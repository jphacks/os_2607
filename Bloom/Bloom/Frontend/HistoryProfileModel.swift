import Foundation
import Observation

/// Historical identity comes from persisted encounters, never from a live UWB session.
@MainActor @Observable
final class HistoryProfileModel {
    let personID: UUID
    private(set) var profile: PublicProfile?
    private(set) var contents: [ProfileContent] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private let repository: any ProfileRepository
    private let includesContents: Bool
    private var expiration: Task<Void, Never>?
    private var requestID = UUID()

    init(personID: UUID, repository: any ProfileRepository, includesContents: Bool) {
        self.personID = personID
        self.repository = repository
        self.includesContents = includesContents
    }

    func refresh() async {
        // A new visible task must not be skipped while an older cancelled request unwinds.
        let id = UUID()
        requestID = id
        isLoading = true
        errorMessage = nil
        defer { if requestID == id { isLoading = false } }
        do {
            let profile = try await repository.fetchProfile(personID: personID)
            let contents = includesContents ? try await repository.fetchContents(personID: personID) : []
            try Task.checkCancellation()
            guard requestID == id else { return }
            self.profile = profile
            self.contents = contents.filter(\.isPublic)
            expiration?.cancel()
            expiration = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                // Expiry clears authorization, but must not cancel an in-flight renewal.
                self?.profile = nil
                self?.contents = []
            }
        } catch {
            guard requestID == id, !Task.isCancelled, !(error is CancellationError) else { return }
            expiration?.cancel()
            profile = nil
            contents = []
            errorMessage = error.localizedDescription
        }
    }

    func invalidate() {
        requestID = UUID()
        expiration?.cancel()
        expiration = nil
        profile = nil
        contents = []
        errorMessage = nil
        isLoading = false
    }

    func revealedContents(accumulatedSeconds: TimeInterval) -> [ProfileContent] {
        contents.filter {
            RevealRule.allows(isPublic: $0.isPublic, requiredSeconds: $0.unlockAfterSeconds, accumulatedSeconds: accumulatedSeconds)
        }
    }
}
