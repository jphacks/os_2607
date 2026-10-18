import Foundation

struct EncounterHistorySummary: Identifiable, Sendable {
    let personID: UUID
    let records: [RecordedEncounter]
    var id: UUID { personID }
    var duration: TimeInterval { records.reduce(0) { $0 + $1.duration } }
    var latestDate: Date? { records.first?.startedAt }

    static func group(_ records: [RecordedEncounter]) -> [EncounterHistorySummary] {
        Dictionary(grouping: records, by: \.personID).map { personID, records in
            EncounterHistorySummary(personID: personID, records: records.sorted { $0.startedAt > $1.startedAt })
        }.sorted {
            if $0.latestDate == $1.latestDate { return $0.id.uuidString < $1.id.uuidString }
            return ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast)
        }
    }
}
