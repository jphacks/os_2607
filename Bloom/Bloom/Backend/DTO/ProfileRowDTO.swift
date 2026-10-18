import Foundation

struct ProfileRowDTO: Decodable, Sendable {
    let id: UUID
    let displayName: String
    let affiliation: String?
    let bio: String?
    let avatarPath: String?
    let isDiscoverable: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case displayName = "display_name"
        case affiliation = "affiliation"
        case bio = "bio"
        case avatarPath = "avatar_path"
        case isDiscoverable = "is_discoverable"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
