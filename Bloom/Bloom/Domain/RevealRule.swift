import Foundation

enum RevealRule {
    static func allows(isPublic: Bool, requiredSeconds: Int, accumulatedSeconds: TimeInterval) -> Bool {
        isPublic && requiredSeconds >= 0 && accumulatedSeconds.isFinite
            && accumulatedSeconds >= Double(requiredSeconds)
    }
}
