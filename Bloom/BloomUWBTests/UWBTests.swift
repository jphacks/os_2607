import Foundation
import Testing
@testable import Bloom

struct UWBDirectionTests {
    @Test func `Direction is normalized and exposes angles`() throws {
        let direction = try #require(UWBDirection(x: 3, y: 4, z: 0))

        #expect(abs(direction.x - 0.6) < 0.000_001)
        #expect(abs(direction.y - 0.8) < 0.000_001)
        #expect(abs(direction.z) < 0.000_001)
        #expect(abs((try #require(direction.azimuthDegrees)) - 90) < 0.000_001)
        #expect(abs(direction.elevationDegrees - 53.130_102) < 0.000_001)
    }

    @Test(arguments: [
        (Double.zero, Double.zero, Double.zero),
        (Double.nan, Double.zero, Double.zero),
        (Double.infinity, Double.zero, Double.zero),
    ])
    func `Invalid direction is rejected`(x: Double, y: Double, z: Double) {
        #expect(UWBDirection(x: x, y: y, z: z) == nil)
    }

    @Test(arguments: [Double.nan, Double.infinity, -0.01])
    func `Invalid distance becomes unavailable`(_ distance: Double) {
        let observation = UWBObservation(
            personID: UUID(),
            distanceMeters: distance,
            direction: nil
        )

        #expect(observation.distanceMeters == nil)
    }
}

struct UWBMultiPeerConnectionStoreTests {
    @Test func `Connections update by connection identity and remain sorted`() throws {
        let aliceID = UUID()
        let bobID = UUID()
        let alicePersonID = UUID()
        let bobPersonID = UUID()
        var store = UWBMultiPeerConnectionStore()

        store.update(connection(id: bobID, personID: nil, name: "Bob", distance: nil))
        store.update(connection(id: aliceID, personID: alicePersonID, name: "Alice", distance: 1.5))
        store.update(connection(id: bobID, personID: bobPersonID, name: "Bob", distance: 2.5))

        #expect(store.connections.map(\.id) == [aliceID, bobID])
        #expect(store.connections.count == 2)
        #expect(store.observations.map(\.distanceMeters) == [1.5, 2.5])
        #expect(store.connection(for: bobPersonID)?.id == bobID)
        #expect(store.connections(for: bobPersonID, excluding: aliceID).map(\.id) == [bobID])

        let removedExisting = store.remove(id: aliceID)
        let removedMissing = store.remove(id: aliceID)
        #expect(removedExisting)
        #expect(!removedMissing)
        #expect(store.connections.map(\.id) == [bobID])
    }

    private func connection(
        id: UUID,
        personID: UUID?,
        name: String,
        distance: Double?
    ) -> UWBPeerConnection {
        UWBPeerConnection(
            id: id,
            personID: personID,
            peerName: name,
            state: personID == nil ? .connecting : .measuring,
            observation: personID.map {
                UWBObservation(personID: $0, distanceMeters: distance, direction: nil)
            }
        )
    }
}

struct UWBPeerConnectionIssueTests {
    @Test func `Issue preserves a typed reason and readable description`() {
        let unavailable = UWBPeerConnectionIssue.rangingUnavailable(message: "not visible")

        #expect(unavailable.errorDescription == "not visible")
        #expect(UWBPeerConnectionIssue.duplicateConnection.errorDescription != nil)
        #expect(UWBPeerConnectionIssue.sessionEnded.errorDescription != nil)
    }
}

struct UWBWireProtocolTests {
    @Test func `Hello round trips through bounded framing`() throws {
        let personID = UUID()
        let token = Data([1, 2, 3])
        let framed = try UWBWireCodec.encode(.hello(personID: personID, token: token))
        let length = try UWBWireCodec.bodyLength(framed.prefix(4))
        let decoded = try JSONDecoder().decode(UWBWireMessage.self, from: framed.dropFirst(4))
        let (decodedID, decodedToken) = try decoded.validatedHello(localID: UUID())

        #expect(length == framed.count - 4)
        #expect(decodedID == personID)
        #expect(decodedToken == token)
    }

    @Test(arguments: [
        Data(),
        Data([0]),
        Data([0, 0, 0, 0]),
        Data([0, 0, 128, 1]),
    ])
    func `Invalid frame length is rejected`(_ header: Data) {
        #expect(throws: (any Error).self) {
            try UWBWireCodec.bodyLength(header)
        }
    }

    @Test func `Self identity and oversized token are rejected`() {
        let personID = UUID()

        #expect(throws: (any Error).self) {
            try UWBWireMessage.hello(personID: personID, token: Data([1]))
                .validatedHello(localID: personID)
        }
        #expect(throws: (any Error).self) {
            try UWBWireMessage.hello(personID: UUID(), token: Data(repeating: 0, count: 16_385))
                .validatedHello(localID: personID)
        }
    }
}

struct UWBTimeoutTests {
    @Test func `Completed operation wins timeout race`() async throws {
        let value = try await withUWBTimeout(seconds: 1) { 42 }
        #expect(value == 42)
    }

    @Test func `Expired operation throws`() async {
        await #expect(throws: (any Error).self) {
            try await withUWBTimeout(seconds: 0) {
                try await Task.sleep(for: .seconds(1))
                return 42
            }
        }
    }
}
