import Foundation

struct ProfileInsertDTO: Encodable, Sendable {
    let id: UUID
    let displayName: String
    let affiliation: String?
    let bio: String?
    let avatarPath: String?
    let isDiscoverable: Bool

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case displayName = "display_name"
        case affiliation = "affiliation"
        case bio = "bio"
        case avatarPath = "avatar_path"
        case isDiscoverable = "is_discoverable"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(affiliation, forKey: .affiliation)
        try c.encode(bio, forKey: .bio)
        try c.encode(avatarPath, forKey: .avatarPath)
        try c.encode(isDiscoverable, forKey: .isDiscoverable)
    }
}
