import Foundation

nonisolated struct UWBWireMessage: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case hello
        case heartbeat
    }

    let version: Int
    let kind: Kind
    let personID: UUID?
    let discoveryToken: Data?

    static func hello(personID: UUID, token: Data) -> Self {
        Self(version: 1, kind: .hello, personID: personID, discoveryToken: token)
    }

    static let heartbeat = Self(
        version: 1,
        kind: .heartbeat,
        personID: nil,
        discoveryToken: nil
    )

    func validatedHello(localID: UUID) throws -> (UUID, Data) {
        guard version == 1, kind == .hello, let personID, personID != localID,
              let discoveryToken, !discoveryToken.isEmpty, discoveryToken.count <= 16_384 else {
            throw UWBFailure.message("相手の識別情報または計測トークンが不正です。")
        }
        return (personID, discoveryToken)
    }
}

/// Bounded length-prefix framing over TCP; does not assume one receive equals one send.
nonisolated enum UWBWireCodec {
    static let maximumBytes = 32_768

    static func encode(_ message: UWBWireMessage) throws -> Data {
        let body = try JSONEncoder().encode(message)
        guard body.count <= maximumBytes else { throw UWBFailure.message("通信データが大きすぎます。") }
        let count = UInt32(body.count)
        let header = Data([
            UInt8((count >> 24) & 255),
            UInt8((count >> 16) & 255),
            UInt8((count >> 8) & 255),
            UInt8(count & 255),
        ])
        return header + body
    }

    static func bodyLength(_ header: Data) throws -> Int {
        guard header.count == 4 else { throw UWBFailure.message("接続が終了しました。") }
        let count = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard count > 0, count <= maximumBytes else { throw UWBFailure.message("通信データの長さが不正です。") }
        return Int(count)
    }
}
