import Foundation

@MainActor
func withUWBTimeout<Value: Sendable>(seconds: Int,
    operation: @escaping @MainActor @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw UWBFailure.message("通信がタイムアウトしました。相手のアプリとネットワークを確認してください。")
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else { throw CancellationError() }
        return result
    }
}
