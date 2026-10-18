import Foundation
import SwiftData

@Model
final class StoredEncounter {
    @Attribute(.unique) var storageID: String
    var id: UUID
    var ownerID: UUID
    var personID: UUID
    var startedAt: Date
    var endedAt: Date
    var duration: Double

    init(ownerID: UUID, encounter: RecordedEncounter) {
        storageID = ownerID.uuidString + ":" + encounter.id.uuidString
        id = encounter.id
        self.ownerID = ownerID
        personID = encounter.personID
        startedAt = encounter.startedAt
        endedAt = encounter.endedAt
        duration = encounter.duration
    }
}

@MainActor
final class EncounterHistoryStore {
    private let container: ModelContainer
    private let ownerID: UUID

    init(ownerID: UUID, configuration: ModelConfiguration = ModelConfiguration("BloomEncounters", cloudKitDatabase: .none)) throws {
        self.ownerID = ownerID
        container = try ModelContainer(for: StoredEncounter.self, configurations: configuration)
    }

    func load() throws -> [RecordedEncounter] {
        let ownerID = ownerID
        let descriptor = FetchDescriptor<StoredEncounter>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try container.mainContext.fetch(descriptor).map {
            RecordedEncounter(id: $0.id, personID: $0.personID, startedAt: $0.startedAt,
                              endedAt: $0.endedAt, duration: $0.duration)
        }
    }

    func save(_ encounters: [RecordedEncounter]) throws {
        guard !encounters.isEmpty else { return }
        var known = Set(try load().map(\.id))
        for encounter in encounters where known.insert(encounter.id).inserted {
            container.mainContext.insert(StoredEncounter(ownerID: ownerID, encounter: encounter))
        }
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
    }

    func deleteAll() throws {
        let ownerID = ownerID
        let descriptor = FetchDescriptor<StoredEncounter>(predicate: #Predicate { $0.ownerID == ownerID })
        for value in try container.mainContext.fetch(descriptor) { container.mainContext.delete(value) }
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
    }
}
