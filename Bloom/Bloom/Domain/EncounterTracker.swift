import Foundation

struct EncounterRules: Sendable {
    var entryDistance = 2.0
    var entryDuration = 10.0
    var exitDistance = 3.0
    var exitDuration = 15.0
    var maximumObservationGap = 3.0
}

struct RecordedEncounter: Identifiable, Sendable, Equatable {
    let id: UUID
    let personID: UUID
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
    var title: String? = nil
}

/// SDK-independent conservative accounting. Entry/exit waits and missing intervals never accrue.
struct EncounterTracker: Sendable {
    private struct State: Sendable {
        var lastTime: TimeInterval
        var lastDate: Date
        var candidateSince: TimeInterval?
        var startedAt: Date?
        var duration: TimeInterval = 0
        var exitSince: TimeInterval?
        var lastWasInside = false
    }
    var rules = EncounterRules()
    private var states: [UUID: State] = [:]

    init(rules: EncounterRules = EncounterRules()) {
        self.rules = rules
    }

    var activeDurations: [UUID: TimeInterval] {
        states.compactMapValues { $0.startedAt == nil ? nil : $0.duration }
    }

    mutating func observe(personID: UUID, distance: Double?, time: TimeInterval, date: Date) -> [RecordedEncounter] {
        guard time.isFinite else { return [] }
        var completed: [RecordedEncounter] = []
        if let previous = states[personID] {
            guard time > previous.lastTime else { return [] }
            if time - previous.lastTime > rules.maximumObservationGap {
                completed += finish(personID: personID)
            }
        }
        guard let distance, distance.isFinite, distance >= 0 else {
            return completed + finish(personID: personID)
        }
        var state = states[personID] ?? State(lastTime: time, lastDate: date)
        if state.startedAt == nil {
            if distance <= rules.entryDistance {
                if state.candidateSince == nil { state.candidateSince = time }
                if let candidate = state.candidateSince, time - candidate >= rules.entryDuration {
                    state.startedAt = date
                    state.lastWasInside = true
                }
            } else {
                state.candidateSince = nil
            }
        } else if distance > rules.exitDistance {
            if state.exitSince == nil { state.exitSince = time }
            state.lastWasInside = false
            if let exit = state.exitSince, time - exit >= rules.exitDuration {
                states[personID] = state
                return completed + finish(personID: personID)
            }
        } else {
            if let exit = state.exitSince, time - exit >= rules.exitDuration {
                states[personID] = state
                completed += finish(personID: personID)
                return completed + observe(personID: personID, distance: distance, time: time, date: date)
            }
            if state.lastWasInside { state.duration += time - state.lastTime }
            state.exitSince = nil
            state.lastWasInside = true
            state.lastDate = date
        }
        state.lastTime = time
        if state.startedAt == nil { state.lastDate = date }
        states[personID] = state
        return completed
    }

    mutating func retainOnly(_ personIDs: Set<UUID>) -> [RecordedEncounter] {
        states.keys.filter { !personIDs.contains($0) }.flatMap { finish(personID: $0) }
    }

    mutating func finishAll() -> [RecordedEncounter] { retainOnly([]) }

    private mutating func finish(personID: UUID) -> [RecordedEncounter] {
        guard let state = states.removeValue(forKey: personID),
              let start = state.startedAt, state.duration > 0 else { return [] }
        return [RecordedEncounter(id: UUID(), personID: personID, startedAt: start,
                                  endedAt: max(start, state.lastDate), duration: state.duration)]
    }
}
