import Foundation

/// In-memory preview/test repository. Shares validation and mapping with production.
@MainActor
final class MockProfileRepository: ProfileRepository {
    private let store: MockProfileStore
    private var repository: SupabaseProfileRepository {
        SupabaseProfileRepository(profileAPI: store, contentAPI: store, auth: store)
    }
    init(userID: UUID = UUID(), profiles: [Profile] = [], contents: [ProfileContent] = [],
         now: @escaping () -> Date = Date.init) {
        store = MockProfileStore(userID: userID, profiles: profiles, contents: contents, now: now)
    }
    func fetchMyProfile() async throws -> Profile { try await repository.fetchMyProfile() }
    func fetchProfile(personID: UUID) async throws -> PublicProfile { try await repository.fetchProfile(personID: personID) }
    func createProfile(_ input: ProfileCreateInput) async throws -> Profile { try await repository.createProfile(input) }
    func updateProfile(_ input: ProfileUpdateInput) async throws -> Profile { try await repository.updateProfile(input) }
    func fetchContents(personID: UUID) async throws -> [ProfileContent] { try await repository.fetchContents(personID: personID) }
    func createContent(_ input: ProfileContentCreateInput) async throws -> ProfileContent { try await repository.createContent(input) }
    func updateContent(id: UUID, input: ProfileContentUpdateInput) async throws -> ProfileContent { try await repository.updateContent(id: id, input: input) }
    func deleteContent(id: UUID) async throws { try await repository.deleteContent(id: id) }
}

@MainActor
private final class MockProfileStore: ProfileAPIProtocol, ProfileContentAPIProtocol, AuthRepository {
    let userID: UUID
    var profiles: [UUID: Profile]
    var contents: [UUID: ProfileContent]
    let now: () -> Date
    init(userID: UUID, profiles: [Profile], contents: [ProfileContent], now: @escaping () -> Date) {
        self.userID = userID
        self.profiles = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        self.contents = Dictionary(contents.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        self.now = now
    }
    private func date(_ date: Date) -> String { date.ISO8601Format(.iso8601WithTimeZone(includingFractionalSeconds: true)) }
    private func row(_ p: Profile) -> ProfileRowDTO {
        ProfileRowDTO(id: p.id, displayName: p.displayName, affiliation: p.affiliation, bio: p.bio,
                      avatarPath: p.avatarPath, isDiscoverable: p.isDiscoverable,
                      createdAt: date(p.createdAt), updatedAt: date(p.updatedAt))
    }
    private func row(_ c: ProfileContent) -> ProfileContentRowDTO {
        ProfileContentRowDTO(id: c.id, profileID: c.profileID, type: c.type, title: c.title, value: c.value,
                            unlockAfterSeconds: c.unlockAfterSeconds, displayOrder: c.displayOrder, isPublic: c.isPublic,
                            createdAt: date(c.createdAt), updatedAt: date(c.updatedAt))
    }
    func getMyProfile() async throws -> ProfileRowDTO { try await getProfile(personID: userID) }
    func getProfile(personID: UUID) async throws -> ProfileRowDTO {
        guard let p = profiles[personID], p.id == userID || p.isDiscoverable else { throw BackendError.notFound }
        return row(p)
    }
    func postProfile(_ input: ProfileInsertDTO) async throws -> ProfileRowDTO {
        guard input.id == userID else { throw BackendError.forbidden }
        guard profiles[userID] == nil else { throw BackendError.conflict }
        let time = now()
        let p = Profile(id: userID, displayName: input.displayName, affiliation: input.affiliation, bio: input.bio,
                        avatarPath: input.avatarPath, isDiscoverable: input.isDiscoverable, createdAt: time, updatedAt: time)
        profiles[userID] = p
        return row(p)
    }
    func patchProfile(_ input: ProfileUpdateDTO) async throws -> ProfileRowDTO {
        guard var p = profiles[userID] else { throw BackendError.notFound }
        p.displayName = input.displayName; p.affiliation = input.affiliation; p.bio = input.bio
        p.avatarPath = input.avatarPath; p.isDiscoverable = input.isDiscoverable; p.updatedAt = now()
        profiles[userID] = p
        return row(p)
    }
    func getContents(personID: UUID) async throws -> [ProfileContentRowDTO] {
        contents.values.filter { $0.profileID == personID &&
            (personID == userID || ($0.isPublic && profiles[personID]?.isDiscoverable == true))
        }.sorted { $0.id.uuidString < $1.id.uuidString }.map(row)
    }
    func postContent(_ input: ProfileContentInsertDTO) async throws -> ProfileContentRowDTO {
        guard input.profileID == userID else { throw BackendError.forbidden }
        guard profiles[userID] != nil else { throw BackendError.notFound }
        let time = now()
        let c = ProfileContent(id: UUID(), profileID: userID, type: input.type, title: input.title, value: input.value,
                               unlockAfterSeconds: input.unlockAfterSeconds, displayOrder: input.displayOrder,
                               isPublic: input.isPublic, createdAt: time, updatedAt: time)
        contents[c.id] = c
        return row(c)
    }
    func patchContent(id: UUID, input: ProfileContentUpdateDTO) async throws -> ProfileContentRowDTO {
        guard var c = contents[id], c.profileID == userID else { throw BackendError.notFound }
        c.type = input.type; c.title = input.title; c.value = input.value
        c.unlockAfterSeconds = input.unlockAfterSeconds; c.displayOrder = input.displayOrder
        c.isPublic = input.isPublic; c.updatedAt = now()
        contents[id] = c
        return row(c)
    }
    func deleteContent(id: UUID) async throws {
        guard contents[id]?.profileID == userID else { throw BackendError.notFound }
        contents.removeValue(forKey: id)
    }
    func currentUser() async throws -> AuthUser? { AuthUser(id: userID, email: nil) }
    func signUp(email: String, password: String) async throws { throw BackendError.configuration }
    func signIn(email: String, password: String) async throws { throw BackendError.configuration }
    func signInWithApple(idToken: String, nonce: String) async throws { throw BackendError.configuration }
    func signOut() async throws { throw BackendError.configuration }
    func requestPasswordReset(email: String) async throws { throw BackendError.configuration }
}
