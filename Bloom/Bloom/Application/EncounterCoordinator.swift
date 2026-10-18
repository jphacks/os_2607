import Foundation
import Observation

@MainActor
protocol NearbySession: AnyObject {
    var isSupported: Bool { get }
    var discoveredPeers: [UWBPeer] { get }
    var connections: [UWBPeerConnection] { get }
    var pendingConnectionIDs: [UUID] { get }
    var events: AsyncStream<UWBMultiPeerEvent> { get }
    func startHosting()
    func startBrowsing()
    func connect(to peer: UWBPeer) throws -> UUID
    func disconnect(from personID: UUID)
    func acceptConnection(id: UUID)
    func rejectConnection(id: UUID)
    func stop()
}

struct RevealedProfileField: Identifiable {
    let id: UUID
    let title: String
    let value: String?
    let requiredSeconds: Int
}

@MainActor @Observable
final class EncounterCoordinator {
    let nearby: any NearbySession
    private(set) var records: [Encounter] = []
    private(set) var publicProfiles: [UUID: CachedPublicProfile] = [:]
    private(set) var profileMessages: [UUID: String] = [:]
    private(set) var isParticipating = false
    var status = "停止中"
    var errorMessage: String?
    private(set) var activePeople: Set<UUID> = []
    @ObservationIgnored private let ownerID: UUID
    @ObservationIgnored private let store: any LocalStore
    @ObservationIgnored private let profiles: any ProfileRepository
    @ObservationIgnored private var trackers: [UUID: EncounterTracker] = [:]
    @ObservationIgnored private var connections: [UUID: UUID] = [:]
    @ObservationIgnored private var pendingSaves: [UUID: Encounter] = [:]
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var refreshRevision = UUID()
    @ObservationIgnored private var isActive = true
    @ObservationIgnored private var isValid = true
    @ObservationIgnored private let clock: () -> TimeInterval

    init(ownerID: UUID, store: any LocalStore, profiles: any ProfileRepository, nearby: any NearbySession,
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.ownerID = ownerID; self.store = store; self.profiles = profiles; self.nearby = nearby; self.clock = clock
        do { records = try store.encounters(ownerID: ownerID) }
        catch { errorMessage = "履歴を読み込めませんでした。" }
    }

    var personIDs: [UUID] {
        Set(records.map(\.personID) + nearby.connections.compactMap(\.personID))
            .filter { $0 != ownerID }.sorted { $0.uuidString < $1.uuidString }
    }
    func totalSeconds(for id: UUID) -> TimeInterval { records.filter { $0.personID == id }.reduce(0) { $0 + $1.duration } }
    func currentSeconds(for id: UUID) -> TimeInterval { trackers[id]?.active?.duration ?? 0 }
    func fields(for id: UUID) -> [RevealedProfileField] {
        (publicProfiles[id]?.contents ?? []).filter(\.isPublic).map {
            RevealedProfileField(id: $0.id, title: $0.title,
                value: RevealPolicy.allows(isPublic: $0.isPublic, requiredSeconds: $0.unlockAfterSeconds,
                    totalSeconds: totalSeconds(for: id)) ? $0.value : nil,
                requiredSeconds: $0.unlockAfterSeconds)
        }
    }
    func start() {
        guard isValid, isActive, nearby.isSupported else { status = "この端末ではUWB計測を利用できません。"; return }
        startTasks()
        isParticipating = true
        nearby.startHosting(); nearby.startBrowsing()
    }
    func connect(to peer: UWBPeer) {
        guard isParticipating else { return }
        do { _ = try nearby.connect(to: peer) }
        catch { errorMessage = error.localizedDescription }
    }
    func stop() {
        isParticipating = false
        finishAll(); nearby.stop(); connections = [:]; status = "停止中"
    }
    func suspend() {
        isActive = false; stop(); cancelTasks(); publicProfiles = [:]; profileMessages = [:]
    }
    func resume() {
        guard isValid else { return }
        isActive = true; startTasks(); refreshAll()
    }
    func shutdown() { suspend(); isValid = false; eventTask?.cancel(); eventTask = nil }

    func refreshProfile(_ id: UUID) {
        guard isValid, isActive, id != ownerID, refreshTasks[id] == nil else { return }
        let revision = refreshRevision
        refreshTasks[id] = Task { [weak self] in
            guard let self else { return }
            defer { if revision == refreshRevision { refreshTasks[id] = nil } }
            do {
                let profile = try await profiles.fetchProfile(personID: id)
                let contents = try await profiles.fetchContents(personID: id)
                guard isValid, isActive, revision == refreshRevision, !Task.isCancelled else { return }
                let value = CachedPublicProfile(profile: profile,
                    contents: contents.filter { $0.isPublic && $0.profileID == id }, fetchedAt: .now)
                try store.save(value, ownerID: ownerID)
                publicProfiles[id] = value; profileMessages[id] = nil
            } catch {
                guard isValid, isActive, revision == refreshRevision, !Task.isCancelled else { return }
                publicProfiles[id] = nil
                profileMessages[id] = "公開情報を取得できません。再読み込みしてください。"
                do { try store.removeCachedProfile(personID: id, ownerID: ownerID) }
                catch { errorMessage = "古いプロフィールキャッシュの削除に失敗しました。" }
            }
        }
    }
    func refreshAll() { personIDs.forEach(refreshProfile) }

    // Deterministic input boundary; tests supply observations without starting real radios.
    func receive(_ event: UWBMultiPeerEvent) {
        guard isValid, isActive, isParticipating else { return }
        switch event {
        case let .statusChanged(message): status = message
        case .discoveredPeersChanged: break
        case let .connectionRemoved(id):
            if let personID = connections.removeValue(forKey: id) { finish(personID) }
        case let .connectionChanged(connection):
            guard let id = connection.personID, id != ownerID else { return }
            // Failed duplicate connections must not terminate another live connection's encounter.
            if case .failed(reason: .duplicateConnection) = connection.state { return }
            if connections[connection.id] == nil { refreshProfile(id) }
            connections[connection.id] = id
            if case .measuring = connection.state, let observation = connection.observation {
                var tracker = trackers[id] ?? EncounterTracker(personID: id)
                if let value = tracker.observe(distance: observation.distanceMeters, time: clock(), date: observation.observedAt) { persist(value) }
                trackers[id] = tracker
                if tracker.active != nil { activePeople.insert(id) } else { activePeople.remove(id) }
            } else { finish(id) }
        }
    }
    func tick() {
        for id in Array(trackers.keys) {
            if let value = trackers[id]?.expire(at: clock()) { persist(value); activePeople.remove(id) }
        }
        retrySaves()
        // Never display a cache past its refresh interval while a request is slow or stalled.
        for (id, profile) in publicProfiles where Date().timeIntervalSince(profile.fetchedAt) >= 30 {
            publicProfiles[id] = nil; refreshProfile(id)
        }
    }
    func retrySaves() {
        for (id, value) in pendingSaves {
            do { try store.save(value, ownerID: ownerID); pendingSaves[id] = nil }
            catch { errorMessage = "履歴を保存できませんでした。再試行してください。" }
        }
    }
    private func persist(_ value: Encounter) {
        if let index = records.firstIndex(where: { $0.id == value.id }) { records[index] = value }
        else { records.append(value); records.sort { $0.startedAt > $1.startedAt } }
        pendingSaves[value.id] = value; retrySaves()
    }
    private func finish(_ id: UUID) {
        if let value = trackers[id]?.stop() { persist(value) }
        trackers[id] = nil; activePeople.remove(id)
    }
    private func finishAll() { Array(trackers.keys).forEach(finish); retrySaves() }
    private func startTasks() {
        if eventTask == nil {
            let events = nearby.events
            eventTask = Task { [weak self] in
                for await event in events {
                    guard !Task.isCancelled else { return }
                    self?.receive(event)
                }
            }
        }
        if timerTask == nil {
            timerTask = Task { [weak self] in
                var ticks = 0
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    guard let self else { return }
                    tick(); ticks += 1
                    if ticks % 30 == 0 { refreshAll() }
                }
            }
        }
    }
    private func cancelTasks() {
        // Keep the single event consumer alive across suspension; AsyncStream is single-use.
        timerTask?.cancel(); timerTask = nil
        refreshRevision = UUID()
        refreshTasks.values.forEach { $0.cancel() }; refreshTasks = [:]
        if !isValid { eventTask?.cancel(); eventTask = nil }
    }
}
