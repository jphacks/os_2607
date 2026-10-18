import Foundation

struct ProfileContentRowDTO: Decodable, Sendable {
    let id: UUID
    let profileID: UUID
    let type: ProfileContentType
    let title: String
    let value: String
    let unlockAfterSeconds: Int
    let displayOrder: Int
    let isPublic: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case profileID = "profile_id"
        case type = "content_type"
        case title = "title"
        case value = "content_value"
        case unlockAfterSeconds = "unlock_after_seconds"
        case displayOrder = "display_order"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
