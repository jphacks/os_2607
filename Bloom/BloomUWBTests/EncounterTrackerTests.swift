import Foundation
import Testing
@testable import Bloom

struct EncounterTrackerTests {
    private let personID = UUID()
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func feed(_ tracker: inout EncounterTracker, _ second: Double, distance: Double? = 2) -> [RecordedEncounter] {
        tracker.observe(personID: personID, distance: distance, time: second, date: epoch.addingTimeInterval(second))
    }

    @Test func entryBoundaryAndHysteresis() {
        var tracker = EncounterTracker()
        for second in 0...9 { #expect(feed(&tracker, Double(second)).isEmpty) }
        #expect(tracker.activeDurations.isEmpty)
        #expect(feed(&tracker, 10).isEmpty)
        #expect(tracker.activeDurations[personID] == 0)
        #expect(feed(&tracker, 11, distance: 3).isEmpty)
        #expect(tracker.activeDurations[personID] == 1)
        let records = tracker.finishAll()
        #expect(records.count == 1)
        #expect(records.first?.startedAt == epoch.addingTimeInterval(10))
        #expect(records.first?.duration == 1)
        #expect(tracker.finishAll().isEmpty)
    }

    @Test func interruptedCandidateMustStartAgain() {
        var tracker = EncounterTracker()
        for second in 0...9 { _ = feed(&tracker, Double(second)) }
        _ = feed(&tracker, 10, distance: 2.01)
        for second in 11...20 { _ = feed(&tracker, Double(second)) }
        #expect(tracker.activeDurations.isEmpty)
        _ = feed(&tracker, 21)
        #expect(tracker.activeDurations[personID] == 0)
    }

    @Test func exitWaitNeverAccruesAndEndsAtFifteenSeconds() {
        var tracker = EncounterTracker()
        for second in 0...11 { _ = feed(&tracker, Double(second)) }
        for second in 12...26 { #expect(feed(&tracker, Double(second), distance: 3.01).isEmpty) }
        let records = feed(&tracker, 27, distance: 3.01)
        #expect(records.count == 1)
        #expect(records.first?.duration == 1)
        #expect(records.first?.endedAt == epoch.addingTimeInterval(11))
        #expect(tracker.activeDurations.isEmpty)
    }

    @Test func missingStaleAndDuplicateSamplesDoNotAddTime() {
        var tracker = EncounterTracker()
        for second in 0...11 { _ = feed(&tracker, Double(second)) }
        _ = feed(&tracker, 11)
        _ = feed(&tracker, 10)
        #expect(tracker.activeDurations[personID] == 1)
        let records = feed(&tracker, 15)
        #expect(records.first?.duration == 1)
        #expect(tracker.activeDurations.isEmpty)
        #expect(feed(&tracker, 16, distance: nil).isEmpty)
        #expect(tracker.finishAll().isEmpty)
    }

    @Test(arguments: [Double.nan, Double.infinity, -1])
    func invalidDistanceEndsWithoutAccruing(_ invalid: Double) {
        var tracker = EncounterTracker()
        for second in 0...11 { _ = feed(&tracker, Double(second)) }
        #expect(feed(&tracker, 12, distance: invalid).first?.duration == 1)
    }

    @Test func peopleAreIndependentAndDisconnectFinishesOnlyDepartedPerson() {
        var tracker = EncounterTracker()
        let otherID = UUID()
        for second in 0...11 {
            _ = feed(&tracker, Double(second))
            _ = tracker.observe(personID: otherID, distance: 1, time: Double(second), date: epoch.addingTimeInterval(Double(second)))
        }
        let finished = tracker.retainOnly([otherID])
        #expect(finished.count == 1)
        #expect(finished.first?.personID == personID)
        #expect(tracker.activeDurations[otherID] == 1)
        #expect(tracker.activeDurations[personID] == nil)
    }

    @Test func wallClockChangesDoNotInflateDuration() {
        var tracker = EncounterTracker()
        for second in 0...10 { _ = feed(&tracker, Double(second)) }
        _ = tracker.observe(personID: personID, distance: 1, time: 11, date: epoch.addingTimeInterval(-1000))
        let record = tracker.finishAll().first
        #expect(record?.duration == 1)
        #expect(record?.endedAt == record?.startedAt)
    }

    @Test(arguments: [60, 180, 300])
    func revealRequiresConsentAndExactThreshold(_ threshold: Int) {
        #expect(!RevealRule.allows(isPublic: true, requiredSeconds: threshold, accumulatedSeconds: Double(threshold) - 0.001))
        #expect(RevealRule.allows(isPublic: true, requiredSeconds: threshold, accumulatedSeconds: Double(threshold)))
        #expect(!RevealRule.allows(isPublic: false, requiredSeconds: threshold, accumulatedSeconds: Double(threshold) + 1))
        #expect(!RevealRule.allows(isPublic: true, requiredSeconds: threshold, accumulatedSeconds: .nan))
        #expect(!RevealRule.allows(isPublic: true, requiredSeconds: -1, accumulatedSeconds: 10))
    }
}
