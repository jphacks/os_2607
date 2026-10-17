import Foundation
import Supabase

@MainActor
final class SupabaseProvider {
    let client: SupabaseClient
    init(config: SupabaseConfig) {
        client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.publishableKey)
    }
    func personID() async throws -> UUID {
        try await client.auth.session.user.id
    }
}

// Composition root: Views receive these protocols, never the client or DTOs.
@MainActor
struct BackendDependencies {
    let authRepository: any AuthRepository
    let profileRepository: any ProfileRepository

    static func live(config: SupabaseConfig) -> BackendDependencies {
        let provider = SupabaseProvider(config: config)
        let auth = SupabaseAuthRepository(provider: provider)
        return BackendDependencies(authRepository: auth,
            profileRepository: SupabaseProfileRepository(
                profileAPI: ProfileAPI(provider: provider),
                contentAPI: ProfileContentAPI(provider: provider), auth: auth))
    }
}
