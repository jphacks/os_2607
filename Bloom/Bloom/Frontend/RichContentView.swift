import SwiftUI
import AVKit

/// Shared renderer for explicitly published profile content and message attachments.
struct RichContentView: View {
    let kind: RichContentKind
    let value: String
    let title: String

    var body: some View {
        Group {
            if kind == .text {
                Text(value).textSelection(.enabled)
            } else if let url = MediaAddress.httpsURL(value) {
                switch kind {
                case .image: RemotePhotoView(url: url, title: title)
                case .video: InlineVideoView(url: url)
                case .url: RichLinkCard(url: url, title: title)
                case .text: Text(value)
                }
            } else {
                Label("このメディアのURLを確認してください。", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

private struct RemotePhotoView: View {
    let url: URL
    let title: String
    @State private var revision = 0
    @State private var expanded = false

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView("写真を読み込み中").frame(maxWidth: .infinity, minHeight: 180)
            case .success(let image):
                Button { expanded = true } label: {
                    image.resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .padding(10).background(.regularMaterial, in: Circle()).padding(10)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title)を拡大")
            case .failure:
                VStack(spacing: 12) {
                    Label("写真を読み込めませんでした", systemImage: "photo.badge.exclamationmark")
                    Button("再試行") { revision += 1 }
                }
                .font(.callout).frame(maxWidth: .infinity, minHeight: 160)
            @unknown default: EmptyView()
            }
        }
        .id(revision)
        .sheet(isPresented: $expanded) {
            ExpandedPhotoView(url: url, title: title)
        }
    }
}

private struct ExpandedPhotoView: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale = 1.0
    @GestureState private var magnification = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                                .frame(width: geometry.size.width * min(max(scale * magnification, 1), 4),
                                       height: geometry.size.height * min(max(scale * magnification, 1), 4))
                                .gesture(MagnifyGesture().updating($magnification) { value, state, _ in
                                    state = value.magnification
                                }.onEnded { value in scale = min(max(scale * value.magnification, 1), 4) })
                                .accessibilityLabel(title)
                        } else if phase.error != nil {
                            ContentUnavailableView("写真を読み込めませんでした", systemImage: "photo")
                        } else {
                            ProgressView().frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .bottomBar) { Button("倍率を戻す") { scale = 1 } }
            }
        }
    }
}

private struct InlineVideoView: View {
    let url: URL
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    @State private var failed = false
    @State private var revision = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ProgressView("動画を準備中").frame(maxWidth: .infinity, minHeight: 180)
            }
            if failed {
                Label("動画を再生できません。動画ファイルのURLをご確認ください。", systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Button("再試行") { revision += 1 }
            }
            Link("元の動画を開く", destination: url).font(.caption)
        }
        .task(id: "\(url.absoluteString)-\(revision)-\(scenePhase)") {
            guard scenePhase == .active else { player?.pause(); return }
            failed = false
            let activePlayer = AVPlayer(url: url)
            player?.pause()
            player = activePlayer
            defer { activePlayer.pause() }
            while !Task.isCancelled {
                if activePlayer.currentItem?.status == .failed { failed = true; return }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
        .onDisappear { player?.pause(); player = nil }
    }
}

private struct RichLinkCard: View {
    let url: URL
    let title: String
    var body: some View {
        Link(destination: url) {
            HStack(spacing: 16) {
                Image(systemName: "link").font(.title2).padding(14)
                    .background(.pink.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title.isEmpty ? "リンクを開く" : title).font(.headline)
                    Text(url.host ?? url.absoluteString).font(.caption).foregroundStyle(.secondary)
                    Text(url.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.pink.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
        }
    }
}
