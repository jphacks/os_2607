import Foundation

struct Profile: Identifiable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    var affiliation: String?
    var bio: String?
    var avatarPath: String?
    var isDiscoverable: Bool
    let createdAt: Date
    var updatedAt: Date
}
