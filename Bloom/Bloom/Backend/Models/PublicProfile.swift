import Foundation

struct PublicProfile: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let displayName: String
    let affiliation: String?
    let bio: String?
    let avatarPath: String?
}
