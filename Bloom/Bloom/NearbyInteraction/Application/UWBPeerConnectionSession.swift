import Foundation
import Network

@MainActor
final class UWBPeerConnectionSession {
    let id: UUID
    let discoveryID: String?
    let peerName: String?

    private let coordinator = UWBSessionCoordinator()
    private var task: Task<Void, Never>?

    var isRunning: Bool {
        task != nil
    }

    init(id: UUID = UUID(), discoveryID: String?, peerName: String?) {
        self.id = id
        self.discoveryID = discoveryID
        self.peerName = peerName
    }

    func start(
        on connection: NetworkConnection<TCP>,
        localPersonID: UUID,
        event: @escaping @MainActor @Sendable (UWBSessionEvent) -> Void,
        finished: @escaping @MainActor @Sendable (UWBPeerConnectionIssue) -> Void
    ) {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            let issue: UWBPeerConnectionIssue
            do {
                try await coordinator.run(on: connection, personID: localPersonID, event: event)
                issue = .sessionEnded
            } catch is CancellationError {
                task = nil
                return
            } catch {
                issue = .transportFailure(message: error.localizedDescription)
            }
            task = nil
            finished(issue)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        coordinator.stop()
    }
}
