import Foundation
import Combine
import NearbyInteraction
import MultipeerConnectivity

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

final class UWBConnectionService: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, NISessionDelegate {
    @Published private(set) var status = "参加中"
    @Published private(set) var distance: Float?
    @Published private(set) var pendingRequestFrom: String?
    @Published private(set) var encounterActive = false
    @Published private(set) var encounterSeconds = 0
    @Published private(set) var records: [EncounterRecord] = []
    @Published private(set) var currentPeerName: String?

    private let serviceType = "hello-encounter"
    private var localPeer: MCPeerID?
    private var mcSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var nearbyPeers: [String: MCPeerID] = [:]
    private var targetName: String?
    private var invitedPeerNames = Set<String>()
    private var niSession: NISession?
    private var isParticipating = false
    private var pendingInvitation: ((Bool, MCSession?) -> Void)?
    private var enteredRangeAt: Date?
    private var leftRangeAt: Date?
    private var encounterStartedAt: Date?

    override init() {
        if let data = UserDefaults.standard.data(forKey: "hello.encounter.records"),
           let savedRecords = try? JSONDecoder().decode([EncounterRecord].self, from: data) {
            records = savedRecords
        }
        super.init()
    }

    func acceptPendingRequest() {
        guard let handler = pendingInvitation, let mcSession else { return }
        pendingInvitation = nil
        DispatchQueue.main.async { self.pendingRequestFrom = nil }
        handler(true, mcSession)
    }

    func rejectPendingRequest() {
        let handler = pendingInvitation
        pendingInvitation = nil
        DispatchQueue.main.async { self.pendingRequestFrom = nil }
        handler?(false, nil)
    }

    func startAdvertising(profileName: String) {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async { self.status = "UWB接続は実機で利用できます" }
        #else
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            DispatchQueue.main.async { self.status = "この端末はUWB距離測定に対応していません" }
            return
        }
        if localPeer?.displayName == profileName, mcSession != nil { return }
        stop()
        isParticipating = true
        let peer = MCPeerID(displayName: String(profileName.prefix(60)))
        localPeer = peer
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        mcSession = session

        let advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: ["app": "hello"], serviceType: serviceType)
        advertiser.delegate = self
        self.advertiser = advertiser
        advertiser.startAdvertisingPeer()

        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        browser.delegate = self
        self.browser = browser
        browser.startBrowsingForPeers()
        DispatchQueue.main.async { self.status = "近くのメンバーを探しています" }
        #endif
    }

    func stop() {
        isParticipating = false
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        mcSession?.disconnect()
        niSession?.invalidate()
        advertiser = nil
        browser = nil
        mcSession = nil
        niSession = nil
        localPeer = nil
        targetName = nil
        nearbyPeers.removeAll()
        invitedPeerNames.removeAll()
        DispatchQueue.main.async {
            self.distance = nil
            self.pendingRequestFrom = nil
            if self.encounterActive { self.finishEncounter(at: Date()) }
            self.status = "出会いを一時停止中"
        }
    }

    func connect(to profileName: String) {
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.distance = nil
            self.status = "UWB接続にはUWB対応iPhoneの実機が必要です"
        }
        #else
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            DispatchQueue.main.async { self.status = "UWB対応端末でお試しください" }
            return
        }
        guard isParticipating else {
            DispatchQueue.main.async { self.status = "出会いへの参加をONにしてください" }
            return
        }
        targetName = profileName
        DispatchQueue.main.async { self.status = "\(profileName)さんを探しています…" }
        inviteTargetIfAvailable()
        #endif
    }

    private func inviteTargetIfAvailable() {
        guard let targetName,
              let peer = nearbyPeers[targetName],
              !invitedPeerNames.contains(targetName),
              let browser,
              let mcSession,
              mcSession.connectedPeers.isEmpty else { return }
        invitedPeerNames.insert(targetName)
        browser.invitePeer(peer, to: mcSession, withContext: nil, timeout: 20)
        DispatchQueue.main.async { self.status = "接続の許可を待っています…" }
    }

    private func updateEncounter(with distance: Float) {
        let now = Date()
        if distance <= 4 {
            leftRangeAt = nil
            if encounterStartedAt == nil {
                if enteredRangeAt == nil { enteredRangeAt = now }
                if let enteredRangeAt, now.timeIntervalSince(enteredRangeAt) >= 5 {
                    encounterStartedAt = now
                    DispatchQueue.main.async { self.encounterActive = true; self.encounterSeconds = 0 }
                } else {
                    DispatchQueue.main.async { self.status = "4 m以内にいます · 出会いを確認中" }
                }
            } else if let encounterStartedAt {
                DispatchQueue.main.async { self.encounterSeconds = Int(now.timeIntervalSince(encounterStartedAt)) }
            }
        } else {
            enteredRangeAt = nil
            guard let encounterStartedAt else { return }
            if leftRangeAt == nil { leftRangeAt = now }
            if let leftRangeAt, now.timeIntervalSince(leftRangeAt) >= 8 {
                finishEncounter(at: leftRangeAt)
            } else {
                DispatchQueue.main.async { self.status = "離れています · 8秒後に出会いを保存" }
            }
        }
    }

    private func finishEncounter(at end: Date) {
        guard let start = encounterStartedAt else { return }
        let seconds = max(Int(end.timeIntervalSince(start)), 1)
        let record = EncounterRecord(id: UUID(), personName: currentPeerName ?? "近くの人", startedAt: start, durationSeconds: seconds)
        records.insert(record, at: 0)
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "hello.encounter.records")
        }
        encounterStartedAt = nil
        enteredRangeAt = nil
        leftRangeAt = nil
        DispatchQueue.main.async {
            self.encounterActive = false
            self.encounterSeconds = 0
            self.status = "出会いを保存しました · \(record.durationLabel)"
        }
    }

    func formattedCurrentEncounter(for personName: String) -> String? {
        guard encounterActive, currentPeerName == personName else { return nil }
        let minutes = encounterSeconds / 60
        let seconds = encounterSeconds % 60
        return minutes > 0 ? "\(minutes)分\(String(format: "%02d", seconds))秒" : "\(seconds)秒"
    }

    private func startNearbyInteraction(with peer: MCPeerID) {
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else { return }
        let session = NISession()
        session.delegate = self
        niSession = session
        guard let token = session.discoveryToken,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            DispatchQueue.main.async { self.status = "UWBセッションを開始できませんでした" }
            return
        }
        do {
            try mcSession?.send(data, toPeers: [peer], with: .reliable)
            DispatchQueue.main.async { self.status = "UWBの距離を測定しています" }
        } catch {
            DispatchQueue.main.async { self.status = "接続情報を送信できませんでした" }
        }
    }

    // MARK: Multipeer Connectivity

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard info?["app"] == "hello" else { return }
        nearbyPeers[peerID.displayName] = peerID
        inviteTargetIfAvailable()
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        nearbyPeers.removeValue(forKey: peerID.displayName)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        guard isParticipating, let mcSession, mcSession.connectedPeers.isEmpty, pendingInvitation == nil else {
            invitationHandler(false, nil)
            return
        }
        pendingInvitation = invitationHandler
        DispatchQueue.main.async {
            self.pendingRequestFrom = peerID.displayName
            self.status = "接続リクエストが届きました"
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            currentPeerName = peerID.displayName
            startNearbyInteraction(with: peerID)
        case .notConnected:
            niSession?.invalidate()
            niSession = nil
            if encounterActive { finishEncounter(at: Date()) }
            DispatchQueue.main.async {
                self.distance = nil
                self.currentPeerName = nil
                self.status = self.isParticipating ? "近くのメンバーを探しています" : "出会いを一時停止中"
            }
        case .connecting:
            DispatchQueue.main.async { self.status = "接続しています…" }
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data),
              let niSession else { return }
        niSession.run(NINearbyPeerConfiguration(peerToken: token))
        DispatchQueue.main.async { self.status = "UWBで接続しました" }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: Nearby Interaction

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let measuredDistance = nearbyObjects.first(where: { $0.distance != nil })?.distance else { return }
        DispatchQueue.main.async {
            self.distance = measuredDistance
            self.status = measuredDistance <= 4 ? "UWB接続中 · \(String(format: "%.1f", measuredDistance)) m" : "4 m以内に近づくと出会いを記録します"
        }
        updateEncounter(with: measuredDistance)
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        niSession = nil
        DispatchQueue.main.async {
            self.distance = nil
            self.status = "UWB接続が終了しました"
        }
    }

    func sessionWasSuspended(_ session: NISession) {
        DispatchQueue.main.async { self.status = "UWB接続を一時停止中" }
    }

    func sessionSuspensionEnded(_ session: NISession) {
        if let configuration = session.configuration {
            session.run(configuration)
        }
    }
}
