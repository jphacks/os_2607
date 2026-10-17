import Foundation

/// SDK-independent values. Axes are relative to a portrait device: +x right,
/// +y up, -z away from the screen toward the other device.
nonisolated struct UWBDirection: Sendable, Equatable {
    let x: Double
    let y: Double
    let z: Double

    init?(x: Double, y: Double, z: Double) {
        let length = sqrt(x * x + y * y + z * z)
        guard length.isFinite, length > 0.0001 else { return nil }
        self.x = x / length
        self.y = y / length
        self.z = z / length
    }

    var azimuthDegrees: Double? {
        guard hypot(x, z) > 0.0001 else { return nil }
        return atan2(x, -z) * 180 / .pi
    }

    var elevationDegrees: Double { atan2(y, hypot(x, z)) * 180 / .pi }
}

nonisolated struct UWBObservation: Sendable, Equatable {
    let personID: UUID
    let observedAt: Date
    let distanceMeters: Double?
    let direction: UWBDirection?

    init(personID: UUID, observedAt: Date = .now, distanceMeters: Double?, direction: UWBDirection?) {
        self.personID = personID
        self.observedAt = observedAt
        self.distanceMeters = distanceMeters.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        self.direction = direction
    }
}

nonisolated struct UWBPeer: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
}

nonisolated enum UWBFailure: LocalizedError, Sendable {
    case message(String)
    var errorDescription: String? {
        switch self {
        case let .message(text): text
        }
    }
}
