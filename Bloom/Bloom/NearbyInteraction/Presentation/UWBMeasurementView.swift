import SwiftUI

struct UWBMeasurementView: View {
    @State private var model = UWBSessionModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if model.isMock {
                        Label("モック表示・実際のUWB計測ではありません", systemImage: "testtube.2")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                    VStack(spacing: 8) {
                        Text(model.peerName ?? "相手の端末")
                            .font(.headline)
                        if let distance = model.observation?.distanceMeters {
                            Text("\(distance, format: .number.precision(.fractionLength(2))) m")
                                .font(.system(size: 48, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .accessibilityLabel("距離 \(distance, format: .number.precision(.fractionLength(2))) メートル")
                        } else {
                            Text("— m")
                                .font(.system(size: 48, weight: .semibold, design: .rounded))
                            Text("距離は未取得").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    UWBDirectionView(direction: model.observation?.direction)
                    Text(model.status)
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("uwb.status")
                    if model.isRunning && !model.isMock {
                        Text("この端末：\(model.localName)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if !model.peers.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(model.peers) { peer in
                                Button { model.connect(to: peer) } label: {
                                    Label(peer.name, systemImage: "iphone.radiowaves.left.and.right")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    if model.isRunning {
                        Button("停止", role: .destructive) { model.stop() }
                            .buttonStyle(.bordered)
                    } else {
                        VStack(spacing: 12) {
                            Button("接続を待つ") { model.host() }
                                .buttonStyle(.borderedProminent)
                            Button("相手を探す") { model.browse() }
                                .buttonStyle(.bordered)
                        }
                        .disabled(!model.isSupported)
                        if !model.isSupported {
                            Text("この端末ではUWB計測を利用できません。")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        #if DEBUG
                        Button("モックで表示を確認") { model.startMock() }
                            .buttonStyle(.borderless)
                        #endif
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

#Preview { UWBMeasurementView() }
