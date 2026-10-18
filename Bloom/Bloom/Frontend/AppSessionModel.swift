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
