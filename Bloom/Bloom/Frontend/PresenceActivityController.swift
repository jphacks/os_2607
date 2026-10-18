// ActivityKit's Activity reference is not Sendable; all ownership stays on MainActor.
@preconcurrency import ActivityKit
import Foundation

/// A visible, user-dismissible Live Activity enables NI background ranging on iOS 18.4+.
@MainActor
final class PresenceActivityController {
    private var activity: Activity<BloomPresenceAttributes>?
    private var stateTask: Task<Void, Never>?
    var onEnded: (() -> Void)?

    var permitsBackgroundRanging: Bool {
        activity?.activityState == .active
    }

    func start() throws {
        guard activity == nil else { return }
        // Activities can outlive a terminated process. End those; never silently restore participation.
        let oldActivities = Activity<BloomPresenceAttributes>.activities
        Task {
            for old in oldActivities { await old.end(nil, dismissalPolicy: .immediate) }
        }
        let activity = try Activity.request(
            attributes: BloomPresenceAttributes(startedAt: Date()),
            content: ActivityContent(state: .init(isParticipating: true), staleDate: nil),
            pushType: nil
        )
        self.activity = activity
        stateTask = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { return }
                if state == .dismissed || state == .ended || state == .stale {
                    self?.onEnded?()
                    return
                }
            }
        }
    }

    func stop() {
        stateTask?.cancel()
        stateTask = nil
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(ActivityContent(state: .init(isParticipating: false), staleDate: nil),
                               dismissalPolicy: .immediate)
        }
    }
}
