import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthFlowView: View {
    private enum Step {
        case account
        case profile
    }

    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var appleNonce: String?
    @State private var appleRequestState: String?
    @State private var step: Step = .account
    @State private var isCreatingAccount = true
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var affiliation = ""
    @State private var bio = ""
    @State private var hobby = ""
    @State private var isDiscoverable = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var alertTitle = "処理を完了できませんでした"

    let authRepository: any AuthRepository
    let profileRepository: any ProfileRepository

    var body: some View {
        ZStack {
            BloomPalette.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    brandMark
                    if step == .account {
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
        .foregroundStyle(BloomPalette.ink)
        .preferredColorScheme(.light)
        .alert(alertTitle, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
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

            SignInWithAppleButton(.continue, onRequest: prepareAppleRequest, onCompletion: completeAppleRequest)
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .disabled(isSaving)

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
                errorMessage = nil
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
                    Text("近くの人に見つけてもらう")
                        .font(.system(size: 13, weight: .semibold))
                    Text("あとからプロフィール設定で変更できます")
                        .font(.system(size: 10))
                        .foregroundStyle(BloomPalette.muted)
                }
            }
            .tint(BloomPalette.green)
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 15))

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

            Button("アカウント画面に戻る") { step = .account }
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

    private func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        // SystemRandomNumberGenerator uses the system cryptographically secure random source.
        let nonce = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
        let state = UUID().uuidString
        appleNonce = nonce
        appleRequestState = state
        isSaving = true
        errorMessage = nil
        alertTitle = "Appleでログインできませんでした"
        request.requestedScopes = [.email, .fullName]
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        request.state = state
    }

    private func completeAppleRequest(_ result: Result<ASAuthorization, Error>) {
        let nonce = appleNonce
        let expectedState = appleRequestState
        appleNonce = nil
        appleRequestState = nil
        switch result {
        case .failure(let error):
            isSaving = false
            if let error = error as? ASAuthorizationError, error.code == .canceled { return }
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce, let expectedState, credential.state == expectedState,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8), !token.isEmpty else {
                isSaving = false
                errorMessage = "Appleの認証情報を確認できませんでした。もう一度お試しください。"
                return
            }
            // Apple may supply the name only once. Prefill it for the user's explicit profile save.
            let suggestedName = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
            Task {
                defer { isSaving = false }
                do {
                    try await authRepository.signInWithApple(idToken: token, nonce: nonce)
                    if displayName.isEmpty, let suggestedName { displayName = suggestedName }
                    try await finishSignIn()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func finishSignIn() async throws {
        do {
            _ = try await profileRepository.fetchMyProfile()
            didCompleteOnboarding = true
        } catch BackendError.notFound {
            step = .profile
        }
    }

    private func submitAccount() {
        guard !isSaving else { return }
        alertTitle = "処理を完了できませんでした"
        isSaving = true
        Task {
            do {
                if isCreatingAccount {
                    try await authRepository.signUp(email: email, password: password)
                    if try await authRepository.currentUser() != nil {
                        step = .profile
                    } else {
                        isCreatingAccount = false
                        password = ""
                        alertTitle = "メールをご確認ください"
                        errorMessage = "確認メールのリンクを開いてから、ログインしてください。"
                    }
                } else {
                    try await authRepository.signIn(email: email, password: password)
                    try await finishSignIn()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isSaving = false }
        }
    }

    private func saveProfile() {
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        isSaving = true
        Task {
            do {
                _ = try await profileRepository.createProfile(
                    ProfileCreateInput(
                        displayName: cleanName,
                        affiliation: affiliation.trimmingCharacters(in: .whitespacesAndNewlines),
                        bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                        avatarPath: nil,
                        isDiscoverable: isDiscoverable
                    )
                )

                let cleanHobby = hobby.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanHobby.isEmpty {
                    _ = try await profileRepository.createContent(
                        ProfileContentCreateInput(
                            type: .text,
                            title: "趣味",
                            value: cleanHobby,
                            unlockAfterSeconds: 60,
                            displayOrder: 0,
                            isPublic: true
                        )
                    )
                }
                await MainActor.run { didCompleteOnboarding = true }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isSaving = false }
        }
    }
}
