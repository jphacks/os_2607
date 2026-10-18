import Foundation

struct Encounter: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let personID: UUID
    let startedAt: Date
    var endedAt: Date
    var duration: TimeInterval
}

struct EncounterRules: Sendable {
    var startDistance: Double = 2
    var startDelay: TimeInterval = 10
    var endDistance: Double = 3
    var endDelay: TimeInterval = 15
    var maximumObservationGap: TimeInterval = 3
}

/// Uses an injected monotonic clock for elapsed time; wall time is only for history labels.
struct EncounterTracker {
    let personID: UUID
    var rules = EncounterRules()
    private var enteredAt: TimeInterval?
    private var leftAt: TimeInterval?
    private var previousTime: TimeInterval?
    private var previousDistance: Double?
    private(set) var active: Encounter?

    init(personID: UUID, rules: EncounterRules = EncounterRules()) {
        self.personID = personID; self.rules = rules
    }

    mutating func observe(distance: Double?, time: TimeInterval, date: Date) -> Encounter? {
        guard let distance, distance.isFinite, distance >= 0 else { return stop() }
        var finished: Encounter?
        if let previousTime {
            guard time > previousTime else { return nil }
            if time - previousTime > rules.maximumObservationGap { finished = stop() }
        }
        defer { previousTime = time; previousDistance = distance }
        if active == nil {
            if distance <= rules.startDistance {
                if enteredAt == nil { enteredAt = time }
                if let enteredAt, time - enteredAt >= rules.startDelay {
                    active = Encounter(id: UUID(), personID: personID, startedAt: date, endedAt: date, duration: 0)
                }
            } else { enteredAt = nil }
            return finished ?? active
        }
        if distance > rules.endDistance {
            if leftAt == nil { leftAt = time }
            if let leftAt, time - leftAt >= rules.endDelay { return stop() }
        } else {
            leftAt = nil
            if let previousTime, let previousDistance, previousDistance <= rules.endDistance {
                active?.duration += time - previousTime
                active?.endedAt = date
            }
        }
        return active
    }

    mutating func expire(at time: TimeInterval) -> Encounter? {
        guard let previousTime, time - previousTime > rules.maximumObservationGap else { return nil }
        return stop()
    }

    mutating func stop() -> Encounter? {
        let result = active
        active = nil
        enteredAt = nil
        leftAt = nil
        previousTime = nil
        previousDistance = nil
        return result
    }
}

enum RevealPolicy {
    static func allows(isPublic: Bool, requiredSeconds: Int, totalSeconds: TimeInterval) -> Bool {
        isPublic && requiredSeconds >= 0 && totalSeconds >= Double(requiredSeconds)
    }
}
