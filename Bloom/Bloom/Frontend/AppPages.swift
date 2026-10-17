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
    let records: [EncounterRecord]
    let people: [EncounterPerson]
    let onSelect: (EncounterPerson) -> Void

    private var todayRecords: [EncounterRecord] {
        records.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    private var earlierRecords: [EncounterRecord] {
        records.filter { !Calendar.current.isDateInToday($0.startedAt) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("出会いの履歴")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .padding(.top, 16)
                Text("一緒に過ごした時間は、また会ったときに積み重なります。")
                    .font(.system(size: 12)).foregroundStyle(BloomPalette.muted)
                HStack(spacing: 12) {
                    historySummary(value: records.isEmpty ? "3人" : "\(todayRecords.count)人", title: "今日会った人", symbol: "person.2.fill")
                    historySummary(value: records.isEmpty ? "26分" : totalTodayDuration, title: "今日の合計", symbol: "clock.fill")
                }
                if records.isEmpty {
                    Text("今日").font(.system(size: 16, weight: .bold)).padding(.top, 4)
                    VStack(spacing: 9) {
                        ForEach(people.filter { $0.id == 3 }) { person in historyRow(person, date: "15:12") }
                    }
                    Text("最近").font(.system(size: 16, weight: .bold)).padding(.top, 4)
                    ForEach(people.filter { $0.id != 3 }) { person in historyRow(person, date: "10月15日") }
                } else {
                    if !todayRecords.isEmpty {
                        Text("今日").font(.system(size: 16, weight: .bold)).padding(.top, 4)
                        VStack(spacing: 9) {
                            ForEach(Array(todayRecords.enumerated()), id: \.element.id) { index, record in
                                recordRow(record, index: index)
                            }
                        }
                    }
                    if !earlierRecords.isEmpty {
                        Text("最近").font(.system(size: 16, weight: .bold)).padding(.top, 4)
                        VStack(spacing: 9) {
                            ForEach(Array(earlierRecords.enumerated()), id: \.element.id) { index, record in
                                recordRow(record, index: index + 100)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(BloomPalette.canvas.ignoresSafeArea())
        .foregroundStyle(BloomPalette.ink)
    }

    private var totalTodayDuration: String {
        let minutes = todayRecords.reduce(0) { $0 + $1.durationSeconds } / 60
        return "\(minutes)分"
    }

    private func recordRow(_ record: EncounterRecord, index: Int) -> some View {
        let person = EncounterPerson(
            id: -index - 1,
            name: record.personName,
            subtitle: "出会いを記録しました",
            imageSymbol: "person.fill",
            tint: Color(red: 0.87, green: 0.91, blue: 0.97),
            distance: "—",
            currentTime: "終了",
            totalTime: record.durationLabel,
            totalSeconds: record.durationSeconds,
            secondsToNextReveal: 600,
            nextReveal: "好きなこと",
            revealedInterests: [],
            isEncountering: false,
            isConnection: true
        )
        return historyRow(person, date: record.startedAt.formatted(date: .omitted, time: .shortened))
    }

    private func historySummary(value: String, title: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(BloomPalette.blue)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
            Text(title).font(.system(size: 10)).foregroundStyle(BloomPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func historyRow(_ person: EncounterPerson, date: String) -> some View {
        Button { onSelect(person) } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(person.tint.gradient)
                    Image(systemName: person.imageSymbol).font(.system(size: 21, weight: .light)).foregroundStyle(BloomPalette.blue.opacity(0.7))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name).font(.system(size: 13, weight: .semibold))
                    Text("一緒にいた時間  ·  \(person.totalTime)").font(.system(size: 10)).foregroundStyle(BloomPalette.muted)
                }
                Spacer()
                Text(date).font(.system(size: 9)).foregroundStyle(BloomPalette.muted)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(BloomPalette.muted)
            }
            .padding(11)
            .background(.white, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
    }
}

private struct EditableProfileField: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var content: String
    var revealMinutes: Int
    var isPublic: Bool
}

struct MyProfilePage: View {
    @Binding var profileName: String
    @AppStorage("editableProfileFields") private var storedFields = ""
    @State private var fields: [EditableProfileField] = [
        EditableProfileField(title: "自己紹介", content: "好きなことを通じて、いろんな人と話したいです。", revealMinutes: 0, isPublic: true),
        EditableProfileField(title: "好きなこと", content: "音楽、カフェ、散歩", revealMinutes: 3, isPublic: true),
        EditableProfileField(title: "最近ハマっていること", content: "新しいお店を探すこと", revealMinutes: 10, isPublic: true)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("プロフィール")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .padding(.top, 16)
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color(red: 0.84, green: 0.89, blue: 0.98).gradient)
                        Image(systemName: "person.fill").font(.system(size: 34, weight: .light)).foregroundStyle(BloomPalette.blue.opacity(0.7))
                    }
                    .frame(width: 70, height: 70)
                    VStack(alignment: .leading, spacing: 5) {
                        TextField("名前", text: $profileName).font(.system(size: 18, weight: .bold))
                        Text("プロフィールを編集").font(.system(size: 11)).foregroundStyle(BloomPalette.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(BloomPalette.muted)
                }
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))

                HStack {
                    Text("公開する情報").font(.system(size: 16, weight: .bold))
                    Spacer()
                    Button { addField() } label: {
                        Label("項目を追加", systemImage: "plus.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .padding(.top, 3)
                Text("項目名も内容も自由に入力できます。公開までの累計時間が長い項目ほど、プロフィールの下に表示されます。")
                    .font(.system(size: 10)).foregroundStyle(BloomPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach($fields) { $field in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField("項目名", text: $field.title)
                                .font(.system(size: 13, weight: .semibold))
                            Toggle("公開", isOn: $field.isPublic).labelsHidden().tint(BloomPalette.green).scaleEffect(0.8, anchor: .trailing)
                            Button(role: .destructive) { removeField(id: field.id) } label: {
                                Image(systemName: "trash").font(.system(size: 12))
                            }
                        }
                        TextField("公開する内容を入力", text: $field.content, axis: .vertical)
                            .font(.system(size: 12))
                            .lineLimit(3...6)
                            .padding(10)
                            .background(BloomPalette.canvas, in: RoundedRectangle(cornerRadius: 12))
                        HStack {
                            Text(field.revealMinutes == 0 ? "最初から公開" : "累計時間で公開")
                                .font(.system(size: 10)).foregroundStyle(BloomPalette.muted)
                            Spacer()
                            Stepper("\(field.revealMinutes)分", value: $field.revealMinutes, in: 0...180, step: 1)
                                .labelsHidden().frame(width: 90)
                            Text("\(field.revealMinutes)分").font(.system(size: 11, weight: .semibold)).foregroundStyle(BloomPalette.blue)
                        }
                    }
                    .padding(13)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                }
                Text("出会いの累計時間は、離れたあとも保存されます。公開条件はいつでも変更できます。")
                    .font(.system(size: 10)).foregroundStyle(BloomPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(BloomPalette.canvas.ignoresSafeArea())
        .foregroundStyle(BloomPalette.ink)
        .onAppear(perform: loadFields)
        .onChange(of: fields) { _, _ in saveFields() }
    }

    private func loadFields() {
        guard let data = storedFields.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([EditableProfileField].self, from: data),
              !decoded.isEmpty else { return }
        fields = decoded
    }

    private func saveFields() {
        guard let data = try? JSONEncoder().encode(fields) else { return }
        storedFields = String(decoding: data, as: UTF8.self)
    }

    private func addField() {
        fields.append(EditableProfileField(title: "新しい項目", content: "", revealMinutes: 15, isPublic: true))
    }

    private func removeField(id: UUID) {
        fields.removeAll { $0.id == id }
    }
}
