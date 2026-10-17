import Foundation

// Update inputs replace all editable fields; nil explicitly clears optional values.
struct ProfileCreateInput: Equatable, Sendable {
    var displayName: String
    var affiliation: String?
    var bio: String?
    var avatarPath: String?
    var isDiscoverable: Bool
}
