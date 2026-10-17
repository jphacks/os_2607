import SwiftUI

/// Inject BackendDependencies.live(config:).profileRepository after authentication.
/// This example does not fetch or display time-locked contents automatically.
struct ProfileRepositoryExampleView: View {
    let profileRepository: any ProfileRepository
    let personID: UUID
    @State private var profile: PublicProfile?
    @State private var status = ""

    var body: some View {
        VStack {
            Text(profile?.displayName ?? "プロフィール")
            Text(status)
            Button("自分の非公開メモを作成") {
                Task {
                    do {
                        let created = try await profileRepository.createContent(.init(
                            type: .text, title: "メモ", value: "会話のメモ", unlockAfterSeconds: 0,
                            displayOrder: 0, isPublic: false))
                        status = "作成しました: \(created.title)"
                    } catch { status = "保存できませんでした" }
                }
            }
        }
        .task(id: personID) {
            profile = nil
            do { profile = try await profileRepository.fetchProfile(personID: personID) }
            catch { status = "プロフィールを取得できませんでした" }
        }
    }
}
