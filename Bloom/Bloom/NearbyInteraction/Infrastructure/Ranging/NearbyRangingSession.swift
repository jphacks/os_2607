import Foundation
import NearbyInteraction

nonisolated enum UWBRangingEvent: Sendable {
    case observation(UWBObservation)
    case unavailable(String)
    case failed(String)
}

/// NISessionDelegate is the current public NI API, not a deprecated API.
/// Its default main queue delivery is confined here; consumers use AsyncStream.
@MainActor
final class NearbyRangingSession: NSObject, @preconcurrency NISessionDelegate {
    let events: AsyncStream<UWBRangingEvent>
    private let continuation: AsyncStream<UWBRangingEvent>.Continuation
    private var session: NISession?
    private var configuration: NINearbyPeerConfiguration?
    private var personID: UUID?

    static var isSupported: Bool {
        NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }

    override init() {
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
        super.init()
    }

    func prepare() throws -> Data {
        guard Self.isSupported else { throw UWBFailure.message("この端末はUWB距離計測に対応していません。") }
        let session = NISession()
        self.session = session
        session.delegate = self
        guard let token = session.discoveryToken else {
            throw UWBFailure.message("計測トークンを取得できません。再度開始してください。")
        }
        return try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    func start(personID: UUID, tokenData: Data) throws {
        guard let session,
              let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: tokenData) else {
            throw UWBFailure.message("計測トークンを読み取れません。")
        }
        self.personID = personID
        let configuration = NINearbyPeerConfiguration(peerToken: token)
        self.configuration = configuration
        session.run(configuration)
    }

    func stop() {
        session?.delegate = nil
        session?.invalidate()
        session = nil
        configuration = nil
        personID = nil
        continuation.finish()
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard session === self.session, let personID,
              let object = nearbyObjects.first(where: { $0.discoveryToken == configuration?.peerDiscoveryToken }) else { return }
        let direction = object.direction.flatMap {
            UWBDirection(x: Double($0.x), y: Double($0.y), z: Double($0.z))
        }
        continuation.yield(.observation(UWBObservation(
            personID: personID, distanceMeters: object.distance.map(Double.init), direction: direction
        )))
    }

    func sessionWasSuspended(_ session: NISession) {
        guard session === self.session else { return }
        continuation.yield(.unavailable("計測が一時停止しました。"))
    }

    func sessionSuspensionEnded(_ session: NISession) {
        guard session === self.session, let configuration else { return }
        continuation.yield(.unavailable("計測を再開しています。"))
        session.run(configuration)
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        guard session === self.session else { return }
        switch reason {
        case .timeout:
            continuation.yield(.failed("相手を見失いました。再接続してください。"))
        case .peerEnded:
            continuation.yield(.failed("相手が計測を終了しました。再接続してください。"))
        @unknown default:
            continuation.yield(.failed("計測が終了しました。再接続してください。"))
        }
    }

    func session(_ session: NISession, didInvalidateWith error: any Error) {
        guard session === self.session else { return }
        continuation.yield(.failed(invalidationMessage(for: error)))
    }

    private func invalidationMessage(for error: any Error) -> String {
        switch error {
        case NIError.userDidNotAllow:
            "Nearby Interactionが許可されていません。設定で許可してから再接続してください。"
        case NIError.incompatiblePeerDevice:
            "相手の端末はこのUWB計測に対応していません。"
        case NIError.activeSessionsLimitExceeded,
             NIError.activeExtendedDistanceSessionsLimitExceeded:
            "同時に利用できるUWBセッション数を超えました。ほかの計測を終了してから再接続してください。"
        case NIError.invalidConfiguration:
            "計測情報が無効です。相手との接続をやり直してください。"
        case NIError.resourceUsageTimeout:
            "UWBセッションがタイムアウトしました。相手との接続をやり直してください。"
        default:
            "計測できません: \(error.localizedDescription)。再接続してください。"
        }
    }
}
