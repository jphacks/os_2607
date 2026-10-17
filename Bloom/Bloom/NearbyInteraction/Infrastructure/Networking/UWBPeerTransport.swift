import Foundation
import Network

@MainActor
final class UWBPeerTransport {
    static let serviceType = "_bloom-uwb._tcp"
    let serviceName = "UWB-" + UUID().uuidString.prefix(6)
    private var endpoints: [String: Bonjour.Endpoint] = [:]
    private var acceptingConnection = false

    private var parameters: NWParametersBuilder<TCP> {
        NWParametersBuilder { TCP().connectionTimeout(15) }.peerToPeerIncluded(true)
    }

    func browse(update: @escaping @MainActor @Sendable ([UWBPeer]) -> Void,
                status: @escaping @MainActor @Sendable (String) -> Void) async throws {
        defer { endpoints = [:] }
        let browser = NetworkBrowser(for: .bonjour(Self.serviceType), using: parameters.parameters)
            .onStateUpdate { _, state in
                if case .waiting(let error) = state {
                    status("端末探索を待機中: \(error.localizedDescription)。ローカルネットワークの許可を確認してください。")
                }
            }
        try await browser.run { discovered in
            self.endpoints = Dictionary(uniqueKeysWithValues: discovered.map { ($0.id, $0) })
            update(discovered.map { UWBPeer(id: $0.id, name: $0.name) }.sorted { $0.name < $1.name })
        }
    }

    func host(status: @escaping @MainActor @Sendable (String) -> Void,
              connected: @escaping @MainActor @Sendable (NetworkConnection<TCP>) async -> Void) async throws {
        let listener = try NetworkListener(for: .bonjour(name: serviceName, type: Self.serviceType), using: parameters)
            .onStateUpdate { _, state in
                switch state {
                case .ready: status("接続待ち：\(self.serviceName)")
                case .waiting(let error): status("接続待機中: \(error.localizedDescription)")
                default: break
                }
            }
        try await listener.run { connection in
            guard !self.acceptingConnection else { return }
            self.acceptingConnection = true
            defer { self.acceptingConnection = false }
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
