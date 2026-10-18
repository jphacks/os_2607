import SwiftUI

struct EncounterHistoryPersonCard: View {
    let summary: EncounterHistorySummary
    @State private var model: HistoryProfileModel

    init(summary: EncounterHistorySummary, repository: any ProfileRepository) {
        self.summary = summary
        _model = State(initialValue: HistoryProfileModel(personID: summary.personID, repository: repository, includesContents: false))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "leaf")
                .foregroundStyle(.pink)
                .padding(12).background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(model.profile?.displayName ?? (model.errorMessage == nil ? "プロフィールを確認中" : "プロフィールを表示できません"))
                    .font(.headline)
                if let affiliation = model.profile?.affiliation, !affiliation.isEmpty {
                    Text(affiliation).font(.subheadline).foregroundStyle(.secondary)
                }
                if let latest = summary.latestDate {
                    Text(latest, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summary.records.count)回の出会い")
                    Text(Duration.seconds(summary.duration), format: .time(pattern: .minuteSecond))
                        .monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary)
                if let title = summary.records.first?.title {
                    Text(title).font(.subheadline).lineLimit(2)
                }
            }
            Label("セッションを見る", systemImage: "arrow.up.right")
                .font(.caption.weight(.semibold)).foregroundStyle(.pink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.pink.opacity(0.1)))
        .modifier(HistoryProfileRefresh(model: model))
    }
}

struct HistoricalPersonDetail: View {
    let personID: UUID
    let proximity: UWBConnectionService
    @State private var model: HistoryProfileModel
    @State private var editing: RecordedEncounter?

    private var summary: EncounterHistorySummary {
        EncounterHistorySummary.group(proximity.records).first { $0.personID == personID }
            ?? EncounterHistorySummary(personID: personID, records: [])
    }

    init(summary: EncounterHistorySummary, proximity: UWBConnectionService, repository: any ProfileRepository) {
        self.personID = summary.personID
        self.proximity = proximity
        _model = State(initialValue: HistoryProfileModel(personID: summary.personID, repository: repository, includesContents: true))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let profile = model.profile {
                    ProfileIdentityHeader(name: profile.displayName, affiliation: profile.affiliation ?? "")
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .modifier(ProfileCardScrollEffect())
                    if let bio = profile.bio, !bio.isEmpty {
                        ProfileCard { Text("自己紹介").font(.title3.bold()); Text(bio).font(.body) }
                    }
                    ForEach(model.revealedContents(accumulatedSeconds: summary.duration)) { content in
                        PublicContentBlock(content: content)
                    }
                } else if model.errorMessage == nil {
                    ProgressView("公開プロフィールを確認しています")
                        .frame(maxWidth: .infinity).padding()
                } else {
                    ContentUnavailableView("プロフィールを表示できません", systemImage: "person.crop.circle.badge.xmark",
                                           description: Text("公開が取り消されたか、通信できない可能性があります。出会いの記録は残っています。"))
                    Button("再試行") { Task { await model.refresh() } }
                        .buttonStyle(.glass)
                }
                ProfileCard {
                    Text("一緒に過ごした時間").font(.title2.bold())
                    Text(Duration.seconds(summary.duration), format: .time(pattern: .minuteSecond))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(.pink)

                }
                Text("セッションの記録").font(.title2.bold())
                ForEach(summary.records) { record in
                    ProfileCard {
                        Text(record.title ?? "タイトル未設定").font(.title3.bold())
                        Text(record.startedAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("終了: \(record.endedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                        Label {
                            Text(Duration.seconds(record.duration), format: .time(pattern: .minuteSecond))
                                .monospacedDigit()
                        } icon: { Image(systemName: "clock") }
                        Button(record.title == nil ? "タイトルをつける" : "タイトルを編集", systemImage: "pencil") {
                            editing = record
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("出会った人")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
        .modifier(HistoryProfileRefresh(model: model))
        .sheet(item: $editing) { record in
            EncounterTitleEditor(record: record, proximity: proximity)
        }
    }
}

private struct EncounterTitleEditor: View {
    let record: RecordedEncounter
    let proximity: UWBConnectionService
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var errorMessage: String?

    init(record: RecordedEncounter, proximity: UWBConnectionService) {
        self.record = record
        self.proximity = proximity
        _title = State(initialValue: record.title ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例: ランチでの出会い", text: $title, axis: .vertical)
                    Text(record.startedAt, format: .dateTime.year().month().day().hour().minute())
                        .foregroundStyle(.secondary)
                } header: { Text("セッションのタイトル") }
                footer: { Text("この端末の履歴に保存します。空欄で保存するとタイトルを解除します。") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("タイトルを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do {
                            try proximity.renameEncounter(id: record.id, title: title)
                            dismiss()
                        } catch {
                            errorMessage = "タイトルを保存できませんでした。" + error.localizedDescription
                        }
                    }
                }
            }
        }
    }
}

private struct HistoryProfileRefresh: ViewModifier {
    let model: HistoryProfileModel
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onDisappear { model.invalidate() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.invalidate() }
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    await model.refresh()
                    do { try await Task.sleep(for: .seconds(12)) } catch { return }
                }
            }
    }
}
