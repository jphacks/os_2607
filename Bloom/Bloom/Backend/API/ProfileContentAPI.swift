import Foundation
import Supabase

@MainActor
protocol ProfileContentAPIProtocol {
    func getContents(personID: UUID) async throws -> [ProfileContentRowDTO]
    func postContent(_ input: ProfileContentInsertDTO) async throws -> ProfileContentRowDTO
    func patchContent(id: UUID, input: ProfileContentUpdateDTO) async throws -> ProfileContentRowDTO
    func deleteContent(id: UUID) async throws
}

@MainActor
struct ProfileContentAPI: ProfileContentAPIProtocol {
    let provider: SupabaseProvider
    func getContents(personID: UUID) async throws -> [ProfileContentRowDTO] {
        // Explicit pagination avoids silently truncating profiles at the Data API row limit.
        var rows: [ProfileContentRowDTO] = []
        var offset = 0
        while true {
            let page: [ProfileContentRowDTO] = try await provider.client.from("profile_contents").select()
                .eq("profile_id", value: personID).order("display_order").order("created_at").order("id")
                .range(from: offset, to: offset + 99).execute().value
            rows += page
            if page.isEmpty { return rows }
            offset += page.count
        }
    }
    func postContent(_ input: ProfileContentInsertDTO) async throws -> ProfileContentRowDTO {
        guard input.profileID == (try await provider.personID()) else { throw BackendError.forbidden }
        return try await provider.client.from("profile_contents").insert(input).select().single().execute().value
    }
    func patchContent(id: UUID, input: ProfileContentUpdateDTO) async throws -> ProfileContentRowDTO {
        let personID = try await provider.personID()
        return try await provider.client.from("profile_contents").update(input)
            .eq("id", value: id).eq("profile_id", value: personID).select().single().execute().value
    }
    func deleteContent(id: UUID) async throws {
        let personID = try await provider.personID()
        let rows: [ProfileContentRowDTO] = try await provider.client.from("profile_contents").delete()
            .eq("id", value: id).eq("profile_id", value: personID).select().execute().value
        guard rows.count == 1 else { throw BackendError.notFound }
    }
}
