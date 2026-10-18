import SwiftUI

struct NearbyPeoplePage: View {
    let proximity: UWBConnectionService
    let ownProfile: Profile
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                NearbyHero(name: ownProfile.displayName, isParticipating: proximity.isParticipating)
                if !ownProfile.isDiscoverable {
                    Label("プロフィールで公開をオンにすると参加できます。", systemImage: "eye.slash")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Button {
                        if proximity.isParticipating { proximity.stop() } else { proximity.start() }
                    } label: {
                        Label(proximity.isParticipating ? "参加を終了" : "この場所に参加する",
                              systemImage: proximity.isParticipating ? "pause.fill" : "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
                if let error = proximity.connectionError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if proximity.people.isEmpty {
                    NearbyEmptyState(isParticipating: proximity.isParticipating)
                } else {
                    HStack {
                        Text("同じ空間にいる人").font(.title2.bold())
                        Spacer()
                        Text("\(proximity.people.count)人").font(.subheadline).foregroundStyle(.secondary)
                    }
                    LazyVStack(spacing: 22) {
                        ForEach(proximity.people) { person in
                            NavigationLink {
                                NearbyPersonDetail(personID: person.id, proximity: proximity)
                            } label: {
                                NearbyProfileCard(person: person)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                DisclosureGroup("見つからないときは") {
                    Text("お互いにBloomを開いて参加し、近づいてください。ライブアクティビティが有効な間は、ほかのアプリを開いても測距を継続できます。設定で「ローカルネットワーク」と「近くの操作」を許可してください。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Text("参加中の人のうち、公開が許可されたプロフィールだけを表示します。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(colors: [
                colorScheme == .dark ? Color.pink.opacity(0.18) : Color(red: 0.94, green: 0.94, blue: 1),
                Color(uiColor: .systemBackground),
                Color.teal.opacity(0.07)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        }
        .navigationTitle("Bloom")

    }
}

private struct NearbyHero: View {
    let name: String
    let isParticipating: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(isParticipating ? Color.green : Color.secondary).frame(width: 7, height: 7)
            }
            Text("偶然のそばに、\n新しいきっかけ。")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(name)さん、こんにちは。")
                .font(.title3).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .background(alignment: .trailing) {
            BloomPetals().frame(width: 150, height: 150).opacity(0.12)
                .accessibilityHidden(true)
        }
    }
}

private struct BloomPetals: View {
    var body: some View {
        ZStack {
            Ellipse().fill(.pink.gradient).rotationEffect(.degrees(-35))
            Ellipse().fill(.teal.gradient).rotationEffect(.degrees(35))
        }
        .aspectRatio(0.45, contentMode: .fit)
    }
}

private struct NearbyEmptyState: View {
    let isParticipating: Bool
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(.pink.opacity(0.1), lineWidth: 1).frame(width: 180, height: 180)
                Circle().stroke(.pink.opacity(0.16), lineWidth: 1).frame(width: 132, height: 132)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.pink.gradient)
                    .frame(width: 88, height: 88)
                    .background(.pink.opacity(0.09), in: Circle())
            }
            .accessibilityHidden(true)
            Text(isParticipating ? "出会いの準備ができました" : "ここから、会話が芽吹く")
                .font(.title3.bold())
            Text(isParticipating
                 ? "相手もBloomで参加すると、自動でつながり、公開プロフィールがここに届きます。端末を選ぶ操作は必要ありません。"
                 : "参加すると、同じ場所にいる人の名前や好きなことに出会えます。")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.vertical, 32).padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
}

struct ProfileIdentityHeader: View {
    let name: String
    let affiliation: String
    var body: some View {
        HStack(spacing: 20) {
            ProfileMonogram(name: name, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                Text(name).font(.system(.title2, design: .rounded, weight: .bold))
                if !affiliation.isEmpty { Text(affiliation).font(.subheadline).foregroundStyle(.secondary) }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.pink.opacity(0.06))
    }
}

private struct ProfileMonogram: View {
    let name: String
    let size: CGFloat
    var body: some View {
        Text(String(name.prefix(1)))
            .font(.system(.largeTitle, design: .rounded, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [.pink, .purple.opacity(0.7), .teal.opacity(0.65)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: size * 0.32))
            .accessibilityHidden(true)
    }
}

private struct NearbyProfileCard: View {
    let person: NearbyPerson
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                ProfileMonogram(name: person.profile.displayName, size: 88)
                Spacer()
                Label("同じ空間", systemImage: "sparkle")
                    .font(.caption.weight(.medium)).foregroundStyle(.pink)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.pink.opacity(0.08), in: Capsule())
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(person.profile.displayName)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(.primary)
                if let affiliation = person.profile.affiliation, !affiliation.isEmpty {
                    Text(affiliation).font(.subheadline).foregroundStyle(.secondary)
                }
                if let bio = person.profile.bio, !bio.isEmpty {
                    Text(bio).font(.body).foregroundStyle(.primary.opacity(0.8)).lineLimit(3)
                }
            }
            if let topic = person.contents.first(where: { $0.type == .text }) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(topic.title, systemImage: "quote.opening")
                        .font(.caption.weight(.semibold)).foregroundStyle(.pink)
                    Text(topic.value).font(.body).foregroundStyle(.primary).lineLimit(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.pink.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
            }
            HStack {
                Text(person.contents.isEmpty ? "プロフィールを見る" : "\(person.contents.count)個の話題を見つける")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .foregroundStyle(.pink)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(.pink.opacity(0.1), lineWidth: 1))
        .shadow(color: .pink.opacity(0.07), radius: 20, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 30))
    }
}

private struct NearbyPersonDetail: View {
    let personID: UUID
    let proximity: UWBConnectionService
    private var person: NearbyPerson? { proximity.people.first { $0.id == personID } }
    var body: some View {
        ScrollView {
            if let person {
                VStack(alignment: .leading, spacing: 24) {
                    NearbyProfileCard(person: person)
                        .modifier(ProfileCardScrollEffect())
                    ForEach(person.contents) { content in
                        PublicContentBlock(content: content)
                    }
                    Text("このプロフィールは近くの端末から共有されたIDをもとに表示しています。端末の所有者本人であることの確認には対応していません。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView("現在は表示できません", systemImage: "person.crop.circle.badge.xmark",
                                       description: Text("相手との接続やプロフィールの公開状態をご確認ください。"))
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)

    }
}

struct PublicContentBlock: View {
    let content: ProfileContent
    var body: some View {
        ProfileCard {
            Text(content.title).font(.title3.bold())
            RichContentView(kind: content.type == .text ? .text : content.type == .image ? .image : content.type == .video ? .video : .url,
                            value: content.value, title: content.title)
                .id(content.value)
        }

    }
}
