import Foundation

struct SupabaseConfig: Sendable {
    let url: URL
    let publishableKey: String

    init(url: String, publishableKey: String) throws {
        guard let parsed = URL(string: url), parsed.scheme == "https", parsed.host != nil,
              parsed.user == nil, parsed.password == nil,
              publishableKey.hasPrefix("sb_publishable_"), !publishableKey.contains("$(") else {
            throw BackendError.configuration
        }
        self.url = parsed
        self.publishableKey = publishableKey
    }
    static func load(bundle: Bundle = .main) throws -> SupabaseConfig {
        guard let url = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else {
            throw BackendError.configuration
        }
        return try SupabaseConfig(url: url, publishableKey: key)
    }
}
