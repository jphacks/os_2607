import SwiftUI

@main
struct BloomApp: App {
    var body: some Scene {
        WindowGroup { HomeView() }
    }
}

private enum BloomPalette {
    static let ink = Color(red: 0.12, green: 0.18, blue: 0.25)
    static let muted = Color(red: 0.47, green: 0.52, blue: 0.59)
    static let blue = Color(red: 0.27, green: 0.42, blue: 0.66)
    static let green = Color(red: 0.20, green: 0.62, blue: 0.43)
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let line = Color(red: 0.90, green: 0.92, blue: 0.94)
}

private struct EncounterPerson: Identifiable {
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
    @State private var isParticipating = true
    @State private var selectedTab = 0
    @State private var selectedPerson: EncounterPerson?

    private let nearbyPeople = [
        EncounterPerson(id: 1, name: "大輔", subtitle: "初めて会いました", imageSymbol: "person.fill", tint: Color(red: 0.84, green: 0.89, blue: 0.98), distance: "2.4 m", currentTime: "01:24", totalTime: "1分24秒", totalSeconds: 84, secondsToNextReveal: 180, nextReveal: "好きなこと", revealedInterests: [], isEncountering: true, isConnection: false),
        EncounterPerson(id: 2, name: "なつみ", subtitle: "また会いました", imageSymbol: "person.fill", tint: Color(red: 0.98, green: 0.88, blue: 0.83), distance: "3.1 m", currentTime: "08:12", totalTime: "8分12秒", totalSeconds: 492, secondsToNextReveal: 900, nextReveal: "最近ハマっていること", revealedInterests: ["カフェ"], isEncountering: true, isConnection: true),
        EncounterPerson(id: 3, name: "悠斗", subtitle: "今日会いました", imageSymbol: "person.fill", tint: Color(red: 0.87, green: 0.92, blue: 0.83), distance: "—", currentTime: "終了", totalTime: "4分06秒", totalSeconds: 246, secondsToNextReveal: 600, nextReveal: "好きなこと", revealedInterests: [], isEncountering: false, isConnection: true),
        EncounterPerson(id: 4, name: "みさき", subtitle: "以前会いました", imageSymbol: "person.fill", tint: Color(red: 0.94, green: 0.88, blue: 0.96), distance: "—", currentTime: "終了", totalTime: "18分", totalSeconds: 1080, secondsToNextReveal: 900, nextReveal: "最近ハマっていること", revealedInterests: ["音楽"], isEncountering: false, isConnection: true)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
                    header
                    greeting
                    participationCard
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
            tabBar
        }
        .background(BloomPalette.canvas.ignoresSafeArea())
        .foregroundStyle(BloomPalette.ink)
        .preferredColorScheme(.light)
        .fullScreenCover(item: $selectedPerson) { person in
            EncounterProfileView(person: person)
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BloomPalette.blue)
            Text("Hello")
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
            Text("Hello, あおいさん")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.6)
            Text("一緒に過ごした時間が、プロフィールをひらきます。")
                .font(.system(size: 13))
                .foregroundStyle(BloomPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var participationCard: some View {
        HStack(spacing: 14) {
            Image(systemName: isParticipating ? "dot.radiowaves.left.and.right" : "pause.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isParticipating ? BloomPalette.green : BloomPalette.muted)
            VStack(alignment: .leading, spacing: 4) {
                Text(isParticipating ? "出会いに参加中" : "出会いを一時停止中")
                    .font(.system(size: 13, weight: .bold))
                Text(isParticipating ? "近くの人との時間を記録します" : "近くの人を検出・記録しません")
                    .font(.system(size: 10))
                    .foregroundStyle(BloomPalette.muted)
            }
            Spacer(minLength: 6)
            Toggle("出会いに参加", isOn: $isParticipating)
                .labelsHidden()
                .tint(BloomPalette.green)
                .scaleEffect(0.85, anchor: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 17))
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
            if !isParticipating { isParticipating = true }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 3) {
                    Text(isParticipating ? "みんなとつながる" : "出会いへの参加を再開")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Text("近くの人のプロフィールを見てみましょう")
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
            tab(title: "出会い", icon: "clock", index: 2)
            tab(title: "プロフィール", icon: "person.crop.circle", index: 3)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Rectangle().fill(BloomPalette.ink.opacity(0.07)).frame(height: 0.5) }
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    portrait
                    identity
                    encounterSummary
                    revealedSection
                    lockedSection
                    actionButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 34)
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
            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BloomPalette.ink)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
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
            HStack(spacing: 11) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(BloomPalette.muted)
                    .frame(width: 36, height: 36)
                    .background(BloomPalette.canvas, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.nextReveal).font(.system(size: 12, weight: .semibold))
                    Text("もう少し一緒に過ごすと公開されます")
                        .font(.system(size: 10))
                        .foregroundStyle(BloomPalette.muted)
                }
                Spacer(minLength: 0)
            }
            ProgressView(value: person.progress)
                .tint(BloomPalette.blue)
            Text("公開される内容と必要な累計時間は、本人が設定できます。")
                .font(.system(size: 10))
                .foregroundStyle(BloomPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var actionButton: some View {
        Button {} label: {
            Label(person.isConnection ? "メッセージを送る" : "つながりをリクエスト", systemImage: person.isConnection ? "bubble.left.and.bubble.right.fill" : "person.badge.plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(BloomPalette.blue, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
