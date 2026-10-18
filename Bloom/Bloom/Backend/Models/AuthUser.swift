import Foundation

struct AuthUser: Identifiable, Equatable, Sendable {
    let id: UUID
    let email: String?
}
