import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthFlowView: View {
    private enum Step {
        case account
        case profile
    }

    @State private var appleNonce: String?
    @State private var appleRequestState: String?
    @State private var step: Step = .account
    @State private var isCreatingAccount = true
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var affiliation = ""
    @State private var bio = ""
    @State private var isDiscoverable = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var alertTitle = "処理を完了できませんでした"

    let authRepository: any AuthRepository
    let profileRepository: any ProfileRepository
    let onAuthenticated: () -> Void

    init(authRepository: any AuthRepository, profileRepository: any ProfileRepository,
         needsProfile: Bool = false, onAuthenticated: @escaping () -> Void) {
        self.authRepository = authRepository
        self.profileRepository = profileRepository
        self.onAuthenticated = onAuthenticated
        _step = State(initialValue: needsProfile ? .profile : .account)
    }

    var body: some View {
        NavigationStack {
            Form {
                if step == .account {
                    Section {
                        SignInWithAppleButton(.continue, onRequest: prepareAppleRequest, onCompletion: completeAppleRequest)
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 50)
                            .disabled(isSaving)
                    }
                    Section("メールでログイン") {
                        TextField("メールアドレス", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                        SecureField("パスワード", text: $password)
                            .textContentType(isCreatingAccount ? .newPassword : .password)
                        Button(action: submitAccount) {
                            HStack {
                                Text(isCreatingAccount ? "アカウントを作成" : "ログイン")
                                if isSaving { ProgressView() }
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isSaving)
                        Button(isCreatingAccount ? "登録済みの方はログイン" : "新規登録はこちら") {
                            isCreatingAccount.toggle()
                            errorMessage = nil
                        }
                        .disabled(isSaving)
                    }
                } else {
                    Section("基本情報") {
                        TextField("氏名・表示名", text: $displayName)
                        TextField("所属（任意）", text: $affiliation)
                        TextField("自己紹介", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    Section {
                        Toggle("近くの人に見つけてもらう", isOn: $isDiscoverable)
                    } footer: {
                        Text("公開する内容は、あとからプロフィールで編集できます。")
                    }
                    Section {
                        Button(action: saveProfile) {
                            HStack {
                                Text("保存してはじめる")
                                if isSaving { ProgressView() }
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(isSaving || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle(step == .account ? "Bloom" : "プロフィールを作成")
            .toolbar {
                if step == .profile {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("戻る", systemImage: "chevron.backward") { step = .account }
                            .disabled(isSaving)
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
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
            onAuthenticated()
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

                await MainActor.run { onAuthenticated() }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
            await MainActor.run { isSaving = false }
        }
    }
}
