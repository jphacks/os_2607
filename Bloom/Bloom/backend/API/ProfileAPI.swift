import Foundation
import Supabase

@MainActor
protocol ProfileAPIProtocol {
    func getMyProfile() async throws -> ProfileRowDTO
    func getProfile(personID: UUID) async throws -> ProfileRowDTO
    func postProfile(_ input: ProfileInsertDTO) async throws -> ProfileRowDTO
    func patchProfile(_ input: ProfileUpdateDTO) async throws -> ProfileRowDTO
}

@MainActor
struct ProfileAPI: ProfileAPIProtocol {
    let provider: SupabaseProvider
    func getMyProfile() async throws -> ProfileRowDTO {
        try await getProfile(personID: provider.personID())
    }
    func getProfile(personID: UUID) async throws -> ProfileRowDTO {
        try await provider.client.from("profiles").select().eq("id", value: personID).single().execute().value
    }
    func postProfile(_ input: ProfileInsertDTO) async throws -> ProfileRowDTO {
        guard input.id == (try await provider.personID()) else { throw BackendError.forbidden }
        return try await provider.client.from("profiles").insert(input).select().single().execute().value
    }
    func patchProfile(_ input: ProfileUpdateDTO) async throws -> ProfileRowDTO {
        let id = try await provider.personID()
        return try await provider.client.from("profiles").update(input).eq("id", value: id).select().single().execute().value
    }
}
