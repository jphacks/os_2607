import Foundation
import Network

nonisolated enum UWBConnectionCapacity: Sendable {
    case single
    case unlimited

    func allows(activeConnectionCount: Int) -> Bool {
        switch self {
        case .single:
            activeConnectionCount == 0
        case .unlimited:
            true
        }
    }
}

@MainActor
final class UWBPeerTransport {
    static let serviceType = "_bloom-uwb._tcp"
    let serviceName = "UWB-" + UUID().uuidString.prefix(6)
    private var endpoints: [String: Bonjour.Endpoint] = [:]
    private var activeConnectionCount = 0

    private var parameters: NWParametersBuilder<TCP> {
        NWParametersBuilder { TCP().connectionTimeout(15) }.peerToPeerIncluded(true)
    }

    func browse(update: @escaping @MainActor @Sendable ([UWBPeer]) -> Void,
                status: @escaping @MainActor @Sendable (String) -> Void) async throws {
        defer { endpoints = [:] }
        let browser = NetworkBrowser(for: .bonjour(Self.serviceType), using: parameters.parameters)
            .onStateUpdate { _, state in
                if case let .waiting(error) = state {
                    status("端末探索を待機中: \(error.localizedDescription)。ローカルネットワークの許可を確認してください。")
                }
            }
        try await browser.run { discovered in
            let remotePeers = discovered.filter { $0.name != self.serviceName }
            self.endpoints = Dictionary(uniqueKeysWithValues: remotePeers.map { ($0.id, $0) })
            update(remotePeers.map { UWBPeer(id: $0.id, name: $0.name) }.sorted { $0.name < $1.name })
        }
    }

    func host(connectionCapacity: UWBConnectionCapacity = .single,
              status: @escaping @MainActor @Sendable (String) -> Void,
              connected: @escaping @MainActor @Sendable (NetworkConnection<TCP>) async -> Void) async throws {
        let listener = try NetworkListener(for: .bonjour(name: serviceName, type: Self.serviceType), using: parameters)
            .onStateUpdate { _, state in
                switch state {
                case .ready: status("接続待ち：\(self.serviceName)")
                case let .waiting(error): status("接続待機中: \(error.localizedDescription)")
                default: break
                }
            }
        try await listener.run { connection in
            guard connectionCapacity.allows(activeConnectionCount: self.activeConnectionCount) else {
                return
            }
            self.activeConnectionCount += 1
            defer { self.activeConnectionCount -= 1 }
            await connected(connection)
        }
    }

    func connection(to peer: UWBPeer) throws -> NetworkConnection<TCP> {
        guard let endpoint = endpoints[peer.id] else {
            throw UWBFailure.message("相手が見つかりません。再度探索してください。")
        }
        return NetworkConnection(to: endpoint, using: parameters)
    }

    static func send(_ message: UWBWireMessage, on connection: NetworkConnection<TCP>) async throws {
        try await connection.send(UWBWireCodec.encode(message))
    }

    static func receive(on connection: NetworkConnection<TCP>) async throws -> UWBWireMessage {
        let header = try await connection.receive(exactly: 4)
        let length = try UWBWireCodec.bodyLength(header.content)
        let body = try await connection.receive(exactly: length)
        guard body.content.count == length else { throw UWBFailure.message("相手との接続が終了しました。") }
        let message = try JSONDecoder().decode(UWBWireMessage.self, from: body.content)
        guard message.version == 1 else { throw UWBFailure.message("通信バージョンが一致しません。") }
        return message
    }
}
