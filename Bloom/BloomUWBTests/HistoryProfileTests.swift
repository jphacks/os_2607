import Foundation
import Testing
@testable import Bloom

struct EncounterHistorySummaryTests {
    @Test func groupsByPersistentPersonAndPreservesEveryEncounter() {
        let first = UUID(), second = UUID()
        let date = Date(timeIntervalSince1970: 1000)
        let a = RecordedEncounter(id: UUID(), personID: first, startedAt: date, endedAt: date.addingTimeInterval(10), duration: 10)
        let b = RecordedEncounter(id: UUID(), personID: second, startedAt: date.addingTimeInterval(20), endedAt: date.addingTimeInterval(30), duration: 10)
        let c = RecordedEncounter(id: UUID(), personID: first, startedAt: date.addingTimeInterval(40), endedAt: date.addingTimeInterval(60), duration: 20)
        let result = EncounterHistorySummary.group([a, b, c])
        #expect(result.map(\.personID) == [first, second])
        #expect(result.first?.duration == 30)
        #expect(result.first?.records.map(\.id) == [c.id, a.id])
    }
}

@MainActor
struct HistoryProfileTests {
    @Test func firstAppearanceStartsWithoutAnError() async {
        let repository = HistoricalProfileTestRepository(personID: UUID())
        let model = HistoryProfileModel(personID: repository.personID, repository: repository, includesContents: true)
        #expect(model.errorMessage == nil)
        #expect(model.profile == nil)
        await model.refresh()
        #expect(model.profile != nil)
        #expect(!model.isLoading)
        model.invalidate()
    }

    @Test func replacementRequestIsNotSkippedWhileCancelledRequestUnwinds() async {
        let repository = HistoricalProfileTestRepository(personID: UUID())
        repository.holdFirstRequest = true
        let model = HistoryProfileModel(personID: repository.personID, repository: repository, includesContents: false)
        let old = Task { await model.refresh() }
        while repository.pending == nil { await Task.yield() }
        old.cancel()
        model.invalidate()
        await model.refresh()
        #expect(repository.requested.count == 2)
        #expect(model.profile != nil)
        repository.pending?.resume(throwing: HistoricalProfileTestRepository.Unavailable.unavailable)
        await old.value
        #expect(model.profile != nil)
        #expect(model.errorMessage == nil)
        model.invalidate()
    }

    @Test func hiddenViewCannotBeRepopulatedByLateResponse() async {
        let repository = HistoricalProfileTestRepository(personID: UUID())
        repository.holdFirstRequest = true
        let model = HistoryProfileModel(personID: repository.personID, repository: repository, includesContents: false)
        let request = Task { await model.refresh() }
        while repository.pending == nil { await Task.yield() }
        model.invalidate()
        repository.pending?.resume(returning: PublicProfile(id: repository.personID, displayName: "遅れた応答", affiliation: nil, bio: nil, avatarPath: nil))
        await request.value
        #expect(model.profile == nil)
        #expect(model.errorMessage == nil)
        #expect(!model.isLoading)
    }

    @Test func loadsHistoricalIdentityWithoutAnyLiveConnection() async {
        let id = UUID()
        let repository = HistoricalProfileTestRepository(personID: id)
        let model = HistoryProfileModel(personID: id, repository: repository, includesContents: true)
        await model.refresh()
        #expect(repository.requested == [id])
        #expect(model.profile?.id == id)
        #expect(model.profile?.displayName == "公開プロフィール")
        #expect(model.revealedContents(accumulatedSeconds: 59).isEmpty)
        #expect(model.revealedContents(accumulatedSeconds: 60).count == 1)
        model.invalidate()
    }

    @Test func revokedPermissionClearsPreviouslyVisibleProfileAndContents() async {
        let repository = HistoricalProfileTestRepository(personID: UUID())
        let model = HistoryProfileModel(personID: repository.personID, repository: repository, includesContents: true)
        await model.refresh()
        #expect(model.profile != nil)
        repository.revoked = true
        await model.refresh()
        #expect(model.profile == nil)
        #expect(model.contents.isEmpty)
        #expect(model.errorMessage != nil)
    }
}

@MainActor
private final class HistoricalProfileTestRepository: ProfileRepository {
    enum Unavailable: Error { case unavailable }
    let personID: UUID
    var revoked = false
    var holdFirstRequest = false
    var pending: CheckedContinuation<PublicProfile, any Error>?
    var requested: [UUID] = []
    init(personID: UUID) { self.personID = personID }

    func fetchProfile(personID: UUID) async throws -> PublicProfile {
        requested.append(personID)
        if holdFirstRequest, requested.count == 1 {
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        if revoked { throw Unavailable.unavailable }
        return PublicProfile(id: personID, displayName: "公開プロフィール", affiliation: nil, bio: "公開された自己紹介", avatarPath: nil)
    }
    func fetchContents(personID: UUID) async throws -> [ProfileContent] {
        if revoked { throw Unavailable.unavailable }
        return [true, false].map {
            ProfileContent(id: UUID(), profileID: personID, type: .text, title: "好きなこと", value: "音楽",
                           unlockAfterSeconds: 60, displayOrder: 0, isPublic: $0, createdAt: Date(), updatedAt: Date())
        }
    }
    func fetchMyProfile() async throws -> Profile { throw Unavailable.unavailable }
    func createProfile(_ input: ProfileCreateInput) async throws -> Profile { throw Unavailable.unavailable }
    func updateProfile(_ input: ProfileUpdateInput) async throws -> Profile { throw Unavailable.unavailable }
    func createContent(_ input: ProfileContentCreateInput) async throws -> ProfileContent { throw Unavailable.unavailable }
    func updateContent(id: UUID, input: ProfileContentUpdateInput) async throws -> ProfileContent { throw Unavailable.unavailable }
    func deleteContent(id: UUID) async throws { throw Unavailable.unavailable }
}
