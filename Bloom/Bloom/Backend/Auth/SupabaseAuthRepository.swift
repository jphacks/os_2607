import Foundation
import Supabase

@MainActor
struct SupabaseAuthRepository: AuthRepository {
    let provider: SupabaseProvider
    func userChanges() -> AsyncStream<AuthUser?> {
        let changes = provider.client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await (event, session) in changes {
                    if event == .initialSession { continue }
                    guard !Task.isCancelled else { break }
                    continuation.yield(session.map { AuthUser(id: $0.user.id, email: $0.user.email) })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    func signUp(email: String, password: String) async throws {
        do { try await provider.client.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
        catch { throw BackendError.map(error) }
    }
    func signIn(email: String, password: String) async throws {
        do { try await provider.client.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
        catch { throw BackendError.map(error) }
    }
    func signOut() async throws {
        do { try await provider.client.auth.signOut() }
        catch { throw BackendError.map(error) }
    }
    func currentUser() async throws -> AuthUser? {
        do {
            let user = try await provider.client.auth.session.user
            return AuthUser(id: user.id, email: user.email)
        } catch AuthError.sessionMissing { return nil }
        catch { throw BackendError.map(error) }
    }
    func requestPasswordReset(email: String) async throws {
        do { try await provider.client.auth.resetPasswordForEmail(email.trimmingCharacters(in: .whitespacesAndNewlines)) }
        catch { throw BackendError.map(error) }
    }
}
