import Foundation

struct CachedPublicProfile: Codable, Equatable, Sendable {
    let profile: PublicProfile
    let contents: [ProfileContent]
    let fetchedAt: Date
}

@MainActor
protocol LocalStore {
    func encounters(ownerID: UUID) throws -> [Encounter]
    func save(_ encounter: Encounter, ownerID: UUID) throws
    func cachedProfile(personID: UUID, ownerID: UUID) throws -> CachedPublicProfile?
    func save(_ profile: CachedPublicProfile, ownerID: UUID) throws
    func removeCachedProfile(personID: UUID, ownerID: UUID) throws
    func clearCache(ownerID: UUID) throws
}
