import Foundation

struct ProfileContentInsertDTO: Encodable, Sendable {
    let profileID: UUID
    let type: ProfileContentType
    let title: String
    let value: String
    let unlockAfterSeconds: Int
    let displayOrder: Int
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case type = "content_type"
        case title = "title"
        case value = "content_value"
        case unlockAfterSeconds = "unlock_after_seconds"
        case displayOrder = "display_order"
        case isPublic = "is_public"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(profileID, forKey: .profileID)
        try c.encode(type, forKey: .type)
        try c.encode(title, forKey: .title)
        try c.encode(value, forKey: .value)
        try c.encode(unlockAfterSeconds, forKey: .unlockAfterSeconds)
        try c.encode(displayOrder, forKey: .displayOrder)
        try c.encode(isPublic, forKey: .isPublic)
    }
}
