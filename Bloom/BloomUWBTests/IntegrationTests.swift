import Foundation
import Testing
@testable import Bloom

struct EncounterIntegrationTests {
    @Test func boundariesAndMissingObservations() {
        let id = UUID()
        var tracker = EncounterTracker(personID: id)
        let date = Date(timeIntervalSince1970: 1000)
        for t in 0..<10 {
            #expect(tracker.observe(distance: 2, time: Double(t), date: date.addingTimeInterval(Double(t))) == nil)
        }
        #expect(tracker.observe(distance: 2, time: 10, date: date.addingTimeInterval(10))?.duration == 0)
        #expect(tracker.observe(distance: 3, time: 11, date: date.addingTimeInterval(11))?.duration == 1)
        for t in 12..<27 { _ = tracker.observe(distance: 3.01, time: Double(t), date: date.addingTimeInterval(Double(t))) }
        #expect(tracker.active != nil)
        #expect(tracker.observe(distance: 3.01, time: 27, date: date.addingTimeInterval(27))?.duration == 1)
        #expect(tracker.active == nil)
        for t in 30...40 { _ = tracker.observe(distance: 2, time: Double(t), date: date.addingTimeInterval(Double(t))) }
        #expect(tracker.active != nil)
        #expect(tracker.expire(at: 43) == nil)
        #expect(tracker.expire(at: 43.01) != nil)
        #expect(tracker.active == nil)
    }

    @Test(arguments: [60, 180, 300]) func revealRequiresConsent(_ threshold: Int) {
        #expect(!RevealPolicy.allows(isPublic: true, requiredSeconds: threshold, totalSeconds: Double(threshold) - 0.01))
        #expect(RevealPolicy.allows(isPublic: true, requiredSeconds: threshold, totalSeconds: Double(threshold)))
        #expect(!RevealPolicy.allows(isPublic: false, requiredSeconds: threshold, totalSeconds: Double(threshold) + 10))
    }
}

@MainActor
struct PersistenceIntegrationTests {
    @Test func duplicateSavesAndOwnerIsolation() throws {
        let store = try SwiftDataLocalStore(inMemory: true)
        let owner = UUID(), otherOwner = UUID(), person = UUID()
        var record = Encounter(id: UUID(), personID: person, startedAt: .now, endedAt: .now, duration: 10)
        try store.save(record, ownerID: owner)
        record.duration = 20
        try store.save(record, ownerID: owner)
        #expect(try store.encounters(ownerID: owner).count == 1)
        #expect(try store.encounters(ownerID: owner).first?.duration == 20)
        #expect(try store.encounters(ownerID: otherOwner).isEmpty == true)
        let profile = PublicProfile(id: person, displayName: "公開", affiliation: nil, bio: nil, avatarPath: nil)
        let hidden = ProfileContent(id: UUID(), profileID: person, type: .text, title: "秘密", value: "非公開",
            unlockAfterSeconds: 0, displayOrder: 0, isPublic: false, createdAt: .now, updatedAt: .now)
        try store.save(CachedPublicProfile(profile: profile, contents: [hidden], fetchedAt: .now), ownerID: owner)
        #expect(try store.cachedProfile(personID: person, ownerID: owner)?.contents.isEmpty == true)
        #expect(try store.cachedProfile(personID: person, ownerID: otherOwner) == nil)
        try store.clearCache(ownerID: owner)
        #expect(try store.cachedProfile(personID: person, ownerID: owner) == nil)
        #expect(try store.encounters(ownerID: owner).count == 1)
    }
}

@MainActor
private final class TestAuth: AuthRepository {
    var user: AuthUser?
    var needsConfirmation = false
    let id = UUID()
    func userChanges() -> AsyncStream<AuthUser?> { AsyncStream { $0.finish() } }
    func currentUser() async throws -> AuthUser? { user }
    func signUp(email: String, password: String) async throws {
        if !needsConfirmation { user = AuthUser(id: id, email: email) }
    }
    func signIn(email: String, password: String) async throws { user = AuthUser(id: id, email: email) }
    func signOut() async throws { user = nil }
    func requestPasswordReset(email: String) async throws {}
}

@MainActor
private final class TestNearby: NearbySession {
    let isSupported = true
    var discoveredPeers: [UWBPeer] = []
    var connections: [UWBPeerConnection] = []
    var pendingConnectionIDs: [UUID] = []
    let events = AsyncStream<UWBMultiPeerEvent> { _ in }
    var stopCount = 0
    func startHosting() {}
    func startBrowsing() {}
    func connect(to peer: UWBPeer) throws -> UUID { UUID() }
    func disconnect(from personID: UUID) {}
    func acceptConnection(id: UUID) {}
    func rejectConnection(id: UUID) {}
    func stop() { stopCount += 1 }
}

@MainActor
struct SessionIntegrationTests {
    @Test func confirmationAndProfileRouting() async throws {
        let auth = TestAuth(); auth.needsConfirmation = true
        let repo = MockProfileRepository(userID: auth.id)
        let nearby = TestNearby()
        let session = AppSessionModel(auth: auth, profiles: repo, store: try SwiftDataLocalStore(inMemory: true), makeNearby: { _ in nearby })
        await session.authenticate(email: "test@example.com", password: "not-a-real-password", creating: true)
        #expect(session.phase == .signedOut)
        #expect(session.notice != nil)
        await session.authenticate(email: "test@example.com", password: "not-a-real-password", creating: false)
        #expect(session.phase == .needsProfile)
        await session.createProfile(name: "本人", affiliation: "", bio: "", hobby: "読書", isPublic: true, hobbyIsPublic: false)
        #expect(session.phase == .ready)
        #expect(session.profile?.id == auth.id)
        #expect(try await repo.fetchContents(personID: auth.id).first?.isPublic == false)
        await session.signOut()
        #expect(session.phase == .signedOut)
        #expect(session.editor == nil && session.encounters == nil && session.profile == nil)
        #expect(nearby.stopCount > 0)
    }

    @Test func contentRetryAndEditorPreserveUneditedFields() async throws {
        let id = UUID()
        let repo = MockProfileRepository(userID: id)
        _ = try await repo.createProfile(ProfileCreateInput(displayName: "名前", affiliation: "所属", bio: "bio", avatarPath: "avatars/kept", isDiscoverable: true))
        let input = ProfileContentCreateInput(type: .url, title: "URL", value: "https://example.com", unlockAfterSeconds: 61, displayOrder: 7, isPublic: false)
        let first = try await repo.createContent(input)
        #expect(first.profileID == id)
        #expect(try await repo.fetchContents(personID: id).count == 1)
        let editor = ProfileEditorModel(repository: repo, ownerID: id)
        await editor.load()
        editor.displayName = "変更"
        let saved = await editor.save()
        #expect(saved?.avatarPath == "avatars/kept")
        let field = try #require(try await repo.fetchContents(personID: id).first)
        #expect(field.unlockAfterSeconds == 61 && field.displayOrder == 7 && field.type == .url && !field.isPublic)
        editor.removeField(id: field.id)
        _ = await editor.save()
        #expect(try await repo.fetchContents(personID: id).isEmpty == true)
    }

    @Test func observationsPersistWithoutDoubleCountingAndStopOnSuspend() async throws {
        let owner = UUID(), person = UUID(), connection = UUID()
        let store = try SwiftDataLocalStore(inMemory: true)
        let nearby = TestNearby()
        var time: Double = 0
        let coordinator = EncounterCoordinator(ownerID: owner, store: store,
            profiles: MockProfileRepository(userID: owner), nearby: nearby, clock: { time })
        coordinator.start()
        for t in 0...12 {
            time = Double(t)
            coordinator.receive(.connectionChanged(UWBPeerConnection(id: connection, personID: person, peerName: nil,
                state: .measuring, observation: UWBObservation(personID: person, distanceMeters: 2, direction: nil))))
        }
        #expect(coordinator.totalSeconds(for: person) == 2)
        #expect(try store.encounters(ownerID: owner).count == 1)
        coordinator.suspend()
        #expect(coordinator.activePeople.isEmpty && !coordinator.isParticipating)
        time = 100
        coordinator.tick()
        #expect(coordinator.totalSeconds(for: person) == 2)
        coordinator.shutdown()
    }
}

@MainActor
private final class FaultProfileRepository: ProfileRepository {
    let base: any ProfileRepository
    var loseNextCreateResponse = false
    var rejectReads = false
    var createCalls = 0
    init(_ base: any ProfileRepository) { self.base = base }
    func fetchMyProfile() async throws -> Profile { try await base.fetchMyProfile() }
    func fetchProfile(personID: UUID) async throws -> PublicProfile {
        if rejectReads { throw BackendError.notFound }
        return try await base.fetchProfile(personID: personID)
    }
    func fetchContents(personID: UUID) async throws -> [ProfileContent] {
        if rejectReads { throw BackendError.network }
        return try await base.fetchContents(personID: personID)
    }
    func createProfile(_ input: ProfileCreateInput) async throws -> Profile { try await base.createProfile(input) }
    func updateProfile(_ input: ProfileUpdateInput) async throws -> Profile { try await base.updateProfile(input) }
    func createContent(_ input: ProfileContentCreateInput) async throws -> ProfileContent {
        createCalls += 1
        let result = try await base.createContent(input)
        if loseNextCreateResponse { loseNextCreateResponse = false; throw BackendError.network }
        return result
    }
    func updateContent(id: UUID, input: ProfileContentUpdateInput) async throws -> ProfileContent {
        try await base.updateContent(id: id, input: input)
    }
    func deleteContent(id: UUID) async throws { try await base.deleteContent(id: id) }
}

@MainActor
struct FailureIntegrationTests {
    @Test func lostCreateResponseDoesNotDuplicateAndInitialProfileCanResume() async throws {
        let auth = TestAuth()
        let base = MockProfileRepository(userID: auth.id)
        let repo = FaultProfileRepository(base)
        let session = AppSessionModel(auth: auth, profiles: repo, store: try SwiftDataLocalStore(inMemory: true),
            makeNearby: { _ in TestNearby() })
        await session.authenticate(email: "test@example.com", password: "test", creating: false)
        repo.loseNextCreateResponse = true
        await session.createProfile(name: "本人", affiliation: "", bio: "", hobby: "読書", isPublic: true, hobbyIsPublic: true)
        #expect(session.phase == .needsProfile)
        await session.createProfile(name: "本人", affiliation: "", bio: "", hobby: "読書", isPublic: true, hobbyIsPublic: true)
        #expect(session.phase == .ready)
        #expect(repo.createCalls == 1)
        #expect(try await base.fetchContents(personID: auth.id).count == 1)
        await session.signOut()
    }

    @Test func editorRecoversPartialCreationAndKeepsReturnedID() async throws {
        let id = UUID()
        let base = MockProfileRepository(userID: id)
        _ = try await base.createProfile(ProfileCreateInput(displayName: "名前", affiliation: nil, bio: nil, avatarPath: nil, isDiscoverable: true))
        let repo = FaultProfileRepository(base)
        let editor = ProfileEditorModel(repository: repo, ownerID: id)
        await editor.load(); editor.addField()
        editor.fields[0].title = "趣味"; editor.fields[0].value = "読書"
        repo.loseNextCreateResponse = true
        #expect(await editor.save() == nil)
        #expect(await editor.save() != nil)
        let saved = try #require(try await base.fetchContents(personID: id).first)
        #expect(editor.fields[0].id == saved.id)
        #expect(repo.createCalls == 1)
        editor.fields[0].value = "散歩"
        #expect(await editor.save() != nil)
        #expect(try await base.fetchContents(personID: id).count == 1)
        #expect(try await base.fetchContents(personID: id).first?.value == "散歩")
    }

    @Test func revokedProfileClearsVisibleDataAndCache() async throws {
        let owner = UUID(), person = UUID()
        let base = MockProfileRepository(userID: person)
        _ = try await base.createProfile(ProfileCreateInput(displayName: "公開", affiliation: nil, bio: nil, avatarPath: nil, isDiscoverable: true))
        let repo = FaultProfileRepository(base)
        let store = try SwiftDataLocalStore(inMemory: true)
        let coordinator = EncounterCoordinator(ownerID: owner, store: store, profiles: repo, nearby: TestNearby())
        coordinator.refreshProfile(person)
        for _ in 0..<1000 {
            if coordinator.publicProfiles[person] != nil { break }
            await Task.yield()
        }
        #expect(coordinator.publicProfiles[person] != nil)
        repo.rejectReads = true
        coordinator.refreshProfile(person)
        for _ in 0..<1000 {
            if coordinator.profileMessages[person] != nil { break }
            await Task.yield()
        }
        #expect(coordinator.publicProfiles[person] == nil)
        #expect(try store.cachedProfile(personID: person, ownerID: owner) == nil)
        coordinator.shutdown()
    }
}
