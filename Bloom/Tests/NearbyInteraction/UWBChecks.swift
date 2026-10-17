import Foundation

@main
struct UWBChecks {
    @MainActor
    static func main() async throws {
        let local = UUID(), remote = UUID()
        let forward = UWBDirection(x: 0, y: 0, z: -1)!
        precondition(forward.azimuthDegrees == 0 && forward.elevationDegrees == 0)
        precondition(UWBDirection(x: 1, y: 0, z: 0)!.azimuthDegrees == 90)
        precondition(UWBDirection(x: -1, y: 0, z: 0)!.azimuthDegrees == -90)
        precondition(abs(UWBDirection(x: 0, y: 0, z: 1)!.azimuthDegrees!) == 180)
        let up = UWBDirection(x: 0, y: 1, z: 0)!
        precondition(up.azimuthDegrees == nil && up.elevationDegrees == 90)
        precondition(UWBDirection(x: 0, y: 0, z: 0) == nil)
        precondition(UWBDirection(x: .nan, y: 0, z: -1) == nil)
        precondition(abs(UWBDirection(x: 3, y: 0, z: -4)!.x - 0.6) < 0.00001)
        for invalid in [-1.0, .nan, .infinity] {
            precondition(UWBObservation(personID: remote, distanceMeters: invalid, direction: nil).distanceMeters == nil)
        }
        precondition(UWBObservation(personID: remote, distanceMeters: 0, direction: nil).distanceMeters == 0)

        let token = Data([0, 1, 2, 255])
        let encoded = try UWBWireCodec.encode(.hello(personID: remote, token: token))
        let length = try UWBWireCodec.bodyLength(encoded.prefix(4))
        precondition(length == encoded.count - 4)
        let decoded = try JSONDecoder().decode(UWBWireMessage.self, from: encoded.dropFirst(4))
        let (id, recovered) = try decoded.validatedHello(localID: local)
        precondition(id == remote && recovered == token)
        try expectFailure { _ = try decoded.validatedHello(localID: remote) }
        try expectFailure { _ = try UWBWireMessage.heartbeat.validatedHello(localID: local) }
        try expectFailure { _ = try UWBWireMessage.hello(personID: remote, token: Data()).validatedHello(localID: local) }
        try expectFailure { _ = try UWBWireMessage(version: 2, kind: .hello, personID: remote, discoveryToken: token).validatedHello(localID: local) }
        for header in [Data([0, 0, 0]), Data([0, 0, 0, 0]), Data([255, 255, 255, 255])] {
            try expectFailure { _ = try UWBWireCodec.bodyLength(header) }
        }
        try expectFailure { _ = try UWBWireCodec.encode(.hello(personID: remote, token: Data(repeating: 0, count: 40_000))) }
        let value = try await withUWBTimeout(seconds: 1) { 42 }
        precondition(value == 42)
        let start = ContinuousClock.now
        do {
            _ = try await withUWBTimeout(seconds: 0) {
                try await Task.sleep(for: .seconds(30))
                return 0
            }
            preconditionFailure("Timeout did not fire")
        } catch is UWBFailure { }
        precondition(start.duration(to: .now) < .seconds(2))
        let task = Task {
            try await withUWBTimeout(seconds: 30) {
                try await Task.sleep(for: .seconds(30))
                return 0
            }
        }
        task.cancel()
        do { _ = try await task.value; preconditionFailure("Cancellation did not propagate") }
        catch is CancellationError { }
        print("PASS: direction, missing values, framing, handshake, timeout, cancellation")
    }

    static func expectFailure(_ operation: () throws -> Void) throws {
        do { try operation(); preconditionFailure("Expected rejection") }
        catch is UWBFailure { }
    }
}
