import Foundation

@MainActor
protocol AuthRepository {
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signInWithApple(idToken: String, nonce: String) async throws
    func signOut() async throws
    func currentUser() async throws -> AuthUser?
    func requestPasswordReset(email: String) async throws
}
