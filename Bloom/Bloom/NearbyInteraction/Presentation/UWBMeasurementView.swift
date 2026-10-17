import SwiftUI

struct UWBMeasurementView: View {
    @State private var model = UWBSessionModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    UWBMeasurementSummary(
                        peerName: model.peerName,
                        distanceMeters: model.observation?.distanceMeters
                    )
                    UWBDirectionView(direction: model.observation?.direction)
                    UWBConnectionStatus(
                        status: model.status,
                        localName: model.isRunning ? model.localName : nil
                    )
                    UWBPeerList(peers: model.peers) { peer in
                        model.connect(to: peer)
                    }
                    UWBSessionControls(
                        isRunning: model.isRunning,
                        isSupported: model.isSupported
                    ) {
                        model.host()
                    } browse: {
                        model.browse()
                    } stop: {
                        model.stop()
                    }
                    Text("片方で「接続を待つ」、もう片方で「相手を探す」を選びます。端末を縦に持ち、背面を相手へ向けてください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("UWB距離・方向")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: scenePhase) { _, phase in
            // Permission sheets can make the scene inactive; only stop in background.
            if phase == .background { model.stop() }
        }
        .onDisappear { model.stop() }
    }
}

private struct UWBMeasurementSummary: View {
    let peerName: String?
    let distanceMeters: Double?

    var body: some View {
        VStack(spacing: 8) {
            Text(peerName ?? "相手の端末")
                .font(.headline)
            if let distanceMeters {
                Text("\(distanceMeters, format: .number.precision(.fractionLength(2))) m")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel(
                        "距離 \(distanceMeters, format: .number.precision(.fractionLength(2))) メートル"
                    )
            } else {
                Text("— m")
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                Text("距離は未取得")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct UWBConnectionStatus: View {
    let status: String
    let localName: String?

    var body: some View {
        VStack(spacing: 24) {
            Text(status)
                .font(.callout)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("uwb.status")
            if let localName {
                Text("この端末：\(localName)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct UWBPeerList: View {
    let peers: [UWBPeer]
    let connect: (UWBPeer) -> Void

    var body: some View {
        if !peers.isEmpty {
            VStack(spacing: 12) {
                ForEach(peers) { peer in
                    Button {
                        connect(peer)
                    } label: {
                        Label(peer.name, systemImage: "iphone.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct UWBSessionControls: View {
    let isRunning: Bool
    let isSupported: Bool
    let host: () -> Void
    let browse: () -> Void
    let stop: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if isRunning {
                Button("停止", role: .destructive, action: stop)
                    .buttonStyle(.bordered)
            } else {
                VStack(spacing: 12) {
                    Button("接続を待つ", action: host)
                        .buttonStyle(.borderedProminent)
                    Button("相手を探す", action: browse)
                        .buttonStyle(.bordered)
                }
                .disabled(!isSupported)
                if !isSupported {
                    Text("この端末ではUWB計測を利用できません。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview { UWBMeasurementView() }
