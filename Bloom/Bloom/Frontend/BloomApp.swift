import SwiftUI

@main
struct BloomApp: App {
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    var body: some Scene {
        WindowGroup {
            if didCompleteOnboarding {
                HomeView()
            } else {
                AuthFlowView()
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
    let id: Int
    let name: String
    let subtitle: String
    let imageSymbol: String
    let tint: Color
    let distance: String
    let currentTime: String
    let totalTime: String
    let totalSeconds: Int
    let secondsToNextReveal: Int
    let nextReveal: String
    let revealedInterests: [String]
    let isEncountering: Bool
    let isConnection: Bool

    var progress: Double {
        guard secondsToNextReveal > 0 else { return 1 }
        return min(max(Double(totalSeconds) / Double(secondsToNextReveal), 0.08), 1)
    }
}

struct HomeView: View {
    @State private var isParticipating = false
    @State private var selectedTab = 0
    @State private var selectedPerson: EncounterPerson?
    @State private var selectedConversation: String?
    @StateObject private var proximity = UWBConnectionService()
    @AppStorage("profileName") private var profileName = "あおい"

    private let nearbyPeople = [
        EncounterPerson(id: 1, name: "大輔", subtitle: "初めて会いました", imageSymbol: "person.fill", tint: Color(red: 0.84, green: 0.89, blue: 0.98), distance: "2.4 m", currentTime: "01:24", totalTime: "1分24秒", totalSeconds: 84, secondsToNextReveal: 180, nextReveal: "好きなこと", revealedInterests: [], isEncountering: true, isConnection: false),
        EncounterPerson(id: 2, name: "なつみ", subtitle: "また会いました", imageSymbol: "person.fill", tint: Color(red: 0.98, green: 0.88, blue: 0.83), distance: "3.1 m", currentTime: "08:12", totalTime: "8分12秒", totalSeconds: 492, secondsToNextReveal: 900, nextReveal: "最近ハマっていること", revealedInterests: ["カフェ"], isEncountering: true, isConnection: true),
        EncounterPerson(id: 3, name: "悠斗", subtitle: "今日会いました", imageSymbol: "person.fill", tint: Color(red: 0.87, green: 0.92, blue: 0.83), distance: "—", currentTime: "終了", totalTime: "4分06秒", totalSeconds: 246, secondsToNextReveal: 600, nextReveal: "好きなこと", revealedInterests: [], isEncountering: false, isConnection: true),
        EncounterPerson(id: 4, name: "みさき", subtitle: "以前会いました", imageSymbol: "person.fill", tint: Color(red: 0.94, green: 0.88, blue: 0.96), distance: "—", currentTime: "終了", totalTime: "18分", totalSeconds: 1080, secondsToNextReveal: 900, nextReveal: "最近ハマっていること", revealedInterests: ["音楽"], isEncountering: false, isConnection: true)
    ]

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
            EncounterProfileView(person: person, proximity: proximity)
        }
        .onAppear {
            if isParticipating { proximity.startAdvertising(profileName: profileName) }
        }
        .onChange(of: isParticipating) { _, isOn in
            if isOn {
                proximity.startAdvertising(profileName: profileName)
            } else {
                proximity.stop()
            }
        }
        .onChange(of: profileName) { _, name in
            if isParticipating { proximity.startAdvertising(profileName: name) }
        }
        .alert("UWB接続リクエスト", isPresented: Binding(
            get: { proximity.pendingRequestFrom != nil },
            set: { _ in }
        )) {
            Button("許可") { proximity.acceptPendingRequest() }
            Button("拒否", role: .cancel) { proximity.rejectPendingRequest() }
        } message: {
            Text("\(proximity.pendingRequestFrom ?? "近くの人")さんから接続リクエストが届きました。許可するとUWBで距離を測定します。")
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedTab {
        case 1:
            MessagesPage(selectedConversation: $selectedConversation)
        case 2:
            EncounterHistoryPage(records: proximity.records, people: nearbyPeople.filter { !$0.isEncountering }) { person in
                selectedPerson = person
            }
        case 3:
            MyProfilePage(profileName: $profileName)
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
                    Text("近くに2人")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BloomPalette.green)
            }

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
            isParticipating.toggle()
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
    let person: EncounterPerson
    @ObservedObject var proximity: UWBConnectionService
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
        let details: [(title: String, text: String, minutes: Int)] = [
            ("自己紹介", person.id == 2 ? "新しいカフェを探すのが好きです。休日は気になるお店を巡っています。" : "好きなことを通じて、いろんな人と話したいです。", 0),
            ("好きなこと", person.id == 2 ? "カフェ巡り、写真、散歩" : "音楽、映画、旅行", 3),
            ("最近ハマっていること", "街の小さな喫茶店を見つけること", 10),
            ("好きな音楽", "インディーポップ、映画のサウンドトラック", 20),
            ("リンク・SNS", "https://example.com/profile", 35),
            ("写真・動画", "お気に入りの場所や日常の写真", 50)
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("プロフィール").font(.system(size: 16, weight: .bold))
            ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                let isUnlocked = person.totalSeconds >= detail.minutes * 60
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(detail.title).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        if detail.minutes > 0 {
                            Label(isUnlocked ? "公開中" : "累計\(detail.minutes)分で公開", systemImage: isUnlocked ? "lock.open.fill" : "lock.fill")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isUnlocked ? BloomPalette.green : BloomPalette.muted)
                        }
                    }
                    if isUnlocked {
                        Text(detail.text)
                            .font(.system(size: 12))
                            .foregroundStyle(BloomPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("一緒に過ごす時間が増えると公開されます")
                            .font(.system(size: 11))
                            .foregroundStyle(BloomPalette.muted)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 17))
                .scrollTransition(.interactive, axis: .vertical) { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1.04 : 0.94)
                        .opacity(phase.isIdentity ? 1 : 0.78)
                }
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

    private var revealedSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("公開されたこと")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("出会いの時間で公開")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(BloomPalette.muted)
            }
            HStack(spacing: 9) {
                revealChip(icon: "person.fill", title: person.name)
                revealChip(icon: "photo", title: "プロフィール写真")
                ForEach(person.revealedInterests, id: \.self) { item in
                    revealChip(icon: "sparkles", title: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func revealChip(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(BloomPalette.blue)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(BloomPalette.blue.opacity(0.08), in: Capsule())
    }

    private var lockedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("これから公開")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BloomPalette.muted)
                Text("公開設定")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(BloomPalette.muted)
            }
            ForEach([person.nextReveal, "自己紹介", "リンク", "好きな音楽", "写真・動画"], id: \.self) { item in
                HStack(spacing: 11) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(BloomPalette.muted)
                        .frame(width: 34, height: 34)
                        .background(BloomPalette.canvas, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item).font(.system(size: 11, weight: .semibold))
                        Text(item == person.nextReveal ? "次に公開 · 累計時間で解除" : "本人が公開条件を設定")
                            .font(.system(size: 9)).foregroundStyle(BloomPalette.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(BloomPalette.muted.opacity(0.7))
                }
                .padding(.vertical, 2)
            }
            ProgressView(value: person.progress).tint(BloomPalette.blue)
            Text("公開される内容と必要な累計時間は、本人が設定できます。")
                .font(.system(size: 10)).foregroundStyle(BloomPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var sharedProfileInformation: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("プロフィール情報").font(.system(size: 16, weight: .bold))
            if person.isConnection {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "text.alignleft").foregroundStyle(BloomPalette.blue).frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ひとこと").font(.system(size: 10)).foregroundStyle(BloomPalette.muted)
                            Text(person.id == 2 ? "新しいカフェを探すのが好きです。" : "好きなことを通じて、いろんな人と話したいです。")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    if !person.revealedInterests.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "music.note").foregroundStyle(BloomPalette.blue).frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(person.revealedInterests.contains("音楽") ? "好きな音楽" : "好きなこと")
                                    .font(.system(size: 10)).foregroundStyle(BloomPalette.muted)
                                Text(person.revealedInterests.joined(separator: " · "))
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
            } else {
                HStack(spacing: 9) {
                    Image(systemName: "lock.fill").foregroundStyle(BloomPalette.muted)
                    Text("公開された項目はここに表示されます")
                        .font(.system(size: 11)).foregroundStyle(BloomPalette.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
            }

            HStack(spacing: 10) {
                mediaTile(icon: "link", title: "URL", isUnlocked: person.isConnection)
                mediaTile(icon: "music.note", title: "MUSIC", isUnlocked: person.revealedInterests.contains("音楽"))
                mediaTile(icon: "photo.on.rectangle", title: "写真・動画", isUnlocked: person.revealedInterests.count > 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mediaTile(icon: String, title: String, isUnlocked: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: isUnlocked ? icon : "lock.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isUnlocked ? BloomPalette.blue : BloomPalette.muted.opacity(0.6))
            Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(BloomPalette.muted)
        }
        .frame(maxWidth: .infinity).frame(height: 72)
        .background(.white, in: RoundedRectangle(cornerRadius: 15))
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            if !proximity.status.isEmpty {
                Text(proximity.status)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(proximity.distance != nil && proximity.distance! <= 4 ? BloomPalette.green : BloomPalette.muted)
                    .lineLimit(1)
            }
            HStack(spacing: 10) {
                Button {
                    isShowingDM = true
                } label: {
                    Label("DM", systemImage: "bubble.left.and.bubble.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BloomPalette.blue)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(BloomPalette.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                Button { proximity.connect(to: person.name) } label: {
                    Label(proximity.distance == nil ? "つながる" : "UWB接続中", systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(BloomPalette.blue, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
