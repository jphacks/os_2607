import Foundation
import Observation

@MainActor @Observable
final class AppSessionModel {
    enum Phase: Equatable { case loading, signedOut, needsProfile, ready, failed }
    private(set) var phase: Phase = .loading
    private(set) var user: AuthUser?
    private(set) var profile: Profile?
    private(set) var editor: ProfileEditorModel?
    private(set) var encounters: EncounterCoordinator?
    private(set) var isBusy = false
    var errorMessage: String?
    var notice: String?
    @ObservationIgnored private let auth: any AuthRepository
    @ObservationIgnored private let profiles: any ProfileRepository
    @ObservationIgnored private let store: any LocalStore
    @ObservationIgnored private let makeNearby: (UUID) -> any NearbySession
    @ObservationIgnored private var revision = UUID()
    @ObservationIgnored private var observing = false
    @ObservationIgnored private let creation = ContentCreationRecovery()
    @ObservationIgnored private var initialHobbyID = UUID()

    init(auth: any AuthRepository, profiles: any ProfileRepository, store: any LocalStore,
         makeNearby: @escaping (UUID) -> any NearbySession) {
        self.auth = auth; self.profiles = profiles; self.store = store; self.makeNearby = makeNearby
    }

    func observeSession() async {
        guard !observing else { return }
        observing = true
        defer { observing = false }
        let stream = auth.userChanges()
        await restore()
        for await next in stream {
            guard !Task.isCancelled else { break }
            if isBusy {
                if next == nil, user != nil { revision = UUID(); resetUser(); phase = .signedOut }
                continue
            }
            // A token refresh must not discard in-progress editing.
            if next?.id != user?.id { await restore() }
        }
    }

    func restore() async {
        let token = UUID(); revision = token
        do {
            let next = try await auth.currentUser()
            guard revision == token else { return }
            if next?.id != user?.id { resetUser(); user = next }
            guard let next else { phase = .signedOut; return }
            do {
                let value = try await profiles.fetchMyProfile()
                guard revision == token, value.id == next.id else { return }
                activate(value)
            } catch BackendError.notFound {
                guard revision == token else { return }
                phase = .needsProfile
            }
        } catch {
            guard revision == token else { return }
            resetUser(); phase = .failed; errorMessage = error.localizedDescription
        }
    }

    func authenticate(email: String, password: String, creating: Bool) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            if creating { try await auth.signUp(email: email, password: password) }
            else { try await auth.signIn(email: email, password: password) }
            await restore()
            if creating, phase == .signedOut { notice = "確認メールを送信しました。メールの確認後にログインしてください。" }
        } catch { errorMessage = error.localizedDescription }
    }

    func createProfile(name: String, affiliation: String, bio: String, hobby: String,
                       isPublic: Bool, hobbyIsPublic: Bool) async {
        guard !isBusy, let user else { return }
        isBusy = true; errorMessage = nil
        let token = revision
        defer { isBusy = false }
        do {
            let value: Profile
            do { value = try await profiles.fetchMyProfile() }
            catch BackendError.notFound {
                guard revision == token else { return }
                value = try await profiles.createProfile(ProfileCreateInput(displayName: name,
                    affiliation: affiliation, bio: bio, avatarPath: nil, isDiscoverable: isPublic))
            }
            guard revision == token else { return }
            if !hobby.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = try await creation.create(ProfileContentCreateInput(
                    type: .text, title: "趣味", value: hobby, unlockAfterSeconds: 60, displayOrder: 0,
                    isPublic: hobbyIsPublic), draftID: initialHobbyID, ownerID: user.id, repository: profiles, isCurrent: { self.revision == token })
            }
            guard revision == token, value.id == user.id else { return }
            activate(value)
        } catch { if revision == token { errorMessage = "保存に失敗しました。再試行できます。\n" + error.localizedDescription } }
    }

    func saveProfile() async {
        guard let editor else { return }
        let token = revision
        if let value = await editor.save(), token == revision { profile = value }
    }

    func signOut() async {
        guard !isBusy, editor?.isBusy != true else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        // Stop measuring and clear visible personal data even if the network request fails.
        revision = UUID(); resetUser(); phase = .signedOut
        do { try await auth.signOut() }
        catch { phase = .failed; errorMessage = error.localizedDescription }
    }

    func suspend() { encounters?.suspend() }
    func resume() async {
        guard !isBusy else { return }
        await restore(); encounters?.resume()
    }

    private func activate(_ value: Profile) {
        profile = value
        if editor == nil { editor = ProfileEditorModel(repository: profiles, ownerID: value.id) }
        if encounters == nil {
            encounters = EncounterCoordinator(ownerID: value.id, store: store, profiles: profiles,
                nearby: makeNearby(value.id))
        }
        phase = .ready
    }
    private func resetUser() {
        encounters?.shutdown(); encounters = nil
        editor?.invalidate(); editor = nil
        if let user {
            do { try store.clearCache(ownerID: user.id) }
            catch { errorMessage = "キャッシュの削除に失敗しました。" }
        }
        profile = nil; user = nil; initialHobbyID = UUID()
    }
}
