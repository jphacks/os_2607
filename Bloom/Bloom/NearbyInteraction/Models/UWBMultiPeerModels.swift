import Foundation

/// The lifecycle of one connection. Each connection owns one Nearby Interaction session.
nonisolated enum UWBPeerConnectionState: Sendable, Equatable {
    case connecting
    case measuring
    case unavailable(message: String)
    case failed(message: String)
}

/// SDK-independent data for one nearby device.
///
/// Use `id` for the lifetime of this connection and `personID` as the persistent identity
/// after the handshake completes. A discovery token is deliberately never exposed here.
nonisolated struct UWBPeerConnection: Identifiable, Sendable, Equatable {
    let id: UUID
    let personID: UUID?
    let peerName: String?
    let state: UWBPeerConnectionState
    let observation: UWBObservation?
}

/// Incremental updates for renderers that don't use Observation, including a future AR layer.
nonisolated enum UWBMultiPeerEvent: Sendable, Equatable {
    case discoveredPeersChanged([UWBPeer])
    case connectionChanged(UWBPeerConnection)
    case connectionRemoved(id: UUID)
    case statusChanged(String)
}

/// Deterministic connection state shared by Observation clients and async renderers.
nonisolated struct UWBMultiPeerConnectionStore: Sendable, Equatable {
    private(set) var connections: [UWBPeerConnection] = []

    var observations: [UWBObservation] {
        connections.compactMap(\.observation)
    }

    func connection(for personID: UUID) -> UWBPeerConnection? {
        connections.first { $0.personID == personID }
    }

    mutating func update(_ connection: UWBPeerConnection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        connections.sort {
            ($0.peerName ?? $0.id.uuidString) < ($1.peerName ?? $1.id.uuidString)
        }
    }

    @discardableResult
    mutating func remove(id: UUID) -> Bool {
        guard connections.contains(where: { $0.id == id }) else { return false }
        connections.removeAll { $0.id == id }
        return true
    }
}
