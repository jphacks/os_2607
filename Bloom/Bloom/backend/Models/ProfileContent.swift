import Foundation

struct ProfileContent: Identifiable, Equatable, Sendable {
    let id: UUID
    let profileID: UUID
    var type: ProfileContentType
    var title: String
    var value: String
    var unlockAfterSeconds: Int
    var displayOrder: Int
    var isPublic: Bool
    let createdAt: Date
    var updatedAt: Date
}
