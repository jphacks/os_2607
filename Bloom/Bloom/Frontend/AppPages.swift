import SwiftUI

struct MessagesPage: View {
    @Binding var selectedConversation: String?
    @State private var searchText = ""

    private let conversations: [(name: String, message: String, time: String, tint: Color, unread: Bool)] = [
        ("なつみ", "また今度おすすめのお店教えてね！", "16:20", Color(red: 0.98, green: 0.88, blue: 0.83), true),
        ("みさき", "音楽の話、もっと聞きたい！", "昨日", Color(red: 0.94, green: 0.88, blue: 0.96), false),
        ("大輔", "はじめまして。ゲーム好きなんですね", "月曜日", Color(red: 0.84, green: 0.89, blue: 0.98), false)
    ]

    var body: some View {
        Group {
            if let name = selectedConversation {
                ChatThreadPage(name: name) { selectedConversation = nil }
            } else {
                conversationList
            }
        }
        .background(BloomPalette.canvas.ignoresSafeArea())
        .foregroundStyle(BloomPalette.ink)
    }

    private var conversationList: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("メッセージ")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .padding(.top, 16)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(BloomPalette.muted)
                TextField("メッセージを検索", text: $searchText)
                    .font(.system(size: 13))
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(conversations.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }, id: \.name) { item in
                        Button { selectedConversation = item.name } label: {
                            HStack(spacing: 12) {
                                messageAvatar(item.name, tint: item.tint)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.name).font(.system(size: 14, weight: .semibold))
                                    Text(item.message).font(.system(size: 11)).foregroundStyle(BloomPalette.muted).lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(item.time).font(.system(size: 9)).foregroundStyle(BloomPalette.muted)
                                    if item.unread { Circle().fill(BloomPalette.blue).frame(width: 7, height: 7) }
                                }
                            }
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func messageAvatar(_ name: String, tint: Color) -> some View {
        ZStack {
            Circle().fill(tint.gradient)
            Image(systemName: "person.fill").font(.system(size: 21, weight: .light)).foregroundStyle(BloomPalette.blue.opacity(0.7))
        }
        .frame(width: 48, height: 48)
    }
}

struct ChatThreadPage: View {
    let name: String
    let onBack: () -> Void
    @State private var draft = ""
    @State private var sentMessages: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BloomPalette.blue).frame(width: 40, height: 40)
                }
                Text(name).font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "person.crop.circle").font(.system(size: 21)).foregroundStyle(BloomPalette.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    Text("出会いからメッセージが始まりました")
                        .font(.system(size: 10)).foregroundStyle(BloomPalette.muted).padding(.vertical, 16)
                    messageBubble("こんにちは！さっきはありがとう。", isMine: false)
                    messageBubble("こちらこそ！話せてうれしかったです。", isMine: true)
                    messageBubble("また今度おすすめのお店教えてね！", isMine: false)
                    ForEach(Array(sentMessages.enumerated()), id: \.offset) { _, message in
                        messageBubble(message, isMine: true)
                    }
                    Color.clear.frame(height: 1).id("latest-message")
                }
                .padding(.horizontal, 16)
            }
            .onAppear { proxy.scrollTo("latest-message", anchor: .bottom) }
            .onChange(of: sentMessages.count) { _, _ in
                withAnimation { proxy.scrollTo("latest-message", anchor: .bottom) }
            }
            }

            HStack(spacing: 10) {
                TextField("メッセージを入力", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(11)
                    .background(BloomPalette.canvas, in: RoundedRectangle(cornerRadius: 17))
                Button {
                    let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !message.isEmpty else { return }
                    sentMessages.append(message)
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(BloomPalette.blue, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.white)
        }
    }

    private func messageBubble(_ text: String, isMine: Bool) -> some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(isMine ? .white : BloomPalette.ink)
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(isMine ? BloomPalette.blue : .white, in: RoundedRectangle(cornerRadius: 16))
            if !isMine { Spacer(minLength: 40) }
        }
    }
}

struct EncounterHistoryPage: View {
    let proximity: EncounterCoordinator
    let onSelect: (EncounterPerson) -> Void
    private var todayRecords: [Encounter] {
        proximity.records.filter { Calendar.current.isDateInToday($0.startedAt) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("出会いの履歴").font(.system(size: 27, weight: .bold, design: .rounded))
                Text("今日会った人：\(Set(todayRecords.map(\.personID)).count)人")
                Text("今日の合計：\(EncounterCoordinator.duration(todayRecords.reduce(0) { $0 + $1.duration }))")
                    .font(.caption).foregroundStyle(BloomPalette.muted)
                if proximity.records.isEmpty {
                    ContentUnavailableView("まだ履歴がありません", systemImage: "clock",
                        description: Text("一緒に過ごした時間をここに記録します。"))
                }
                ForEach(proximity.records) { record in
                    let person = proximity.person(record.personID)
                    Button { onSelect(person) } label: {
                        HStack {
                            Image(systemName: "person.crop.circle").font(.title)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(person.name).font(.headline)
                                Text("今回 \(EncounterCoordinator.duration(record.duration))・累計 \(person.totalTime)")
                                    .font(.caption)
                                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                }
            }.padding(20)
        }
        .background(BloomPalette.canvas.ignoresSafeArea())
    }
}

struct MyProfilePage: View {
    let session: AppSessionModel
    var body: some View {
        if let editor = session.editor {
            ProfileEditorView(editor: editor, session: session)
        }
    }
}

private struct ProfileEditorView: View {
    @Bindable var editor: ProfileEditorModel
    let session: AppSessionModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("プロフィール").font(.system(size: 27, weight: .bold, design: .rounded))
                if editor.isBusy { ProgressView("処理中") }
                if let error = editor.errorMessage { Text(error).foregroundStyle(.red).font(.callout) }
                if let message = editor.message { Text(message).foregroundStyle(BloomPalette.green) }
                if editor.errorMessage != nil {
                    Button("編集を破棄して再読み込み") { Task { await editor.load() } }
                }
                if editor.isLoaded {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("名前", text: $editor.displayName)
                        TextField("所属（任意）", text: $editor.affiliation)
                        TextField("自己紹介（任意）", text: $editor.bio, axis: .vertical)
                        Toggle("基本プロフィールを公開する", isOn: $editor.isDiscoverable)
                        Text("名前・所属・自己紹介・プロフィール画像をログイン済みユーザーに公開します。")
                            .font(.caption).foregroundStyle(BloomPalette.muted)
                    }
                    .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    HStack {
                        Text("追加の公開項目").font(.headline)
                        Spacer()
                        Button("追加") { editor.addField() }
                    }
                    Text("表示順は各項目の順序で指定します。公開までの時間は秒単位です。")
                        .font(.caption).foregroundStyle(BloomPalette.muted)
                    ForEach($editor.fields) { $field in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                TextField("項目名", text: $field.title)
                                Button(role: .destructive) { editor.removeField(id: field.id) } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            Picker("種類", selection: $field.type) {
                                ForEach(ProfileContentType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            TextField(field.type == .text ? "内容" : "https://…", text: $field.value, axis: .vertical)
                            Toggle("この項目の公開を許可", isOn: $field.isPublic)
                            HStack {
                                Text("公開まで（秒）")
                                TextField("秒", value: $field.unlockAfterSeconds, format: .number)
                                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            }
                            HStack {
                                Text("表示順")
                                TextField("順序", value: $field.displayOrder, format: .number)
                                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            }
                        }
                        .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                    Button("変更を保存") { Task { await session.saveProfile() } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("読み込みを再試行") { Task { await editor.load() } }
                }
                Button("ログアウト", role: .destructive) { Task { await session.signOut() } }
            }
            .padding(20)
            .disabled(editor.isBusy || session.isBusy)
        }
        .background(BloomPalette.canvas.ignoresSafeArea())
        .task { if !editor.isLoaded { await editor.load() } }
    }
}
