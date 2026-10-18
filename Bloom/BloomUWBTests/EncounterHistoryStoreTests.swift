import Foundation
import SwiftData
import Testing
@testable import Bloom

@MainActor
struct EncounterHistoryStoreTests {
    @Test func sessionTitlesPersistIndependentlyAndCanBeCleared() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = ModelConfiguration(url: folder.appendingPathComponent("history.store"), cloudKitDatabase: .none)
        let owner = UUID()
        let person = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = RecordedEncounter(id: UUID(), personID: person, startedAt: date,
                                      endedAt: date.addingTimeInterval(60), duration: 60)
        let second = RecordedEncounter(id: UUID(), personID: person, startedAt: date.addingTimeInterval(120),
                                       endedAt: date.addingTimeInterval(180), duration: 60)
        do {
            let store = try EncounterHistoryStore(ownerID: owner, configuration: configuration)
            try store.save([first, second])
            try store.rename(id: first.id, title: "  ランチの出会い\n")
            try store.save([first])
        }
        let reopened = try EncounterHistoryStore(ownerID: owner, configuration: configuration)
        let loaded = try reopened.load()
        #expect(loaded.first { $0.id == first.id }?.title == "ランチの出会い")
        #expect(loaded.first { $0.id == second.id } == second)
        #expect(loaded.reduce(0) { $0 + $1.duration } == 120)
        let other = try EncounterHistoryStore(ownerID: UUID(), configuration: configuration)
        #expect(throws: CocoaError.self) { try other.rename(id: first.id, title: "別アカウント") }
        try reopened.rename(id: first.id, title: " \n ")
        #expect(try reopened.load().first { $0.id == first.id } == first)
    }

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
