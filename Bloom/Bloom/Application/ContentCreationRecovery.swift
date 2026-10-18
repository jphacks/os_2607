import Foundation

/// The existing DB only grants INSERT on content fields, not the generated ID.
/// Never blindly repeat a POST after a lost response: reconcile it using the pre-request snapshot.
@MainActor
final class ContentCreationRecovery {
    private struct Pending {
        let ownerID: UUID
        let previousIDs: Set<UUID>
        let input: ProfileContentCreateInput
    }
    private var pending: [UUID: Pending] = [:]

    func create(_ input: ProfileContentCreateInput, draftID: UUID, ownerID: UUID,
                repository: any ProfileRepository, isCurrent: () -> Bool = { true }) async throws -> ProfileContent {
        if let attempt = pending[draftID] {
            guard attempt.ownerID == ownerID else { throw BackendError.forbidden }
            let rows = try await repository.fetchContents(personID: ownerID)
            guard isCurrent() else { throw CancellationError() }
            let matches = rows.filter { row in
                !attempt.previousIDs.contains(row.id) && row.profileID == ownerID &&
                row.type == attempt.input.type && row.title == attempt.input.title.trimmingCharacters(in: .whitespacesAndNewlines) &&
                row.value == attempt.input.value.trimmingCharacters(in: .whitespacesAndNewlines) &&
                row.unlockAfterSeconds == attempt.input.unlockAfterSeconds && row.displayOrder == attempt.input.displayOrder &&
                row.isPublic == attempt.input.isPublic
            }
            guard matches.count == 1, let value = matches.first else { throw CreationUncertain() }
            pending[draftID] = nil
            return value
        }
        let previous = try await repository.fetchContents(personID: ownerID)
        guard isCurrent() else { throw CancellationError() }
        pending[draftID] = Pending(ownerID: ownerID, previousIDs: Set(previous.map(\.id)), input: input)
        do {
            let created = try await repository.createContent(input)
            pending[draftID] = nil
            return created
        } catch {
            // Validation and permission failures are known not to have inserted a row.
            if let error = error as? BackendError {
                switch error {
                case .validation, .forbidden, .unauthenticated, .configuration, .notFound:
                    pending[draftID] = nil
                default: break
                }
            }
            throw error
        }
    }
}

struct CreationUncertain: LocalizedError {
    var errorDescription: String? {
        "追加の結果を確認できません。重複を防ぐため再送を停止しました。再読み込みして保存済みの内容を確認してください。"
    }
}
