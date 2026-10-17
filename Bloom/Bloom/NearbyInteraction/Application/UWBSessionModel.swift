import Foundation
import Network
import Observation

nonisolated enum UWBSessionState: Equatable, Sendable {
    case idle(status: String)
    case hosting(status: String)
    case browsing(peers: [UWBPeer], status: String)
    case connecting(peerName: String, status: String)
    case measuring(peerName: String?, observation: UWBObservation?, status: String)

    var status: String {
        switch self {
        case let .idle(status), let .hosting(status), let .browsing(_, status),
             let .connecting(_, status), let .measuring(_, _, status):
            status
        }
    }
}

@MainActor
@Observable
final class UWBSessionModel {
    private enum MeasurementOrigin {
        case hosting
        case browsing
    }

    private(set) var state = UWBSessionState.idle(status: "2台の端末でこの画面を開いてください。")
    let isSupported = NearbyRangingSession.isSupported

    @ObservationIgnored private let personID = LocalPersonIdentity.load()
    @ObservationIgnored private var transport = UWBPeerTransport()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var coordinator: UWBSessionCoordinator?
    @ObservationIgnored private var generation = UUID()

    var peers: [UWBPeer] {
        guard case let .browsing(peers, _) = state else { return [] }
        return peers
    }

    var observation: UWBObservation? {
        guard case let .measuring(_, observation, _) = state else { return nil }
        return observation
    }

    var status: String { state.status }

    var isRunning: Bool {
        if case .idle = state { false } else { true }
    }

    var peerName: String? {
        switch state {
        case let .connecting(peerName, _): peerName
        case let .measuring(peerName, _, _): peerName
        default: nil
        }
    }

    var localName: String { transport.serviceName }

    func host() {
        stop()
        guard requireSupport() else { return }
        state = .hosting(status: "接続を準備しています。")
        let generation = generation
        let transport = transport
        task = Task { [weak self] in
            do {
                try await transport.host { [weak self] status in
                    self?.updateHostingStatus(status, generation: generation)
                } connected: { [weak self] connection in
                    guard let self, self.generation == generation, !Task.isCancelled else { return }
                    await self.measure(on: connection, origin: .hosting, generation: generation)
                }
            } catch {
                self?.finish(error, generation: generation)
            }
        }
    }

    func browse() {
        stop()
        guard requireSupport() else { return }
        state = .browsing(peers: [], status: "接続待ちの端末を探しています。")
        let generation = generation
        let transport = transport
        task = Task { [weak self] in
            do {
                try await transport.browse { [weak self] peers in
                    self?.updatePeers(peers, generation: generation)
                } status: { [weak self] status in
                    self?.updateBrowsingStatus(status, generation: generation)
                }
            } catch {
                self?.finish(error, generation: generation)
            }
        }
    }

    func connect(to peer: UWBPeer) {
        do {
            // Resolve before stopping the browser, which clears its endpoint map.
            let connection = try transport.connection(to: peer)
            stop()
            guard requireSupport() else { return }
            state = .connecting(peerName: peer.name, status: state.status)
            let generation = generation
            task = Task {
                await measure(on: connection, origin: .browsing, generation: generation)
            }
        } catch {
            guard case let .browsing(peers, _) = state else { return }
            state = .browsing(peers: peers, status: error.localizedDescription)
        }
    }

    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        coordinator?.stop()
        coordinator = nil
        transport = UWBPeerTransport()
        state = .idle(status: "停止中です。接続方法を選んでください。")
    }

    private func requireSupport() -> Bool {
        guard isSupported else {
            state = .idle(status: "この端末はUWB計測に対応していません。")
            return false
        }
        return true
    }

    private func measure(
        on connection: NetworkConnection<TCP>,
        origin: MeasurementOrigin,
        generation: UUID
    ) async {
        let coordinator = UWBSessionCoordinator()
        self.coordinator = coordinator
        state = .measuring(
            peerName: peerName,
            observation: nil,
            status: "接続・計測情報を交換しています。"
        )
        defer { finishMeasurement(coordinator, origin: origin, generation: generation) }

        do {
            try await coordinator.run(on: connection, personID: personID) { [weak self] event in
                self?.handle(event, generation: generation)
            }
        } catch {
            guard isCurrent(generation) else { return }
            updateMeasurement(status: error.localizedDescription + " 接続をやり直してください。")
        }
    }

    private func handle(_ event: UWBSessionEvent, generation: UUID) {
        guard self.generation == generation else { return }
        switch event {
        case let .identified(remoteID):
            let name = peerName ?? "相手 \(remoteID.uuidString.prefix(6))"
            state = .measuring(
                peerName: name,
                observation: nil,
                status: "距離・方向を取得中です。端末の背面を相手に向けてください。"
            )
        case let .observation(observation):
            state = .measuring(
                peerName: peerName,
                observation: observation,
                status: observation.direction == nil
                    ? "方向を取得中です。端末を相手に向けてください。"
                    : "計測中"
            )
        case let .unavailable(status):
            state = .measuring(peerName: peerName, observation: nil, status: status)
        }
    }

    private func finishMeasurement(
        _ coordinator: UWBSessionCoordinator,
        origin: MeasurementOrigin,
        generation: UUID
    ) {
        coordinator.stop()
        guard self.generation == generation else { return }
        self.coordinator = nil
        let status = state.status
        switch origin {
        case .hosting:
            state = .hosting(status: status)
        case .browsing:
            state = .idle(status: status)
        }
    }

    private func updateHostingStatus(_ status: String, generation: UUID) {
        guard self.generation == generation, case .hosting = state else { return }
        state = .hosting(status: status)
    }

    private func updatePeers(_ peers: [UWBPeer], generation: UUID) {
        guard self.generation == generation, case .browsing = state else { return }
        let status = peers.isEmpty
            ? "相手の端末で「接続を待つ」を押してください。"
            : "接続する端末を選んでください。"
        state = .browsing(peers: peers, status: status)
    }

    private func updateBrowsingStatus(_ status: String, generation: UUID) {
        guard self.generation == generation, case let .browsing(peers, _) = state else { return }
        state = .browsing(peers: peers, status: status)
    }

    private func updateMeasurement(status: String) {
        guard case let .measuring(peerName, observation, _) = state else { return }
        state = .measuring(peerName: peerName, observation: observation, status: status)
    }

    private func isCurrent(_ generation: UUID) -> Bool {
        self.generation == generation && !Task.isCancelled
    }

    private func finish(_ error: any Error, generation: UUID) {
        guard isCurrent(generation) else { return }
        state = .idle(status: error.localizedDescription)
    }
}
