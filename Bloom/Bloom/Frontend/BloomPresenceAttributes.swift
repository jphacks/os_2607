import ActivityKit
import Foundation

// Keep this wire format identical in the app and the Live Activity extension.
nonisolated struct BloomPresenceAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isParticipating: Bool
    }
    let startedAt: Date
}
