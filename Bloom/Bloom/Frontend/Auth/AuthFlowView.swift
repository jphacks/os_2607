import SwiftUI

struct AuthFlowView: View {
    let session: AppSessionModel
    private var isSaving: Bool { session.isBusy }
    private var errorMessage: String? { session.errorMessage }
    @State private var isCreatingAccount = true
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var affiliation = ""
    @State private var bio = ""
    @State private var hobby = ""
    @State private var isDiscoverable = false
    @State private var hobbyIsPublic = false
    var body: some View {
        ZStack {
            BloomPalette.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    brandMark
                    if let notice = session.notice { Text(notice).font(.callout) }
                    if session.phase == .signedOut {
                        accountForm
                    } else {
                        profileForm
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .padding(.bottom, 32)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .disabled(isSaving)
        .foregroundStyle(BloomPalette.ink)
        .preferredColorScheme(.light)
        .alert("入力を確認してください", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var brandMark: some View {
        HStack(spacing: 9) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(BloomPalette.blue)
            Text("Bloom")
                .font(.system(size: 25, weight: .bold, design: .rounded))
        }
    }

    private var accountForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isCreatingAccount ? "はじめまして" : "おかえりなさい")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(isCreatingAccount ? "アカウントを作成して、プロフィールを設定しましょう。" : "Bloomにログインしましょう。")
                    .font(.system(size: 13))
                    .foregroundStyle(BloomPalette.muted)
            }

            VStack(spacing: 12) {
                inputField(title: "メールアドレス", placeholder: "name@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                VStack(alignment: .leading, spacing: 7) {
                    Text("パスワード").font(.system(size: 12, weight: .semibold))
                    SecureField("8文字以上", text: $password)
                        .textContentType(isCreatingAccount ? .newPassword : .password)
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            Button(action: submitAccount) {
                HStack {
                    Spacer()
                    if isSaving { ProgressView().tint(.white) }
                    else { Text(isCreatingAccount ? "アカウントを作成" : "ログイン") }
                    Spacer()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .background(BloomPalette.blue, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isSaving)

            Button {
                isCreatingAccount.toggle()
                session.errorMessage = nil
            } label: {
                HStack(spacing: 4) {
                    Spacer()
                    Text(isCreatingAccount ? "すでにアカウントをお持ちですか？" : "初めて利用しますか？")
                        .foregroundStyle(BloomPalette.muted)
                    Text(isCreatingAccount ? "ログイン" : "新規登録")
                        .foregroundStyle(BloomPalette.blue)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var profileForm: some View {
        VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 6) {
                Text("プロフィールを作成")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("公開する内容は、あとからプロフィールで編集できます。")
                    .font(.system(size: 12))
                    .foregroundStyle(BloomPalette.muted)
            }

            VStack(spacing: 13) {
                inputField(title: "氏名・表示名", placeholder: "例：あおい", text: $displayName)
                inputField(title: "所属", placeholder: "学校・会社など（任意）", text: $affiliation)
                VStack(alignment: .leading, spacing: 7) {
                    Text("自己紹介").font(.system(size: 12, weight: .semibold))
                    TextField("自由に自己紹介を書いてください", text: $bio, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                inputField(title: "趣味・話題（任意）", placeholder: "例：音楽、カフェ、散歩", text: $hobby)
            }

            Toggle(isOn: $isDiscoverable) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("基本プロフィールを公開する")
                        .font(.system(size: 13, weight: .semibold))
                    Text("名前・所属・自己紹介・プロフィール画像をログイン済みユーザーに公開します")
                        .font(.system(size: 10))
                        .foregroundStyle(BloomPalette.muted)
                }
            }
            .tint(BloomPalette.green)
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 15))

            Toggle("趣味の公開を許可する", isOn: $hobbyIsPublic)
            Text("公開する趣味は、一緒に過ごした累計60秒から画面に表示されます。")
                .font(.caption).foregroundStyle(BloomPalette.muted)
            Button(action: saveProfile) {
                HStack {
                    Spacer()
                    if isSaving { ProgressView().tint(.white) }
                    else { Text("保存してはじめる") }
                    Spacer()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .background(BloomPalette.blue, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

            if session.errorMessage != nil {
                Button("保存済みプロフィールを確認") { Task { await session.restore() } }
            }
            Button("ログアウトして戻る") { Task { await session.signOut() } }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BloomPalette.muted)
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
        }
    }

    private func inputField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 12, weight: .semibold))
            TextField(placeholder, text: text)
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func submitAccount() {
        Task { await session.authenticate(email: email, password: password, creating: isCreatingAccount) }
    }

    private func saveProfile() {
        Task {
            await session.createProfile(name: displayName, affiliation: affiliation, bio: bio, hobby: hobby,
                isPublic: isDiscoverable, hobbyIsPublic: hobbyIsPublic)
        }
    }
}
