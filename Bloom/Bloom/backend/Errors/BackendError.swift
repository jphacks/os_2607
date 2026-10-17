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
