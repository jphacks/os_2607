import Foundation
import Observation

struct ProfileFieldDraft: Identifiable, Equatable {
    var id = UUID()
    var type: ProfileContentType = .text
    var title = ""
    var value = ""
    var unlockAfterSeconds = 60
    var displayOrder = 0
    var isPublic = false

    init() {}
    init(_ content: ProfileContent) {
        id = content.id; type = content.type; title = content.title; value = content.value
        unlockAfterSeconds = content.unlockAfterSeconds; displayOrder = content.displayOrder
        isPublic = content.isPublic
    }
    var createInput: ProfileContentCreateInput {
        ProfileContentCreateInput(type: type, title: title, value: value,
            unlockAfterSeconds: unlockAfterSeconds, displayOrder: displayOrder, isPublic: isPublic)
    }
    var updateInput: ProfileContentUpdateInput {
        ProfileContentUpdateInput(type: type, title: title, value: value,
            unlockAfterSeconds: unlockAfterSeconds, displayOrder: displayOrder, isPublic: isPublic)
    }
}

@MainActor @Observable
final class ProfileEditorModel {
    var displayName = ""
    var affiliation = ""
    var bio = ""
    var isDiscoverable = false
    var fields: [ProfileFieldDraft] = []
    private(set) var isBusy = false
    private(set) var isLoaded = false
    var errorMessage: String?
    var message: String?
    @ObservationIgnored private let repository: any ProfileRepository
    @ObservationIgnored private let ownerID: UUID
    @ObservationIgnored private var savedProfile: Profile?
    @ObservationIgnored private var savedFields: [UUID: ProfileContent] = [:]
    @ObservationIgnored private let creation = ContentCreationRecovery()
    @ObservationIgnored private var isValid = true

    init(repository: any ProfileRepository, ownerID: UUID) {
        self.repository = repository; self.ownerID = ownerID
    }
    func invalidate() { isValid = false; fields = []; savedFields = [:]; savedProfile = nil }

    func load() async {
        guard isValid, !isBusy else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            let profile = try await repository.fetchMyProfile()
            let contents = try await repository.fetchContents(personID: ownerID)
            guard isValid, profile.id == ownerID else { return }
            savedProfile = profile
            displayName = profile.displayName; affiliation = profile.affiliation ?? ""
            bio = profile.bio ?? ""; isDiscoverable = profile.isDiscoverable
            fields = contents.map(ProfileFieldDraft.init)
            savedFields = Dictionary(uniqueKeysWithValues: contents.map { ($0.id, $0) })
            isLoaded = true
        } catch { if isValid { errorMessage = error.localizedDescription } }
    }

    func addField() {
        guard !isBusy else { return }
        var field = ProfileFieldDraft()
        field.displayOrder = (fields.map(\.displayOrder).max() ?? -1) + 1
        fields.append(field)
    }
    func removeField(id: UUID) { guard !isBusy else { return }; fields.removeAll { $0.id == id } }

    func save() async -> Profile? {
        guard isValid, isLoaded, !isBusy, let savedProfile else { return nil }
        isBusy = true; errorMessage = nil; message = nil
        defer { isBusy = false }
        do {
            let updated = try await repository.updateProfile(ProfileUpdateInput(displayName: displayName,
                affiliation: affiliation, bio: bio, avatarPath: savedProfile.avatarPath, isDiscoverable: isDiscoverable))
            guard isValid else { return nil }
            self.savedProfile = updated
            for id in savedFields.keys.filter({ id in !fields.contains { $0.id == id } }) {
                do { try await repository.deleteContent(id: id) }
                catch BackendError.notFound { /* Already deleted on a previous attempt. */ }
                guard isValid else { return nil }
                savedFields[id] = nil
            }
            for draft in fields {
                guard isValid else { return nil }
                if let previous = savedFields[draft.id], ProfileFieldDraft(previous) == draft { continue }
                let value: ProfileContent
                if savedFields[draft.id] != nil {
                    value = try await repository.updateContent(id: draft.id, input: draft.updateInput)
                } else {
                    let created = try await creation.create(draft.createInput, draftID: draft.id, ownerID: ownerID, repository: repository, isCurrent: { self.isValid })
                    guard isValid else { return nil }
                    savedFields[created.id] = created
                    if let index = fields.firstIndex(where: { $0.id == draft.id }) { fields[index].id = created.id }
                    // Reconcile an earlier ambiguous response before accepting further edits.
                    value = created.type == draft.type && created.title == draft.title && created.value == draft.value &&
                        created.unlockAfterSeconds == draft.unlockAfterSeconds && created.displayOrder == draft.displayOrder &&
                        created.isPublic == draft.isPublic ? created :
                        try await repository.updateContent(id: created.id, input: draft.updateInput)
                }
                guard isValid else { return nil }
                savedFields[draft.id] = nil
                savedFields[value.id] = value
                if let index = fields.firstIndex(where: { $0.id == value.id }) { fields[index] = ProfileFieldDraft(value) }
            }
            message = "保存しました"
            return updated
        } catch {
            if isValid { errorMessage = "保存できなかった変更があります。再試行できます。\n" + error.localizedDescription }
            return nil
        }
    }
}
