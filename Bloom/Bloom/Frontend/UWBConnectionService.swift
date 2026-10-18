import Foundation
import Observation

struct EncounterRecord: Identifiable, Codable {
    let id: UUID
    let personName: String
    let startedAt: Date
    let durationSeconds: Int

    var durationLabel: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return minutes > 0 ? "\(minutes)分\(String(format: "%02d", seconds))秒" : "\(seconds)秒"
    }
}

/// Frontend adapter for the existing Network.framework / Nearby Interaction stack.
@MainActor
@Observable
final class UWBConnectionService {
    private(set) var session = UWBMultiPeerSession()
    private(set) var isParticipating = false
    private(set) var connectionError: String?
    private(set) var records: [EncounterRecord] = []

    init() {
        // Preserve legacy history without associating name-only records with discovered devices.
        if let data = UserDefaults.standard.data(forKey: "hello.encounter.records"),
           let saved = try? JSONDecoder().decode([EncounterRecord].self, from: data) {
            records = saved
        }
    }

    func start() {
        guard !isParticipating else { return }
        // A fresh session isolates callbacks from any previously cancelled run.
        session = UWBMultiPeerSession()
        connectionError = nil
        guard session.isSupported else {
            connectionError = "UWB接続には対応するiPhoneの実機が必要です。"
            return
        }
        isParticipating = true
        session.startHosting()
        session.startBrowsing()
    }

    func connect(to peer: UWBPeer) {
        guard isParticipating else { return }
        do {
            try session.connect(to: peer)
            connectionError = nil
        } catch {
            connectionError = error.localizedDescription
        }
    }

    func stop() {
        session.stop()
        isParticipating = false
        connectionError = nil
    }
}
