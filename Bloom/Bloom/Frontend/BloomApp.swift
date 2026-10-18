import SwiftUI

@main
struct BloomApp: App {
    private let backend: Result<BackendDependencies, Error> = Result {
        BackendDependencies.live(config: try SupabaseConfig.load())
    }

    var body: some Scene {
        WindowGroup {
            switch backend {
            case .success(let dependencies):
                SessionRootView(dependencies: dependencies)
            case .failure(let error):
                ContentUnavailableView("接続設定を確認してください", systemImage: "exclamationmark.icloud", description: Text(error.localizedDescription))
            }
        }
    }
}

private struct SessionRootView: View {
    @State private var model: AppSessionModel
    @Environment(\.scenePhase) private var scenePhase

    init(dependencies: BackendDependencies) {
        _model = State(initialValue: AppSessionModel(dependencies: dependencies))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView("Bloomを準備しています")
            } else if let error = model.errorMessage {
                ContentUnavailableView {
                    Label("アカウントを確認できませんでした", systemImage: "exclamationmark.icloud")
                } description: {
                    Text(error)
                } actions: {
                    Button("再試行") { Task { await model.restore() } }
                        .buttonStyle(.glassProminent)
                }
            } else if let user = model.user, let profile = model.profile {
                HomeView(userID: user.id, profile: profile, dependencies: model.dependencies,
                         onProfileSaved: { model.profile = $0 },
                         onSignOut: { Task { await model.signOut() } })
                    .id(user.id)
            } else {
                AuthFlowView(authRepository: model.dependencies.authRepository,
                             profileRepository: model.dependencies.profileRepository,
                             needsProfile: model.user != nil) {
                    Task { await model.restore() }
                }
            }
        }
        .task { await model.restore() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !model.isLoading {
                Task { await model.refreshSession() }
            }
        }
    }
}

struct HomeView: View {
    let profile: Profile
    let dependencies: BackendDependencies
    let onProfileSaved: (Profile) -> Void
    let onSignOut: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var proximity: UWBConnectionService

    init(userID: UUID, profile: Profile, dependencies: BackendDependencies,
         onProfileSaved: @escaping (Profile) -> Void, onSignOut: @escaping () -> Void) {
        self.profile = profile
        self.dependencies = dependencies
        self.onProfileSaved = onProfileSaved
        self.onSignOut = onSignOut
        _proximity = State(initialValue: UWBConnectionService(personID: userID, repository: dependencies.profileRepository))
    }

    var body: some View {
        TabView {
            Tab("近く", systemImage: "sparkles") {
                NavigationStack { NearbyPeoplePage(proximity: proximity, ownProfile: profile) }
            }
            Tab("履歴", systemImage: "clock") {
                NavigationStack {
                    EncounterHistoryPage(proximity: proximity,
                                         repository: dependencies.profileRepository)
                }
            }
            Tab("プロフィール", systemImage: "person.crop.circle") {
                NavigationStack {
                    MyProfilePage(profile: profile, repository: dependencies.profileRepository,
                                  onSaved: onProfileSaved, onSignOut: {
                        proximity.stop()
                        onSignOut()
                    })
                }
            }
        }
        .tint(.pink)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { proximity.enteredBackground() }
            if phase == .active { proximity.becameActive() }
        }
        .onChange(of: profile.isDiscoverable) { _, allowed in
            if !allowed { proximity.stop() }
        }
        .onDisappear { proximity.stop() }
    }
}
