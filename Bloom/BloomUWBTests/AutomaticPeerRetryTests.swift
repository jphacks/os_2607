import Testing
@testable import Bloom

struct AutomaticPeerRetryTests {
    @Test func onlyOneSideInitiatesAndFailuresCanRetry() {
        var first = AutomaticPeerRetry()
        var second = AutomaticPeerRetry()
        let attempt1 = first.shouldAttempt(peerID: "b", localName: "a", remoteName: "b", time: 0)
        #expect(attempt1)
        let attempt2 = second.shouldAttempt(peerID: "a", localName: "b", remoteName: "a", time: 0)
        #expect(!attempt2)
        let attempt3 = first.shouldAttempt(peerID: "b", localName: "a", remoteName: "b", time: 4.99)
        #expect(!attempt3)
        let attempt4 = first.shouldAttempt(peerID: "b", localName: "a", remoteName: "b", time: 5)
        #expect(attempt4)
        let attempt5 = first.shouldAttempt(peerID: "self", localName: "a", remoteName: "a", time: 6)
        #expect(!attempt5)
    }

    @Test func peersHaveIndependentSchedulesAndReappearanceResetsRetry() {
        var scheduler = AutomaticPeerRetry()
        let attempt6 = scheduler.shouldAttempt(peerID: "b", localName: "a", remoteName: "b", time: 0)
        #expect(attempt6)
        let attempt7 = scheduler.shouldAttempt(peerID: "c", localName: "a", remoteName: "c", time: 1)
        #expect(attempt7)
        scheduler.retainOnly(["c"])
        let attempt8 = scheduler.shouldAttempt(peerID: "b", localName: "a", remoteName: "b", time: 2)
        #expect(attempt8)
        let attempt9 = scheduler.shouldAttempt(peerID: "c", localName: "a", remoteName: "c", time: 2)
        #expect(!attempt9)
    }
}
