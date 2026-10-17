import Foundation

// Update inputs replace all editable fields; nil explicitly clears optional values.
struct ProfileContentCreateInput: Equatable, Sendable {
    var type: ProfileContentType
    var title: String
    var value: String
    var unlockAfterSeconds: Int
    var displayOrder: Int
    var isPublic: Bool
}
