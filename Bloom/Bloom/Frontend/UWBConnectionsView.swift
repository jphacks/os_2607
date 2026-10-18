import SwiftUI

struct UWBConnectionsView: View {
    let proximity: UWBConnectionService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("近くの端末").font(.headline)
            if proximity.isParticipating {
                Text("この端末：\(proximity.session.localName)").font(.subheadline)
                Text("相手も参加を開始し、片方の端末で相手の端末名を選んでください。")
                    .font(.caption).foregroundStyle(.secondary)
                Text(verbatim: proximity.session.status)
                    .font(.caption).foregroundStyle(.secondary)
                if let error = proximity.connectionError {
                    Text(verbatim: error).foregroundStyle(.secondary)
                }
                if proximity.session.discoveredPeers.isEmpty {
                    Text("端末を探しています…").foregroundStyle(.secondary)
                }
                ForEach(proximity.session.discoveredPeers) { peer in
                    Button {
                        proximity.connect(to: peer)
                    } label: {
                        Label(peer.name, systemImage: "iphone.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                ForEach(proximity.session.connections) { connection in
                    UWBConnectionCard(connection: connection) {
                        proximity.session.disconnect(id: connection.id)
                    }
                }
                Button("接続をすべて停止", role: .destructive) { proximity.stop() }
            } else {
                Text("参加すると、近くの端末から接続して距離・方向を測定できます。")
                    .font(.subheadline)
                Button("参加を開始") { proximity.start() }
                    .buttonStyle(.borderedProminent)
                if let error = proximity.connectionError {
                    Text(verbatim: error).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UWBConnectionCard: View {
    let connection: UWBPeerConnection
    let disconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: connection.peerName ?? "接続中の端末").font(.headline)
            if let personID = connection.personID {
                Text("端末ID：\(personID.uuidString.prefix(8))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            switch connection.state {
            case .connecting:
                Text("接続情報を交換しています…")
            case .measuring:
                if let distance = connection.observation?.distanceMeters {
                    Text("\(distance, format: .number.precision(.fractionLength(2))) m")
                        .font(.largeTitle).monospacedDigit()
                } else {
                    Text("距離は未取得")
                }
                UWBDirectionView(direction: connection.observation?.direction)
            case .unavailable(let reason), .failed(let reason):
                Text(verbatim: reason.localizedDescription).foregroundStyle(.secondary)
            }
            Button("切断", role: .destructive, action: disconnect)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
