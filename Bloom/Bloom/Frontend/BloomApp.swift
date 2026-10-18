import SwiftUI

@main
struct BloomApp: App {
    @State private var session: AppSessionModel?
    @State private var configurationError: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let session {
                    SessionRootView(session: session)
                        .task { await session.observeSession() }
                } else if let configurationError {
                    ContentUnavailableView {
                        Label("起動できませんでした", systemImage: "exclamationmark.triangle")
                    } description: { Text(configurationError) } actions: {
                        Button("再試行", action: configure)
                    }
                } else { ProgressView("読み込み中").task { configure() } }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await session?.resume() } }
                else if phase == .background { session?.suspend() }
            }
        }
    }
    private func configure() {
        do {
            let dependencies = BackendDependencies.live(config: try SupabaseConfig.load())
            let store = try SwiftDataLocalStore()
            session = AppSessionModel(auth: dependencies.authRepository, profiles: dependencies.profileRepository,
                store: store, makeNearby: { UWBMultiPeerSession(personID: $0, requiresApproval: true) })
            configurationError = nil
        } catch { configurationError = error.localizedDescription }
    }
}

private struct SessionRootView: View {
    let session: AppSessionModel
    var body: some View {
        switch session.phase {
        case .loading: ProgressView("ログイン状態を確認中")
        case .signedOut, .needsProfile: AuthFlowView(session: session)
        case .ready:
            if let encounters = session.encounters { HomeView(session: session, proximity: encounters) }
        case .failed:
            ContentUnavailableView {
                Label("接続を確認してください", systemImage: "wifi.exclamationmark")
            } description: { Text(session.errorMessage ?? "情報を取得できませんでした") } actions: {
                Button("再試行") { Task { await session.restore() } }
                Button("ログアウト") { Task { await session.signOut() } }
            }
        }
    }
}

enum BloomPalette {
    static let ink = Color(red: 0.12, green: 0.18, blue: 0.25)
    static let muted = Color(red: 0.47, green: 0.52, blue: 0.59)
    static let blue = Color(red: 0.27, green: 0.42, blue: 0.66)
    static let green = Color(red: 0.20, green: 0.62, blue: 0.43)
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let line = Color(red: 0.90, green: 0.92, blue: 0.94)
}

struct EncounterPerson: Identifiable {
    let id: UUID
    let name: String
    let subtitle: String
    let distance: String
    let currentTime: String
    let totalTime: String
    let totalSeconds: Int
    let secondsToNextReveal: Int
    let nextReveal: String
    let revealedInterests: [String]
    let isEncountering: Bool
    let isConnection: Bool
    var imageSymbol: String { "person.fill" }
    var tint: Color { Color(red: 0.84, green: 0.89, blue: 0.98) }
    var progress: Double {
        guard secondsToNextReveal > 0 else { return 1 }
        return min(max(Double(totalSeconds) / Double(secondsToNextReveal), 0), 1)
    }
}

extension EncounterCoordinator {
    func person(_ id: UUID) -> EncounterPerson {
        let profile = publicProfiles[id]?.profile
        let connection = nearby.connections.first { $0.personID == id }
        let seconds = Int(totalSeconds(for: id))
        let visibleFields = fields(for: id)
        let next = visibleFields.filter { $0.value == nil }.min { $0.requiredSeconds < $1.requiredSeconds }
        return EncounterPerson(id: id, name: profile?.displayName ?? "公開情報なし",
            subtitle: profile?.affiliation ?? "",
            distance: connection?.observation?.distanceMeters.map { String(format: "%.1f m", $0) } ?? "—",
            currentTime: activePeople.contains(id) ? Self.duration(currentSeconds(for: id)) : "終了",
            totalTime: Self.duration(Double(seconds)), totalSeconds: seconds,
            secondsToNextReveal: next?.requiredSeconds ?? 0, nextReveal: next?.title ?? "公開待ちの項目なし",
            revealedInterests: visibleFields.filter { $0.value != nil }.map(\.title),
            isEncountering: activePeople.contains(id), isConnection: connection?.observation != nil)
    }
    static func duration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        return "\(value / 60)分\(value % 60)秒"
    }
}

struct HomeView: View {
    let session: AppSessionModel
    let proximity: EncounterCoordinator
    @State private var selectedTab = 0
    @State private var selectedPerson: EncounterPerson?
    @State private var selectedConversation: String?
    private var isParticipating: Bool { proximity.isParticipating }
    private var profileName: String { session.profile?.displayName ?? "" }
    private var nearbyPeople: [EncounterPerson] { proximity.personIDs.map(proximity.person) }

    var body: some View {
        VStack(spacing: 0) {
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            tabBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BloomPalette.canvas.ignoresSafeArea())
        .foregroundStyle(BloomPalette.ink)
        .preferredColorScheme(.light)
        .fullScreenCover(item: $selectedPerson) { person in
            EncounterProfileView(personID: person.id, proximity: proximity)
        }
        .task { proximity.resume() }
        .alert("UWB接続リクエスト", isPresented: Binding(
            get: { !proximity.nearby.pendingConnectionIDs.isEmpty },
            set: { _ in }
        )) {
            Button("許可") {
                if let id = proximity.nearby.pendingConnectionIDs.first { proximity.nearby.acceptConnection(id: id) }
            }
            Button("拒否", role: .cancel) {
                if let id = proximity.nearby.pendingConnectionIDs.first { proximity.nearby.rejectConnection(id: id) }
            }
        } message: {
            Text("近くの端末と人物IDを交換し、距離を計測します。接続を許可しますか？")
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedTab {
        case 1:
            MessagesPage(selectedConversation: $selectedConversation)
        case 2:
            EncounterHistoryPage(proximity: proximity) { person in
                selectedPerson = person
            }
        case 3:
            MyProfilePage(session: session)
        default:
            homePage
        }
    }

    private var homePage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                header
                greeting
                if isParticipating {
                    nearbySection
                } else {
                    pausedCard
                }
                connectBanner
                Text(proximity.status).font(.caption).foregroundStyle(BloomPalette.muted)
                if let error = proximity.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("保存を再試行") { proximity.retrySaves() }
                }
                if isParticipating {
                    Text("接続する端末を選択").font(.headline)
                    Text("端末名は一時的な名前です。相手と確認して選択してください。")
                        .font(.caption).foregroundStyle(BloomPalette.muted)
                    ForEach(proximity.nearby.discoveredPeers) { peer in
                        Button(peer.name) { proximity.connect(to: peer) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BloomPalette.blue)
            Text("Bloom")
                .font(.system(size: 21, weight: .bold, design: .rounded))
            Spacer()
            Button {} label: {
                Image(systemName: "bell")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(BloomPalette.ink)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("通知")
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Hello, \(profileName)さん")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.6)
            Text("一緒に過ごした時間が、プロフィールをひらきます。")
                .font(.system(size: 13))
                .foregroundStyle(BloomPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("出会い")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Text("近くにいる人・今日会った人")
                        .font(.system(size: 11))
                        .foregroundStyle(BloomPalette.muted)
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(BloomPalette.green).frame(width: 7, height: 7)
                    Text("接続中 \(proximity.nearby.connections.filter { $0.observation != nil }.count)人")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BloomPalette.green)
            }

            if nearbyPeople.isEmpty { Text("まだ出会いがありません").font(.caption) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(nearbyPeople) { person in
                    Button { selectedPerson = person } label: { personCard(person) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func personCard(_ person: EncounterPerson) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 17)
                    .fill(person.tint.gradient)
                    .overlay {
                        Image(systemName: person.imageSymbol)
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundStyle(BloomPalette.blue.opacity(0.64))
                            .offset(y: 9)
                    }
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                HStack(spacing: 4) {
                    Circle().fill(person.isEncountering ? BloomPalette.green : BloomPalette.muted.opacity(0.55))
                        .frame(width: 6, height: 6)
                    Text(person.isEncountering ? person.distance : "今日会った")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(BloomPalette.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(.white.opacity(0.92), in: Capsule())
                .padding(6)
            }
            HStack(spacing: 4) {
                Text(person.name).font(.system(size: 14, weight: .bold))
                if person.isConnection {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10)).foregroundStyle(BloomPalette.blue)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: person.isEncountering ? "timer" : "clock")
                    .font(.system(size: 9, weight: .medium))
                Text(person.totalTime).font(.system(size: 10, weight: .medium))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(BloomPalette.muted)
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: person.progress).tint(BloomPalette.blue)
                Text(person.revealedInterests.isEmpty ? "次に公開：\(person.nextReveal)" : "公開済み：\(person.revealedInterests.joined(separator: "・"))")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(BloomPalette.blue)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(BloomPalette.line.opacity(0.65), lineWidth: 1))
    }

    private var connectBanner: some View {
        Button {
            if isParticipating { proximity.stop() } else { proximity.start() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isParticipating ? "近くの人を探しています · タップで停止" : "みんなとつながる")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Text(isParticipating ? "近くの相手を検出しています" : "タップしてUWBで近くの人を探す")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(BloomPalette.blue.gradient, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var pausedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 27))
                .foregroundStyle(BloomPalette.muted.opacity(0.7))
            VStack(alignment: .leading, spacing: 4) {
                Text("参加を再開すると表示されます")
                    .font(.system(size: 13, weight: .semibold))
                Text("過去の出会いと記録はそのまま残ります")
                    .font(.system(size: 11))
                    .foregroundStyle(BloomPalette.muted)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func avatar(_ person: EncounterPerson, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(person.tint.gradient)
            Image(systemName: person.imageSymbol)
                .font(.system(size: size * 0.48, weight: .light))
                .foregroundStyle(BloomPalette.blue.opacity(0.7))
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tab(title: "ホーム", icon: "house.fill", index: 0)
            tab(title: "メッセージ", icon: "bubble.left.and.bubble.right", index: 1)
            tab(title: "履歴", icon: "clock", index: 2)
            tab(title: "プロフィール", icon: "person.crop.circle", index: 3)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Rectangle().fill(BloomPalette.ink.opacity(0.07)).frame(height: 0.5) }
        .frame(maxWidth: .infinity)
    }

    private func tab(title: String, icon: String, index: Int) -> some View {
        Button { selectedTab = index } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18, weight: selectedTab == index ? .semibold : .regular))
                Text(title).font(.system(size: 9, weight: selectedTab == index ? .semibold : .regular))
            }
            .foregroundStyle(selectedTab == index ? BloomPalette.blue : BloomPalette.muted)
            .frame(maxWidth: .infinity).frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

private struct EncounterProfileView: View {
    let personID: UUID
    let proximity: EncounterCoordinator
    private var person: EncounterPerson { proximity.person(personID) }
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDM = false

    var body: some View {
        Group {
            if isShowingDM {
                ChatThreadPage(name: person.name) { isShowingDM = false }
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            portrait
                            identity
                            actionButtons
                            encounterSummary
                            profileDetails
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .background(BloomPalette.canvas.ignoresSafeArea())
        .foregroundStyle(BloomPalette.ink)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BloomPalette.ink)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("プロフィール")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var portrait: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 30)
                .fill(person.tint.gradient)
                .overlay {
                    Image(systemName: person.imageSymbol)
                        .font(.system(size: 120, weight: .ultraLight))
                        .foregroundStyle(BloomPalette.blue.opacity(0.65))
                        .offset(y: 18)
                }
                .frame(height: 275)
                .clipShape(RoundedRectangle(cornerRadius: 30))
            HStack(spacing: 6) {
                Circle().fill(BloomPalette.green).frame(width: 7, height: 7)
                Text(person.isEncountering ? "一緒にいます" : "今日会いました")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(BloomPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.white.opacity(0.94), in: Capsule())
            .padding(14)
        }
        .padding(.top, 2)
    }

    private var identity: some View {
        VStack(spacing: 6) {
            Text(person.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(person.subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BloomPalette.muted)
        }
        .padding(.top, 1)
    }

    private var profileDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("プロフィール").font(.headline)
            if let message = proximity.profileMessages[personID] { Text(message).font(.caption) }
            Button("再読み込み") { proximity.refreshProfile(personID) }
            if let bio = proximity.publicProfiles[personID]?.profile.bio { Text(bio).font(.body) }
            ForEach(proximity.fields(for: personID)) { field in
                VStack(alignment: .leading, spacing: 8) {
                    Text(field.title).font(.headline)
                    if let value = field.value { Text(value) }
                    else { Label("累計\(field.requiredSeconds)秒で公開", systemImage: "lock.fill") }
                }
                .font(.subheadline)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 17))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var encounterSummary: some View {
        HStack(spacing: 0) {
            metric(title: "今回", value: person.currentTime)
            Rectangle().fill(BloomPalette.line).frame(width: 1, height: 34)
            metric(title: "累計", value: person.totalTime)
            Rectangle().fill(BloomPalette.line).frame(width: 1, height: 34)
            metric(title: "距離", value: person.isEncountering ? person.distance : "—")
        }
        .padding(.vertical, 15)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.system(size: 10)).foregroundStyle(BloomPalette.muted)
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionButtons: some View {
        HStack {
            Button("DM（デモ）") { isShowingDM = true }
            Spacer()
            if person.isConnection {
                Button("接続を終了") { proximity.nearby.disconnect(from: personID) }
            } else { Text("接続はホームの端末一覧から行えます").font(.caption) }
        }
        .task { proximity.refreshProfile(personID) }
    }
}
