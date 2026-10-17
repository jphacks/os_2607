import Foundation

enum UWBMockSource {
    static func samples() -> AsyncStream<UWBObservation?> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                let personID = UUID()
                var index = 0
                do {
                    while !Task.isCancelled {
                        let angle = Double(index) * 0.12
                        let direction = UWBDirection(x: sin(angle) * 0.6, y: sin(angle / 2) * 0.3, z: -1)
                        let sample: UWBObservation? = index % 40 >= 32 ? nil : UWBObservation(
                            personID: personID, distanceMeters: 1.5 + sin(angle),
                            direction: index % 40 >= 26 ? nil : direction
                        )
                        continuation.yield(sample)
                        index += 1
                        try await Task.sleep(for: .milliseconds(250))
                    }
                } catch { }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
