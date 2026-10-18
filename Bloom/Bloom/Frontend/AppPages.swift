import SwiftUI

struct MessagesPage: View {
    var body: some View {
        ContentUnavailableView("メッセージは準備中です", systemImage: "bubble.left.and.bubble.right",
                               description: Text("メッセージの送受信にはまだ対応していません。"))
            .navigationTitle("メッセージ")
    }
}

struct EncounterHistoryPage: View {
    let proximity: UWBConnectionService
    @State private var confirmsDeletion = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("重なった時間を、\nあなたの記憶に。")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("\(proximity.records.count)回の出会い")
                        .font(.headline).foregroundStyle(.indigo)
                    Text("終了した出会いの実測時間を、このアカウントの履歴として端末に保存します。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .padding(.vertical, 16)
            }
            if let error = proximity.historyError {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("再試行") { proximity.retryHistory() }
                }
            }
            if proximity.records.isEmpty {
                ContentUnavailableView("まだ記録はありません", systemImage: "clock",
                                       description: Text("近くの人との出会いが終了すると、ここに記録されます。"))
            } else {
                Section {
                    ForEach(proximity.records) { record in EncounterHistoryRow(record: record, people: proximity.people) }
                } header: {
                    Text("この端末での出会い")
                } footer: {
                    Text("名前は現在公開を確認できる相手のみ表示します。待機中・観測が途切れた時間は含みません。")
                }
            }
        }
        .navigationTitle("出会いの履歴")
        .toolbar {
            Button("履歴を削除", systemImage: "trash", role: .destructive) { confirmsDeletion = true }
                .disabled(proximity.records.isEmpty)
        }
        .confirmationDialog("このアカウントの端末内履歴を削除しますか？", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("履歴と累計時間を削除", role: .destructive) { proximity.deleteHistory() }
        } message: {
            Text("時間条件を満たしていた公開項目も、時間が再びたまるまで非表示になります。")
        }
    }
}

private struct EncounterHistoryRow: View {
    let record: RecordedEncounter
    let people: [NearbyPerson]
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "leaf")
                .foregroundStyle(.indigo)
                .padding(12).background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(people.first { $0.id == record.personID }?.profile.displayName ?? "記録された出会い")
                    .font(.headline)
                Text(record.startedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
                Text(Duration.seconds(record.duration), format: .time(pattern: .minuteSecond))
                    .font(.system(.title3, design: .rounded, weight: .medium)).monospacedDigit()
            }
        }
        .padding(.vertical, 8)
    }
}

struct MyProfilePage: View {
    let profile: Profile
    let repository: any ProfileRepository
    let onSaved: (Profile) -> Void
    let onSignOut: () -> Void
    @State private var name = ""
    @State private var affiliation = ""
    @State private var bio = ""
    @State private var isDiscoverable = false
    @State private var contents: [ProfileContent] = []
    @State private var editing: ContentDraft?
    @State private var pendingDeletion: ProfileContent?
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    @State private var didLoad = false

    var body: some View {
        Form {
            Section {
                ProfileIdentityHeader(name: name.isEmpty ? profile.displayName : name, affiliation: affiliation)
                    .listRowInsets(EdgeInsets())
            }
            Section("基本情報") {
                TextField("表示名", text: $name)
                TextField("所属", text: $affiliation)
                TextField("自己紹介", text: $bio, axis: .vertical).lineLimit(3...8)
                Toggle("近くの人にプロフィールを公開", isOn: $isDiscoverable)
                Button("基本情報を保存") { Task { await saveProfile() } }
                    .buttonStyle(.glassProminent)
            }
            Section {
                ForEach(contents) { content in
                    Button { editing = ContentDraft(content: content) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(content.title, systemImage: content.isPublic ? "eye" : "eye.slash")
                                .foregroundStyle(.primary)
                            Text(content.value).lineLimit(2).font(.subheadline).foregroundStyle(.secondary)
                            Text(content.unlockAfterSeconds == 0 ? "公開時はすぐに表示" : "累計\(content.unlockAfterSeconds)秒で公開")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("削除", role: .destructive) { pendingDeletion = content }
                    }
                }
                Button("公開項目を追加", systemImage: "plus") { editing = ContentDraft() }
            } header: {
                Text("あなたを知るきっかけ")
            } footer: {
                Text("公開を許可した項目だけが対象です。時間条件は相手の端末に保存された、終了済みの出会いの累計時間で判定します。")
            }
            if let savedMessage { Text(savedMessage).foregroundStyle(.secondary) }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("項目を再読み込み") { Task { await loadContents() } }
                }
            }
            Section {
                Button("ログアウト", role: .destructive, action: onSignOut)
            }
        }
        .disabled(isBusy)
        .overlay { if isBusy { ProgressView().padding().background(.regularMaterial, in: Capsule()) } }
        .navigationTitle("あなたのプロフィール")
        .task {
            guard !didLoad else { return }
            name = profile.displayName
            affiliation = profile.affiliation ?? ""
            bio = profile.bio ?? ""
            isDiscoverable = profile.isDiscoverable
            didLoad = true
            await loadContents()
        }
        .sheet(item: $editing) { draft in
            ContentEditor(draft: draft, repository: repository) {
                Task { await loadContents() }
            }
        }
        .confirmationDialog("この項目を削除しますか？", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                guard let content = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await delete(content) }
            }
        }
    }

    private func loadContents() async {
        isBusy = true
        defer { isBusy = false }
        do {
            contents = try await repository.fetchContents(personID: profile.id)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private func saveProfile() async {
        isBusy = true
        savedMessage = nil
        defer { isBusy = false }
        do {
            let saved = try await repository.updateProfile(.init(displayName: name, affiliation: affiliation,
                bio: bio, avatarPath: profile.avatarPath, isDiscoverable: isDiscoverable))
            name = saved.displayName
            affiliation = saved.affiliation ?? ""
            bio = saved.bio ?? ""
            onSaved(saved)
            errorMessage = nil
            savedMessage = "プロフィールを保存しました。"
        } catch { errorMessage = error.localizedDescription }
    }

    private func delete(_ content: ProfileContent) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await repository.deleteContent(id: content.id)
            contents.removeAll { $0.id == content.id }
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct ContentDraft: Identifiable {
    let id = UUID()
    var originalID: UUID?
    var title = ""
    var value = ""
    var type = ProfileContentType.text
    var seconds = 0
    var order = 0
    var isPublic = false

    init() {}
    init(content: ProfileContent) {
        originalID = content.id
        title = content.title
        value = content.value
        type = content.type
        seconds = content.unlockAfterSeconds
        order = content.displayOrder
        isPublic = content.isPublic
    }
}

private struct ContentEditor: View {
    @State var draft: ContentDraft
    let repository: any ProfileRepository
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("項目") {
                    TextField("タイトル", text: $draft.title)
                    Picker("種類", selection: $draft.type) {
                        Text("テキスト").tag(ProfileContentType.text)
                        Text("画像URL").tag(ProfileContentType.image)
                        Text("音楽URL").tag(ProfileContentType.music)
                        Text("リンク").tag(ProfileContentType.url)
                        Text("動画URL").tag(ProfileContentType.video)
                    }
                    TextField(draft.type == .text ? "内容" : "https://…", text: $draft.value, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("公開設定") {
                    Toggle("公開する", isOn: $draft.isPublic)
                    TextField("公開までの累計秒数", value: $draft.seconds, format: .number)
                        .keyboardType(.numberPad)
                    TextField("表示順", value: $draft.order, format: .number).keyboardType(.numberPad)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .disabled(isSaving)
            .navigationTitle(draft.originalID == nil ? "新しい項目" : "項目を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }.disabled(isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            if let id = draft.originalID {
                _ = try await repository.updateContent(id: id, input: .init(type: draft.type, title: draft.title,
                    value: draft.value, unlockAfterSeconds: draft.seconds, displayOrder: draft.order, isPublic: draft.isPublic))
            } else {
                _ = try await repository.createContent(.init(type: draft.type, title: draft.title,
                    value: draft.value, unlockAfterSeconds: draft.seconds, displayOrder: draft.order, isPublic: draft.isPublic))
            }
            onSaved()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
