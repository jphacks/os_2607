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
    private(set) var status = "停止中です。"
    var localName: String { transport.serviceName }

    private(set) var discoveredPeers: [UWBPeer] = []
    private var connectionStore = UWBMultiPeerConnectionStore()
    let isSupported = NearbyRangingSession.isSupported

    @ObservationIgnored let events: AsyncStream<UWBMultiPeerEvent>

    @ObservationIgnored private let personID: UUID
    @ObservationIgnored private var eventContinuation: AsyncStream<UWBMultiPeerEvent>.Continuation
    @ObservationIgnored private var transport = UWBPeerTransport()
    @ObservationIgnored private var hostingTask: Task<Void, Never>?
    @ObservationIgnored private var browsingTask: Task<Void, Never>?
    @ObservationIgnored private var connectionSessions: [UUID: UWBPeerConnectionSession] = [:]

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
                try await transport.host(connectionCapacity: .unlimited) { [weak self] status in
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
                    self?.updateDiscoveredPeers(peers)
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
        updateDiscoveredPeers([])
    }

    @discardableResult
    func connect(to peer: UWBPeer) throws -> UUID {
        guard requireSupport() else {
            throw UWBFailure.message("この端末はUWB計測に対応していません。")
        }
        if let existing = connectionSession(forDiscoveryID: peer.id) {
            guard !existing.isRunning else { return existing.id }
            disconnect(id: existing.id)
        }
        let connection = try transport.connection(to: peer)
        return startConnection(on: connection, peerName: peer.name, discoveryID: peer.id)
    }

    func disconnect(id: UUID) {
        connectionSessions.removeValue(forKey: id)?.stop()
        guard connectionStore.remove(id: id) else { return }
        emit(.connectionRemoved(id: id))
    }

    func disconnect(from personID: UUID) {
        connectionStore.connections(for: personID).forEach { disconnect(id: $0.id) }
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
        let session = UWBPeerConnectionSession(discoveryID: discoveryID, peerName: peerName)
        connectionSessions[session.id] = session
        updateConnection(
            UWBPeerConnection(
                id: session.id,
                personID: nil,
                peerName: peerName,
                state: .connecting,
                observation: nil
            )
        )
        session.start(
            on: connection,
            localPersonID: personID,
            event: { [weak self] event in
                self?.handle(event, connectionID: session.id)
            },
            finished: { [weak self, weak session] issue in
                guard let self, let session else { return }
                finish(session, issue: issue)
            }
        )
        return session.id
    }

    private func handle(_ event: UWBSessionEvent, connectionID: UUID) {
        guard let current = connectionStore.connection(id: connectionID) else { return }
        switch event {
        case let .identified(remoteID):
            handleIdentification(remoteID, for: current)
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
                    state: .unavailable(reason: .rangingUnavailable(message: message)),
                    observation: nil
                )
            )
        }
    }

    private func handleIdentification(_ personID: UUID, for connection: UWBPeerConnection) {
        let duplicates = connectionStore.connections(for: personID, excluding: connection.id)
        guard !duplicates.contains(where: { connectionSessions[$0.id]?.isRunning == true }) else {
            failConnection(id: connection.id, issue: .duplicateConnection)
            connectionSessions.removeValue(forKey: connection.id)?.stop()
            return
        }
        duplicates.forEach { disconnect(id: $0.id) }
        updateConnection(
            UWBPeerConnection(
                id: connection.id,
                personID: personID,
                peerName: connection.peerName ?? "相手 \(personID.uuidString.prefix(6))",
                state: .measuring,
                observation: nil
            )
        )
    }

    private func finish(_ session: UWBPeerConnectionSession, issue: UWBPeerConnectionIssue) {
        guard connectionSessions[session.id] === session else { return }
        connectionSessions[session.id] = nil
        failConnection(id: session.id, issue: issue)
    }

    private func failConnection(id: UUID, issue: UWBPeerConnectionIssue) {
        guard let current = connectionStore.connection(id: id) else { return }
        updateConnection(
            UWBPeerConnection(
                id: current.id,
                personID: current.personID,
                peerName: current.peerName,
                state: .failed(reason: issue),
                observation: nil
            )
        )
    }

    private func connectionSession(forDiscoveryID discoveryID: String) -> UWBPeerConnectionSession? {
        connectionSessions.values.first { $0.discoveryID == discoveryID }
    }

    private func updateDiscoveredPeers(_ peers: [UWBPeer]) {
        discoveredPeers = peers
        emit(.discoveredPeersChanged(peers))
    }

    private func updateConnection(_ connection: UWBPeerConnection) {
        connectionStore.update(connection)
        emit(.connectionChanged(connection))
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
        if case let .statusChanged(message) = event { status = message }
        eventContinuation.yield(event)
    }
}
