import Foundation
import Supabase

@MainActor
struct SupabaseAuthRepository: AuthRepository {
    let provider: SupabaseProvider
    func signUp(email: String, password: String) async throws {
        do { try await provider.client.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
        catch { throw BackendError.map(error) }
    }
    func signIn(email: String, password: String) async throws {
        do { try await provider.client.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
        catch { throw BackendError.map(error) }
    }
    func signInWithApple(idToken: String, nonce: String) async throws {
        do {
            _ = try await provider.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
        } catch {
            throw BackendError.map(error)
        }
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
