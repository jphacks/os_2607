import Foundation
import Network
import Observation

/// UI-independent entry point for discovering and ranging with multiple nearby devices.
///
/// Observation clients can read `discoveredPeers` and `connections`. Render loops and other
/// async clients can consume `events`. The API doesn't expose Network or Nearby Interaction types.
@MainActor
@Observable
final class UWBMultiPeerSession {
    private(set) var discoveredPeers: [UWBPeer] = []
    private var connectionStore = UWBMultiPeerConnectionStore()
    let isSupported = NearbyRangingSession.isSupported

    @ObservationIgnored let events: AsyncStream<UWBMultiPeerEvent>

    @ObservationIgnored private let personID: UUID
    @ObservationIgnored private var eventContinuation: AsyncStream<UWBMultiPeerEvent>.Continuation
    @ObservationIgnored private var transport = UWBPeerTransport()
    @ObservationIgnored private var hostingTask: Task<Void, Never>?
    @ObservationIgnored private var browsingTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var coordinators: [UUID: UWBSessionCoordinator] = [:]
    @ObservationIgnored private var discoveryIDs: [UUID: String] = [:]

    init(personID: UUID = LocalPersonIdentity.load()) {
        self.personID = personID
        let stream = AsyncStream<UWBMultiPeerEvent>.makeStream(bufferingPolicy: .bufferingNewest(64))
        events = stream.stream
        eventContinuation = stream.continuation
    }

    var connections: [UWBPeerConnection] {
        connectionStore.connections
    }

    var observations: [UWBObservation] {
        connectionStore.observations
    }

    func connection(for personID: UUID) -> UWBPeerConnection? {
        connectionStore.connection(for: personID)
    }

    func startHosting() {
        guard hostingTask == nil, requireSupport() else { return }
        let transport = transport
        hostingTask = Task { [weak self] in
            do {
                try await transport.host(maximumConcurrentConnections: nil) { [weak self] status in
                    self?.emit(.statusChanged(status))
                } connected: { [weak self] connection in
                    self?.startConnection(on: connection, peerName: nil, discoveryID: nil)
                }
            } catch is CancellationError {
                // Explicit stop.
            } catch {
                self?.emit(.statusChanged(error.localizedDescription))
            }
            self?.hostingTask = nil
        }
    }

    func stopHosting() {
        hostingTask?.cancel()
        hostingTask = nil
    }

    func startBrowsing() {
        guard browsingTask == nil, requireSupport() else { return }
        let transport = transport
        browsingTask = Task { [weak self] in
            do {
                try await transport.browse { [weak self] peers in
                    guard let self else { return }
                    discoveredPeers = peers
                    emit(.discoveredPeersChanged(peers))
                } status: { [weak self] status in
                    self?.emit(.statusChanged(status))
                }
            } catch is CancellationError {
                // Explicit stop.
            } catch {
                self?.emit(.statusChanged(error.localizedDescription))
            }
            self?.browsingTask = nil
        }
    }

    func stopBrowsing() {
        browsingTask?.cancel()
        browsingTask = nil
        discoveredPeers = []
        emit(.discoveredPeersChanged([]))
    }

    @discardableResult
    func connect(to peer: UWBPeer) throws -> UUID {
        guard requireSupport() else {
            throw UWBFailure.message("この端末はUWB計測に対応していません。")
        }
        if let existing = discoveryIDs.first(where: { $0.value == peer.id })?.key {
            if connectionTasks[existing] != nil {
                return existing
            }
            disconnect(id: existing)
        }
        let connection = try transport.connection(to: peer)
        return startConnection(on: connection, peerName: peer.name, discoveryID: peer.id)
    }

    func disconnect(id: UUID) {
        connectionTasks[id]?.cancel()
        coordinators[id]?.stop()
        connectionTasks[id] = nil
        coordinators[id] = nil
        discoveryIDs[id] = nil
        guard connectionStore.remove(id: id) else { return }
        emit(.connectionRemoved(id: id))
    }

    func disconnect(from personID: UUID) {
        connections.filter { $0.personID == personID }.forEach { disconnect(id: $0.id) }
    }

    func stop() {
        stopHosting()
        stopBrowsing()
        connections.map(\.id).forEach(disconnect(id:))
        transport = UWBPeerTransport()
    }

    @discardableResult
    private func startConnection(
        on connection: NetworkConnection<TCP>,
        peerName: String?,
        discoveryID: String?
    ) -> UUID {
        let id = UUID()
        let coordinator = UWBSessionCoordinator()
        coordinators[id] = coordinator
        discoveryIDs[id] = discoveryID
        updateConnection(
            UWBPeerConnection(
                id: id,
                personID: nil,
                peerName: peerName,
                state: .connecting,
                observation: nil
            )
        )

        connectionTasks[id] = Task { [weak self] in
            guard let self else { return }
            do {
                try await coordinator.run(on: connection, personID: personID) { [weak self] event in
                    self?.handle(event, connectionID: id)
                }
                if !Task.isCancelled {
                    markFailed(id: id, message: "計測セッションが終了しました。")
                }
            } catch is CancellationError {
                // Explicit disconnect.
            } catch {
                markFailed(id: id, message: error.localizedDescription)
            }
            finishConnectionTask(id: id, coordinator: coordinator)
        }
        return id
    }

    private func handle(_ event: UWBSessionEvent, connectionID: UUID) {
        guard let current = connections.first(where: { $0.id == connectionID }) else { return }
        switch event {
        case let .identified(remoteID):
            let duplicates = connections.filter { $0.id != connectionID && $0.personID == remoteID }
            guard !duplicates.contains(where: { connectionTasks[$0.id] != nil }) else {
                markFailed(id: connectionID, message: "同じ端末との接続が既に存在します。")
                connectionTasks[connectionID]?.cancel()
                coordinators[connectionID]?.stop()
                return
            }
            duplicates.forEach { disconnect(id: $0.id) }
            updateConnection(
                UWBPeerConnection(
                    id: current.id,
                    personID: remoteID,
                    peerName: current.peerName ?? "相手 \(remoteID.uuidString.prefix(6))",
                    state: .measuring,
                    observation: nil
                )
            )
        case let .observation(observation):
            updateConnection(
                UWBPeerConnection(
                    id: current.id,
                    personID: observation.personID,
                    peerName: current.peerName,
                    state: .measuring,
                    observation: observation
                )
            )
        case let .unavailable(message):
            updateConnection(
                UWBPeerConnection(
                    id: current.id,
                    personID: current.personID,
                    peerName: current.peerName,
                    state: .unavailable(message: message),
                    observation: nil
                )
            )
        }
    }

    private func markFailed(id: UUID, message: String) {
        guard let current = connections.first(where: { $0.id == id }) else { return }
        updateConnection(
            UWBPeerConnection(
                id: current.id,
                personID: current.personID,
                peerName: current.peerName,
                state: .failed(message: message),
                observation: nil
            )
        )
    }

    private func updateConnection(_ connection: UWBPeerConnection) {
        connectionStore.update(connection)
        emit(.connectionChanged(connection))
    }

    private func finishConnectionTask(id: UUID, coordinator: UWBSessionCoordinator) {
        coordinator.stop()
        if coordinators[id] === coordinator {
            coordinators[id] = nil
            connectionTasks[id] = nil
        }
    }

    @discardableResult
    private func requireSupport() -> Bool {
        guard isSupported else {
            emit(.statusChanged("この端末はUWB計測に対応していません。"))
            return false
        }
        return true
    }

    private func emit(_ event: UWBMultiPeerEvent) {
        eventContinuation.yield(event)
    }
}
