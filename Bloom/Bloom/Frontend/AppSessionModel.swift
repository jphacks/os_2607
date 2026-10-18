import Foundation
import Observation

@MainActor
@Observable
final class AppSessionModel {
    private(set) var user: AuthUser?
    var profile: Profile?
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    let dependencies: BackendDependencies

    init(dependencies: BackendDependencies) {
        self.dependencies = dependencies
    }

    func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            user = try await dependencies.authRepository.currentUser()
            guard user != nil else { profile = nil; return }
            do {
                profile = try await dependencies.profileRepository.fetchMyProfile()
            } catch BackendError.notFound {
                profile = nil
            }
        } catch {
            user = nil
            profile = nil
            errorMessage = error.localizedDescription
        }
    }

    /// Revalidate without replacing HomeView and destroying active ranging sessions.
    func refreshSession() async {
        guard let existingUser = user, profile != nil else { await restore(); return }
        do {
            let current = try await dependencies.authRepository.currentUser()
            guard user?.id == existingUser.id else { return }
            guard current?.id == existingUser.id else {
                await restore()
                return
            }
            do {
                let refreshed = try await dependencies.profileRepository.fetchMyProfile()
                guard user?.id == existingUser.id else { return }
                profile = refreshed
            } catch BackendError.notFound {
                guard user?.id == existingUser.id else { return }
                profile = nil
            }
        } catch {
            // Transient connectivity failures must not tear down a locally running encounter.
            // Authenticated API calls continue to enforce server-side authorization.
        }
    }

    func signOut() async {
        do {
            try await dependencies.authRepository.signOut()
            user = nil
            profile = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
