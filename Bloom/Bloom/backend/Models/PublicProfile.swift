import Foundation

struct PublicProfile: Identifiable, Equatable, Sendable {
    let id: UUID
    let displayName: String
    let affiliation: String?
    let bio: String?
    let avatarPath: String?
}
