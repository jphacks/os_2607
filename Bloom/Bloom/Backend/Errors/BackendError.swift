import Foundation
import Supabase

enum BackendError: Error, Equatable, Sendable {
    case configuration, unauthenticated, forbidden, notFound, conflict, invalidResponse, network, server
    case validation(ProfileValidationError)

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
        if error is AuthError { return BackendError.unauthenticated }
        return BackendError.server
    }
}


extension BackendError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .configuration: "接続設定を読み込めませんでした。"
        case .unauthenticated: "ログイン状態を確認してください。"
        case .forbidden: "この操作は許可されていません。"
        case .notFound: "情報が見つからないか、公開されていません。"
        case .conflict: "すでに登録されています。再読み込みしてください。"
        case .invalidResponse: "取得した情報を読み込めませんでした。"
        case .network: "通信できませんでした。接続を確認して再試行してください。"
        case .server: "処理に失敗しました。時間をおいて再試行してください。"
        case let .validation(error): error.localizedDescription
        }
    }
}
