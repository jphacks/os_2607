import Foundation

enum ProfileMapper {
    static func map(_ row: ProfileRowDTO) throws -> Profile {
        Profile(id: row.id, displayName: row.displayName, affiliation: row.affiliation,
                bio: row.bio, avatarPath: row.avatarPath, isDiscoverable: row.isDiscoverable,
                createdAt: try date(row.createdAt), updatedAt: try date(row.updatedAt))
    }
    static func publicProfile(_ profile: Profile) -> PublicProfile {
        PublicProfile(id: profile.id, displayName: profile.displayName, affiliation: profile.affiliation,
                      bio: profile.bio, avatarPath: profile.avatarPath)
    }
    static func date(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else { throw BackendError.invalidResponse }
        return date
    }
}
