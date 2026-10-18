import Foundation
import Supabase

enum BackendError: LocalizedError, Equatable, Sendable {
    case configuration, unauthenticated, forbidden, notFound, conflict, invalidResponse, network, server
    case validation(ProfileValidationError)
    case authentication(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .configuration:
            "接続設定が不足しているため、アプリを開始できません。"
        case .unauthenticated:
            "認証できませんでした。ログイン情報とメール確認の状況をご確認ください。"
        case .forbidden:
            "この情報にアクセスする権限がありません。"
        case .notFound:
            "対象の情報が見つかりませんでした。"
        case .conflict:
            "同じ情報がすでに登録されています。"
        case .invalidResponse:
            "サーバーからの応答を読み取れませんでした。"
        case .network:
            "通信できませんでした。ネットワーク接続をご確認ください。"
        case .server:
            "サーバーでエラーが発生しました。時間をおいて再度お試しください。"
        case let .authentication(code, message):
            switch code {
            case "over_email_send_rate_limit":
                "確認メールの送信上限に達しました。時間をおいてお試しください。"
            case "over_request_rate_limit":
                "リクエストが集中しています。時間をおいてお試しください。"
            case "email_address_not_authorized":
                "このメールアドレスには確認メールを送信できません。管理者によるメール送信設定の確認が必要です。"
            case "email_address_invalid":
                "メールアドレスの形式をご確認ください。"
            case "weak_password":
                "パスワードが登録条件を満たしていません。\n" + message
            case "email_not_confirmed":
                "確認メールのリンクを開いてからログインしてください。"
            case "signup_disabled", "email_provider_disabled":
                "現在、メールでの新規登録が無効になっています。"
            case "user_already_exists", "email_exists":
                "すでに登録されています。ログインをお試しください。"
            case "invalid_credentials":
                "メールアドレスまたはパスワードが正しくありません。"
            default:
                "認証処理に失敗しました（" + code + "）。\n" + message
            }
        case .validation:
            "入力内容が条件を満たしていません。内容をご確認ください。"
        }
    }

    static func map(_ error: Error) -> Error {
        if error is CancellationError { return error }
        if let error = error as? BackendError { return error }
        if let error = error as? ProfileValidationError { return BackendError.validation(error) }
        if error is DecodingError { return BackendError.invalidResponse }
        if let error = error as? URLError {
            return error.code == .cancelled ? CancellationError() : BackendError.network
        }
        if let error = error as? PostgrestError {
            switch error.code {
            case "42501": return BackendError.forbidden
            case "23505": return BackendError.conflict
            case "PGRST116": return BackendError.notFound
            case "PGRST301", "PGRST302", "PGRST303": return BackendError.unauthenticated
            default: return BackendError.server
            }
        }
        if let error = error as? AuthError {
            if error == .sessionMissing { return BackendError.unauthenticated }
            return BackendError.authentication(code: error.errorCode.rawValue, message: error.message)
        }
        return BackendError.server
    }
}
