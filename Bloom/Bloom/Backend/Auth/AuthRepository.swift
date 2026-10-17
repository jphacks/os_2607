import Foundation

protocol AuthRepository {
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func signOut() async throws
}

/// UI development adapter. Replace with a Supabase-backed implementation when
/// the Supabase client and project configuration are added to this target.
struct LocalAuthRepository: AuthRepository {
    func signUp(email: String, password: String) async throws {
        try validate(email: email, password: password)
        UserDefaults.standard.set(email, forKey: "localAuthEmail")
    }

    func signIn(email: String, password: String) async throws {
        try validate(email: email, password: password)
        UserDefaults.standard.set(email, forKey: "localAuthEmail")
    }

    func signOut() async throws {
        UserDefaults.standard.removeObject(forKey: "localAuthEmail")
    }

    private func validate(email: String, password: String) throws {
        guard email.contains("@"), email.contains(".") else {
            throw AuthInputError.invalidEmail
        }
        guard password.count >= 8 else {
            throw AuthInputError.shortPassword
        }
    }
}

enum AuthInputError: LocalizedError {
    case invalidEmail
    case shortPassword

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "メールアドレスを確認してください。"
        case .shortPassword:
            return "パスワードは8文字以上で入力してください。"
        }
    }
}
