import Foundation
import SwiftData

@Model
final class StoredEncounter {
    @Attribute(.unique) var key: String
    var ownerID: UUID
    var personID: UUID
    var encounterID: UUID
    var startedAt: Date
    var endedAt: Date
    var duration: Double

    init(_ value: Encounter, ownerID: UUID) {
        key = ownerID.uuidString + ":" + value.id.uuidString
        self.ownerID = ownerID
        personID = value.personID
        encounterID = value.id
        startedAt = value.startedAt
        endedAt = value.endedAt
        duration = value.duration
    }

    var value: Encounter {
        Encounter(id: encounterID, personID: personID, startedAt: startedAt, endedAt: endedAt, duration: duration)
    }
}

@Model
final class StoredProfileCache {
    @Attribute(.unique) var key: String
    var ownerID: UUID
    var personID: UUID
    var payload: Data
    init(_ value: CachedPublicProfile, ownerID: UUID) throws {
        key = ownerID.uuidString + ":" + value.profile.id.uuidString
        self.ownerID = ownerID
        personID = value.profile.id
        payload = try JSONEncoder().encode(value)
    }
}

@MainActor
final class SwiftDataLocalStore: LocalStore {
    let container: ModelContainer
    private let context: ModelContext

    init(inMemory: Bool = false) throws {
        container = try ModelContainer(for: StoredEncounter.self, StoredProfileCache.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func encounters(ownerID: UUID) throws -> [Encounter] {
        try context.fetch(FetchDescriptor<StoredEncounter>(predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\StoredEncounter.startedAt, order: .reverse)])).map(\.value)
    }

    func save(_ encounter: Encounter, ownerID: UUID) throws {
        let key = ownerID.uuidString + ":" + encounter.id.uuidString
        do {
            if let row = try context.fetch(FetchDescriptor<StoredEncounter>(predicate: #Predicate { $0.key == key })).first {
                row.duration = encounter.duration
                row.endedAt = encounter.endedAt
            } else { context.insert(StoredEncounter(encounter, ownerID: ownerID)) }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    func cachedProfile(personID: UUID, ownerID: UUID) throws -> CachedPublicProfile? {
        let key = ownerID.uuidString + ":" + personID.uuidString
        guard let row = try context.fetch(FetchDescriptor<StoredProfileCache>(predicate: #Predicate { $0.key == key })).first else { return nil }
        return try JSONDecoder().decode(CachedPublicProfile.self, from: row.payload)
    }

    func save(_ profile: CachedPublicProfile, ownerID: UUID) throws {
        // Own private editor data must never enter the public-profile cache.
        let publicValue = CachedPublicProfile(profile: profile.profile,
            contents: profile.contents.filter(\.isPublic), fetchedAt: profile.fetchedAt)
        let key = ownerID.uuidString + ":" + profile.profile.id.uuidString
        do {
            if let row = try context.fetch(FetchDescriptor<StoredProfileCache>(predicate: #Predicate { $0.key == key })).first {
                row.payload = try JSONEncoder().encode(publicValue)
            } else { context.insert(try StoredProfileCache(publicValue, ownerID: ownerID)) }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    func removeCachedProfile(personID: UUID, ownerID: UUID) throws {
        let key = ownerID.uuidString + ":" + personID.uuidString
        do {
            for row in try context.fetch(FetchDescriptor<StoredProfileCache>(predicate: #Predicate { $0.key == key })) { context.delete(row) }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    func clearCache(ownerID: UUID) throws {
        do {
            for row in try context.fetch(FetchDescriptor<StoredProfileCache>(predicate: #Predicate { $0.ownerID == ownerID })) { context.delete(row) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
