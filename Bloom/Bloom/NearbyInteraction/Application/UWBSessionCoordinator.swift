import Foundation
import Network

nonisolated enum UWBSessionEvent: Sendable {
    case identified(UUID)
    case observation(UWBObservation)
    case unavailable(String)
}

@MainActor
final class UWBSessionCoordinator {
    private enum Timing {
        static let handshakeTimeout = 20
        static let heartbeatTimeout = 10
        static let heartbeatInterval = Duration.seconds(2)
        static let observationCheckInterval = Duration.milliseconds(500)
        static let observationLifetime = Duration.seconds(3)
    }

    private var ranging: NearbyRangingSession?
    private var lastObservation: ContinuousClock.Instant?

    func run(
        on connection: NetworkConnection<TCP>,
        personID: UUID,
        event: @escaping @MainActor @Sendable (UWBSessionEvent) -> Void
    ) async throws {
        let ranging = NearbyRangingSession()
        self.ranging = ranging
        defer {
            ranging.stop()
            if self.ranging === ranging {
                self.ranging = nil
                lastObservation = nil
            }
        }

        let remoteID = try await startRanging(ranging, on: connection, personID: personID)
        event(.identified(remoteID))
        try await runSessionTasks(ranging: ranging, connection: connection, event: event)
    }

    func stop() {
        ranging?.stop()
        ranging = nil
        lastObservation = nil
    }

    private func startRanging(
        _ ranging: NearbyRangingSession,
        on connection: NetworkConnection<TCP>,
        personID: UUID
    ) async throws -> UUID {
        let token = try ranging.prepare()
        let hello = try await withUWBTimeout(seconds: Timing.handshakeTimeout) {
            try await UWBPeerTransport.send(.hello(personID: personID, token: token), on: connection)
            return try await UWBPeerTransport.receive(on: connection)
        }
        try Task.checkCancellation()

        let (remoteID, remoteToken) = try hello.validatedHello(localID: personID)
        try ranging.start(personID: remoteID, tokenData: remoteToken)
        return remoteID
    }

    private func runSessionTasks(
        ranging: NearbyRangingSession,
        connection: NetworkConnection<TCP>,
        event: @escaping @MainActor @Sendable (UWBSessionEvent) -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor @Sendable in
                try await self.consumeRangingEvents(from: ranging, event: event)
            }
            group.addTask { @MainActor @Sendable in
                try await self.receiveHeartbeats(on: connection)
            }
            group.addTask { @MainActor @Sendable in
                try await self.sendHeartbeats(on: connection)
            }
            group.addTask { @MainActor @Sendable in
                try await self.monitorObservationFreshness(event: event)
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }

    private func consumeRangingEvents(
        from ranging: NearbyRangingSession,
        event: @escaping @MainActor @Sendable (UWBSessionEvent) -> Void
    ) async throws {
        for await rangingEvent in ranging.events {
            try Task.checkCancellation()
            switch rangingEvent {
            case let .observation(observation):
                lastObservation = .now
                event(.observation(observation))
            case let .unavailable(message):
                lastObservation = nil
                event(.unavailable(message))
            case let .failed(message):
                throw UWBFailure.message(message)
            }
        }
    }

    private func receiveHeartbeats(on connection: NetworkConnection<TCP>) async throws {
        while !Task.isCancelled {
            let message = try await withUWBTimeout(seconds: Timing.heartbeatTimeout) {
                try await UWBPeerTransport.receive(on: connection)
            }
            guard message.kind == .heartbeat,
                  message.personID == nil,
                  message.discoveryToken == nil else {
                throw UWBFailure.message("想定外の通信メッセージを受信しました。")
            }
        }
    }

    private func sendHeartbeats(on connection: NetworkConnection<TCP>) async throws {
        while !Task.isCancelled {
            try await UWBPeerTransport.send(.heartbeat, on: connection)
            try await Task.sleep(for: Timing.heartbeatInterval)
        }
    }

    private func monitorObservationFreshness(
        event: @escaping @MainActor @Sendable (UWBSessionEvent) -> Void
    ) async throws {
        while !Task.isCancelled {
            try await Task.sleep(for: Timing.observationCheckInterval)
            guard let lastObservation,
                  lastObservation.duration(to: .now) >= Timing.observationLifetime else { continue }
            self.lastObservation = nil
            event(.unavailable("計測値が更新されていません。端末を相手に向けてください。"))
        }
    }
}
