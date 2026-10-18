import Foundation
import SwiftData
import Testing
@testable import Bloom

@MainActor
struct EncounterHistoryStoreTests {
    @Test func persistenceDeduplicationAndAccountIsolation() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = ModelConfiguration(url: folder.appendingPathComponent("history.store"), cloudKitDatabase: .none)
        let owner = UUID()
        let otherOwner = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let record = RecordedEncounter(id: UUID(), personID: UUID(), startedAt: date,
                                       endedAt: date.addingTimeInterval(60), duration: 60)
        do {
            let store = try EncounterHistoryStore(ownerID: owner, configuration: configuration)
            try store.save([record, record])
            try store.save([record])
            #expect(try store.load() == [record])
        }
        do {
            let other = try EncounterHistoryStore(ownerID: otherOwner, configuration: configuration)
            #expect(try other.load().isEmpty)
            try other.save([record])
        }
        do {
            let reopened = try EncounterHistoryStore(ownerID: owner, configuration: configuration)
            #expect(try reopened.load() == [record])
            try reopened.deleteAll()
            #expect(try reopened.load().isEmpty)
        }
        let other = try EncounterHistoryStore(ownerID: otherOwner, configuration: configuration)
        #expect(try other.load() == [record])
    }
}
