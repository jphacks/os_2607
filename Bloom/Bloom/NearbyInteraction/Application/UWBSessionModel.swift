import Foundation
import Network
import Observation

@MainActor
@Observable
final class UWBSessionModel {
    private(set) var peers: [UWBPeer] = []
    private(set) var observation: UWBObservation?
    private(set) var status = "2台の端末でこの画面を開いてください。"
    private(set) var isRunning = false
    private(set) var isConnected = false
    private(set) var isMock = false
    private(set) var peerName: String?
    let isSupported = NearbyRangingSession.isSupported

    @ObservationIgnored private let personID = LocalPersonIdentity.load()
    @ObservationIgnored private var transport = UWBPeerTransport()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var ranging: NearbyRangingSession?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var lastObservation: ContinuousClock.Instant?

    var localName: String { transport.serviceName }

    func host() {
        stop()
        guard requireSupport() else { return }
        isRunning = true
        status = "接続を準備しています。"
        let generation = generation
        let transport = transport
        task = Task {
            do {
                try await transport.host(status: { [weak self] text in
                    guard let self, self.generation == generation, !self.isConnected else { return }
                    self.status = text
                }, connected: { [weak self] connection in
                    guard let self, self.generation == generation, !Task.isCancelled else { return }
                    await self.measure(on: connection, generation: generation)
                })
            } catch {
                finish(error, generation: generation)
            }
        }
    }

    func browse() {
        stop()
        guard requireSupport() else { return }
        isRunning = true
        status = "接続待ちの端末を探しています。"
        let generation = generation
        let transport = transport
        task = Task {
            do {
                try await transport.browse(update: { [weak self] peers in
                    guard let self, self.generation == generation else { return }
                    self.peers = peers
                    self.status = peers.isEmpty ? "相手の端末で「接続を待つ」を押してください。" : "接続する端末を選んでください。"
                }, status: { [weak self] text in
                    guard let self, self.generation == generation else { return }
                    self.status = text
                })
            } catch {
                finish(error, generation: generation)
            }
        }
    }

    func connect(to peer: UWBPeer) {
        do {
            // Resolve before cancelling the browser, which clears its endpoint map.
            let connection = try transport.connection(to: peer)
            stop()
            guard requireSupport() else { return }
            isRunning = true
            peerName = peer.name
            let generation = generation
            task = Task {
                await measure(on: connection, generation: generation)
                guard self.generation == generation else { return }
                isRunning = false
            }
        } catch { status = error.localizedDescription }
    }

    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        ranging?.stop()
        ranging = nil
        transport = UWBPeerTransport()
        peers = []
        observation = nil
        lastObservation = nil
        peerName = nil
        isConnected = false
        isRunning = false
        isMock = false
        status = "停止中です。接続方法を選んでください。"
    }

    private func requireSupport() -> Bool {
        guard isSupported else {
            status = "この端末はUWB計測に対応していません。表示確認にはモックを使えます。"
            return false
        }
        return true
    }

    private func measure(on connection: NetworkConnection<TCP>, generation: UUID) async {
        let ranging = NearbyRangingSession()
        self.ranging = ranging
        isConnected = true
        peers = []
        status = "接続・計測情報を交換しています。"
        defer {
            ranging.stop()
            if self.generation == generation {
                self.ranging = nil
                isConnected = false
                observation = nil
                lastObservation = nil
                peerName = nil
            }
        }
        do {
            let token = try ranging.prepare()
            let hello = try await withUWBTimeout(seconds: 20) {
                try await UWBPeerTransport.send(.hello(personID: self.personID, token: token), on: connection)
                return try await UWBPeerTransport.receive(on: connection)
            }
            try Task.checkCancellation()
            guard self.generation == generation else { return }
            let (remoteID, remoteToken) = try hello.validatedHello(localID: personID)
            peerName = peerName ?? "相手 \(remoteID.uuidString.prefix(6))"
            try ranging.start(personID: remoteID, tokenData: remoteToken)
            status = "距離・方向を取得中です。端末の背面を相手に向けてください。"

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor @Sendable in
                    for await event in ranging.events {
                        try Task.checkCancellation()
                        guard self.generation == generation else { return }
                        switch event {
                        case .observation(let observation):
                            self.observation = observation
                            self.lastObservation = .now
                            self.status = observation.direction == nil ? "方向を取得中です。端末を相手に向けてください。" : "計測中"
                        case .unavailable(let text):
                            self.observation = nil
                            self.lastObservation = nil
                            self.status = text
                        case .failed(let text): throw UWBFailure.message(text)
                        }
                    }
                }
                group.addTask { @MainActor @Sendable in
                    while !Task.isCancelled {
                        let message = try await withUWBTimeout(seconds: 10) {
                            try await UWBPeerTransport.receive(on: connection)
                        }
                        guard message.kind == .heartbeat, message.personID == nil, message.discoveryToken == nil else {
                            throw UWBFailure.message("想定外の通信メッセージを受信しました。")
                        }
                    }
                }
                group.addTask { @MainActor @Sendable in
                    while !Task.isCancelled {
                        try await UWBPeerTransport.send(.heartbeat, on: connection)
                        try await Task.sleep(for: .seconds(2))
                    }
                }
                group.addTask { @MainActor @Sendable in
                    while !Task.isCancelled {
                        try await Task.sleep(for: .milliseconds(500))
                        guard self.generation == generation else { return }
                        if let last = self.lastObservation, last.duration(to: .now) >= .seconds(3) {
                            self.observation = nil
                            self.lastObservation = nil
                            self.status = "計測値が更新されていません。端末を相手に向けてください。"
                        }
                    }
                }
                defer { group.cancelAll() }
                try await group.next()
            }
        } catch {
            guard self.generation == generation, !Task.isCancelled else { return }
            status = error.localizedDescription + " 接続をやり直してください。"
        }
    }

    private func finish(_ error: any Error, generation: UUID) {
        guard self.generation == generation, !Task.isCancelled else { return }
        isRunning = false
        peers = []
        status = error.localizedDescription
    }

    func startMock() {
        stop()
        isRunning = true
        isMock = true
        isConnected = true
        peerName = "モック端末"
        task = Task {
            do {
                for await sample in UWBMockSource.samples() {
                    try Task.checkCancellation()
                    observation = sample
                    status = sample == nil ? "モック：観測欠損" : "モック：距離・方向の表示確認"
                }
            } catch { /* A stopped demo must not overwrite the next session. */ }
        }
    }
}

