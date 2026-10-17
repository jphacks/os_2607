import Foundation
import Testing
import Supabase
@testable import BloomBackend

struct BackendTests {
    let id = UUID(uuidString: "a1000000-0000-4000-8000-000000000001")!
    let stamp = "2026-10-17T01:02:03.123Z"
    func profileJSON() -> Data {
        Data("""
        {"id":"\(id)","display_name":"Alice","affiliation":null,"bio":"Bio","avatar_path":null,
        "is_discoverable":true,"created_at":"\(stamp)","updated_at":"2026-10-17T01:02:03Z"}
        """.utf8)
    }
    func contentJSON(type: String = "url", uuid: String? = nil) -> Data {
        Data("""
        {"id":"\(uuid ?? id.uuidString)","profile_id":"\(id)","content_type":"\(type)","title":"Link",
        "content_value":"https://example.com","unlock_after_seconds":60,"display_order":2,"is_public":true,
        "created_at":"\(stamp)","updated_at":"\(stamp)"}
        """.utf8)
    }
    @Test func mappingAndDecoding() throws {
        let dto = try JSONDecoder().decode(ProfileRowDTO.self, from: profileJSON())
        let p = try ProfileMapper.map(dto)
        #expect(p.id == id && p.displayName == "Alice" && p.affiliation == nil)
        #expect(p.createdAt == (try ProfileMapper.date(stamp)))
        let c = try ProfileContentMapper.map(JSONDecoder().decode(ProfileContentRowDTO.self, from: contentJSON()))
        #expect(c.profileID == id && c.type == .url && c.displayOrder == 2 && c.unlockAfterSeconds == 60)
        #expect(throws: (any Error).self) { try ProfileMapper.date("bad-date") }
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ProfileContentRowDTO.self, from: contentJSON(type: "unknown")) }
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ProfileContentRowDTO.self, from: contentJSON(uuid: "invalid")) }
    }
    @Test func encodingImmutableFieldsAndNull() throws {
        func object<T: Encodable>(_ value: T) throws -> [String: Any] {
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String: Any]
        }
        let insert = try object(ProfileInsertDTO(id: id, displayName: "Alice", affiliation: nil, bio: nil, avatarPath: nil, isDiscoverable: true))
        #expect(insert["created_at"] == nil && insert["updated_at"] == nil)
        #expect(insert["display_name"] as? String == "Alice")
        let update = try object(ProfileUpdateDTO(displayName: "Alice", affiliation: nil, bio: nil, avatarPath: nil, isDiscoverable: true))
        #expect(update["id"] == nil && update["created_at"] == nil && update["updated_at"] == nil)
        #expect(update["bio"] is NSNull && update["affiliation"] is NSNull && update["avatar_path"] is NSNull)
        let content = try object(ProfileContentInsertDTO(profileID: id, type: .text, title: "Hi", value: "Text", unlockAfterSeconds: 0, displayOrder: 0, isPublic: true))
        #expect(content["id"] == nil && content["created_at"] == nil && content["updated_at"] == nil)
        let patch = try object(ProfileContentUpdateDTO(type: .text, title: "Hi", value: "Text", unlockAfterSeconds: 0, displayOrder: 0, isPublic: true))
        #expect(patch["id"] == nil && patch["profile_id"] == nil && patch["created_at"] == nil && patch["updated_at"] == nil)
    }
    @Test func validation() throws {
        #expect(try ProfileValidation.required(" \nAlice \n", field: "name", max: 50) == "Alice")
        #expect(try ProfileValidation.optional(" \n", field: "bio", max: 500) == nil)
        #expect(try ProfileValidation.optional(" MIT ", field: "affiliation", max: 100) == "MIT")
        for value in ["javascript:alert(1)", "ftp://example.com", "https://", "https://a b.com", "https://user:pass@example.com"] {
            #expect(throws: ProfileValidationError.self) { try ProfileValidation.contentValue(value, type: .url) }
        }
        #expect(try ProfileValidation.contentValue(" https://example.com/a ", type: .image) == "https://example.com/a")
        #expect(throws: ProfileValidationError.self) { try ProfileValidation.number(-1, field: "order") }
        #expect(throws: ProfileValidationError.self) { try ProfileValidation.number(Int.max, field: "order") }
        #expect(throws: ProfileValidationError.self) { try ProfileValidation.required(" ", field: "name", max: 50) }
        #expect(throws: ProfileValidationError.self) { try ProfileValidation.required(String(repeating: "a", count: 51), field: "name", max: 50) }
    }
    @Test func stableSorting() {
        let time = Date(timeIntervalSince1970: 100)
        func item(_ order: Int, _ date: Date) -> ProfileContent {
            ProfileContent(id: UUID(), profileID: id, type: .text, title: "T", value: "V", unlockAfterSeconds: 0,
                           displayOrder: order, isPublic: true, createdAt: date, updatedAt: date)
        }
        let a = item(1, time), b = item(0, time), c = item(0, time), d = item(0, time.addingTimeInterval(-1))
        #expect(ProfileContentMapper.sorted([a,b,c,d]).map(\.id) == [d.id,b.id,c.id,a.id])
    }
    @Test func errorMapping() throws {
        #expect(BackendError.map(URLError(.notConnectedToInternet)) as? BackendError == .network)
        #expect(BackendError.map(CancellationError()) is CancellationError)
        #expect(BackendError.map(ProfileValidationError.invalidURL) as? BackendError == .validation(.invalidURL))
        for (code, expected) in [("42501", BackendError.forbidden), ("23505", .conflict), ("PGRST116", .notFound)] {
            let error = try JSONDecoder().decode(PostgrestError.self, from: Data("{\"code\":\"\(code)\",\"message\":\"test\"}".utf8))
            #expect(BackendError.map(error) as? BackendError == expected)
        }
    }
    @Test @MainActor func mockCRUDAndPrivacy() async throws {
        let repo = MockProfileRepository(userID: id)
        let profile = try await repo.createProfile(.init(displayName: " Alice ", affiliation: " ", bio: nil, avatarPath: nil, isDiscoverable: false))
        #expect(profile.displayName == "Alice" && profile.affiliation == nil)
        #expect(try await repo.fetchMyProfile() == profile)
        let c = try await repo.createContent(.init(type: .text, title: " Title ", value: " Value ", unlockAfterSeconds: 0, displayOrder: 0, isPublic: false))
        #expect(c.title == "Title" && c.value == "Value")
        let updated = try await repo.updateContent(id: c.id, input: .init(type: .url, title: "Link", value: "https://example.com", unlockAfterSeconds: 60, displayOrder: 1, isPublic: true))
        #expect(updated.id == c.id && updated.type == .url && updated.profileID == id)
        _ = try await repo.updateProfile(.init(displayName: "Bob", affiliation: nil, bio: "new", avatarPath: nil, isDiscoverable: true))
        #expect(try await repo.fetchProfile(personID: id).displayName == "Bob")
        try await repo.deleteContent(id: c.id)
        #expect(try await repo.fetchContents(personID: id).isEmpty)
        let other = MockProfileRepository(userID: UUID(), profiles: [profile], contents: [c])
        #expect(try await other.fetchContents(personID: id).isEmpty)
        await #expect(throws: BackendError.notFound) { try await other.fetchProfile(personID: id) }
        await #expect(throws: BackendError.notFound) { try await other.deleteContent(id: c.id) }
        await #expect(throws: BackendError.validation(.negativeNumber("displayOrder"))) {
            try await repo.createContent(.init(type: .text, title: "T", value: "V", unlockAfterSeconds: 0, displayOrder: -1, isPublic: true))
        }
    }
    @Test func configRejectsSecrets() {
        #expect(throws: BackendError.self) { try SupabaseConfig(url: "https://example.com", publishableKey: "sb_secret_test") }
        #expect(throws: BackendError.self) { try SupabaseConfig(url: "http://example.com", publishableKey: "sb_publishable_test") }
    }
}
