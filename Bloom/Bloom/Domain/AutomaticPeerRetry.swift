import Foundation

/// Temporary discovery names elect one initiator without exposing device IDs in the UI.
nonisolated struct AutomaticPeerRetry {
    var retryInterval: TimeInterval = 5
    private var nextAttempt: [String: TimeInterval] = [:]

    mutating func shouldAttempt(peerID: String, localName: String, remoteName: String, time: TimeInterval) -> Bool {
        guard time.isFinite, localName < remoteName else { return false }
        if let next = nextAttempt[peerID], time < next { return false }
        nextAttempt[peerID] = time + retryInterval
        return true
    }

    mutating func retainOnly(_ ids: Set<String>) {
        nextAttempt = nextAttempt.filter { ids.contains($0.key) }
    }
}
