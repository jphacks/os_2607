import Foundation

nonisolated enum UWBPeerConnectionIssue: LocalizedError, Sendable, Equatable {
    case rangingUnavailable(message: String)
    case duplicateConnection
    case sessionEnded
    case transportFailure(message: String)

    var errorDescription: String? {
        switch self {
        case let .rangingUnavailable(message), let .transportFailure(message):
            message
        case .duplicateConnection:
            "同じ端末との接続が既に存在します。"
        case .sessionEnded:
            "計測セッションが終了しました。"
        }
    }
}

/// The lifecycle of one connection. Each connection owns one Nearby Interaction session.
nonisolated enum UWBPeerConnectionState: Sendable, Equatable {
    case connecting
    case measuring
    case unavailable(reason: UWBPeerConnectionIssue)
    case failed(reason: UWBPeerConnectionIssue)
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

    func connection(id: UUID) -> UWBPeerConnection? {
        connections.first { $0.id == id }
    }

    func connection(for personID: UUID) -> UWBPeerConnection? {
        connections.first { $0.personID == personID }
    }

    func connections(for personID: UUID, excluding id: UUID? = nil) -> [UWBPeerConnection] {
        connections.filter { $0.personID == personID && $0.id != id }
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
