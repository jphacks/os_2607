import SwiftUI

struct EncounterHistoryPersonRow: View {
    let summary: EncounterHistorySummary
    @State private var model: HistoryProfileModel

    init(summary: EncounterHistorySummary, repository: any ProfileRepository) {
        self.summary = summary
        _model = State(initialValue: HistoryProfileModel(personID: summary.personID, repository: repository, includesContents: false))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
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
                HStack {
                    Text("\(summary.records.count)回の出会い")
                    Text(Duration.seconds(summary.duration), format: .time(pattern: .minuteSecond))
                        .monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .modifier(HistoryProfileRefresh(model: model))
    }
}

struct HistoricalPersonDetail: View {
    let summary: EncounterHistorySummary
    @State private var model: HistoryProfileModel

    init(summary: EncounterHistorySummary, repository: any ProfileRepository) {
        self.summary = summary
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

            }
            .padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("出会った人")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refresh() }
        .modifier(HistoryProfileRefresh(model: model))
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
