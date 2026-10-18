import Foundation
import Observation

struct NearbyPerson: Identifiable {
    let profile: PublicProfile
    let contents: [ProfileContent]
    var id: UUID { profile.id }
}

/// Coordinates real observations, account-scoped history, and freshly authorized profiles.
@MainActor
@Observable
final class UWBConnectionService {
    private(set) var session: UWBMultiPeerSession
    private(set) var isParticipating = false
    private(set) var connectionError: String?
    private(set) var historyError: String?
    private(set) var records: [RecordedEncounter] = []
    private var authorizedPeople: [NearbyPerson] = []
    private var tracker = EncounterTracker()
    private var historyStore: EncounterHistoryStore?
    private var pendingRecords: [RecordedEncounter] = []
    private var lastObservation: [UUID: Date] = [:]
    private let clockOrigin = ContinuousClock.now
    private let personID: UUID
    private let repository: any ProfileRepository
    private var monitor: Task<Void, Never>?
    private var requests: [UUID: Task<Void, Never>] = [:]
    private var requestIDs: [UUID: UUID] = [:]
    private var refreshAt: [UUID: ContinuousClock.Instant] = [:]
    private var expiresAt: [UUID: ContinuousClock.Instant] = [:]
    private var automaticRetry = AutomaticPeerRetry()
    private var nextDiscoveryRestart: ContinuousClock.Instant?
    private var generation = UUID()
    private let presenceActivity = PresenceActivityController()

    var people: [NearbyPerson] {
        authorizedPeople.map { person in
            let total = records.filter { $0.personID == person.id }.reduce(0) { $0 + $1.duration }
            return NearbyPerson(profile: person.profile, contents: person.contents.filter {
                RevealRule.allows(isPublic: $0.isPublic, requiredSeconds: $0.unlockAfterSeconds, accumulatedSeconds: total)
            })
        }
    }

    init(personID: UUID, repository: any ProfileRepository) {
        self.personID = personID
        self.repository = repository
        session = UWBMultiPeerSession(personID: personID)
        do {
            let store = try EncounterHistoryStore(ownerID: personID)
            records = try store.load()
            historyStore = store
        } catch {
            historyError = "履歴を開けませんでした。" + error.localizedDescription
        }
    }

    func start() {
        guard !isParticipating else { return }
        session = UWBMultiPeerSession(personID: personID)
        connectionError = nil
        guard session.isSupported else {
            connectionError = "近くの人を見つけるにはUWB対応のiPhoneが必要です。"
            return
        }
        presenceActivity.onEnded = { [weak self] in
            self?.stop()
        }
        do { try presenceActivity.start() }
        catch {
            connectionError = "バックグラウンドでの参加にはライブアクティビティの許可が必要です。今回はBloomを開いている間だけ参加できます。"
        }
        generation = UUID()
        isParticipating = true
        session.startHosting()
        session.startBrowsing()
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    func connect(to peer: UWBPeer) {
        guard isParticipating else { return }
        do { try session.connect(to: peer) }
        catch { connectionError = error.localizedDescription }
    }

    private func refresh() {
        let now = ContinuousClock.now
        let elapsed = clockOrigin.duration(to: now).components
        let time = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        if nextDiscoveryRestart.map({ now >= $0 }) ?? true {
            // These are idempotent while running; restart after a transient discovery failure.
            session.startHosting()
            session.startBrowsing()
            nextDiscoveryRestart = now.advanced(by: .seconds(5))
        }
        let discoveredIDs = Set(session.discoveredPeers.map(\.id))
        automaticRetry.retainOnly(discoveredIDs)
        // Only one endpoint initiates automatically, avoiding simultaneous cross-connections.
        for peer in session.discoveredPeers where session.localName < peer.name {
            if automaticRetry.shouldAttempt(peerID: peer.id, localName: session.localName, remoteName: peer.name, time: time) {
                // connect(to:) reuses a live connection and replaces a failed one.
                connect(to: peer)
            }
        }
        let observations = session.observations.filter {
            guard let distance = $0.distanceMeters else { return false }
            let age = Date().timeIntervalSince($0.observedAt)
            return distance.isFinite && distance >= 0 && age >= 0 && age < 3 && $0.personID != personID
        }
        let visibleIDs = Set(observations.map(\.personID))
        authorizedPeople.removeAll { !visibleIDs.contains($0.id) || (expiresAt[$0.id].map { now >= $0 } ?? true) }
        for id in Array(requests.keys) where !visibleIDs.contains(id) {
            requests.removeValue(forKey: id)?.cancel()
            requestIDs[id] = nil
            refreshAt[id] = nil
            expiresAt[id] = nil
        }
        let authorizedIDs = Set(authorizedPeople.map(\.id))
        var completed = tracker.retainOnly(visibleIDs.intersection(authorizedIDs))
        lastObservation = lastObservation.filter { visibleIDs.contains($0.key) && authorizedIDs.contains($0.key) }
        for observation in observations where authorizedIDs.contains(observation.personID) {
            guard lastObservation[observation.personID] != observation.observedAt else { continue }
            lastObservation[observation.personID] = observation.observedAt
            completed += tracker.observe(personID: observation.personID, distance: observation.distanceMeters,
                                         time: time, date: observation.observedAt)
        }
        persist(completed)
        for id in visibleIDs where requests[id] == nil {
            if let next = refreshAt[id], now < next { continue }
            let generation = generation
            let requestID = UUID()
            requestIDs[id] = requestID
            requests[id] = Task { [weak self] in
                guard let self else { return }
                defer {
                    if self.requestIDs[id] == requestID {
                        self.requests[id] = nil
                        self.requestIDs[id] = nil
                    }
                }
                do {
                    let profile = try await repository.fetchProfile(personID: id)
                    let contents = try await repository.fetchContents(personID: id)
                    try Task.checkCancellation()
                    guard self.generation == generation, requestIDs[id] == requestID, isParticipating,
                          session.observations.contains(where: {
                              $0.personID == id && $0.distanceMeters != nil && Date().timeIntervalSince($0.observedAt) < 3
                          }) else { return }
                    authorizedPeople.removeAll { $0.id == id }
                    authorizedPeople.append(NearbyPerson(profile: profile, contents: contents.filter(\.isPublic)))
                    authorizedPeople.sort { $0.profile.displayName.localizedStandardCompare($1.profile.displayName) == .orderedAscending }
                    refreshAt[id] = ContinuousClock.now.advanced(by: .seconds(12))
                    expiresAt[id] = ContinuousClock.now.advanced(by: .seconds(15))
                } catch {
                    guard self.generation == generation, requestIDs[id] == requestID, !Task.isCancelled else { return }
                    authorizedPeople.removeAll { $0.id == id }
                    refreshAt[id] = ContinuousClock.now.advanced(by: .seconds(15))
                    if (error as? BackendError) != .notFound {
                        connectionError = "プロフィールを取得できませんでした。" + error.localizedDescription
                    }
                }
            }
        }
    }

    private func persist(_ completed: [RecordedEncounter]) {
        pendingRecords += completed
        guard !pendingRecords.isEmpty else { return }
        do {
            if historyStore == nil { historyStore = try EncounterHistoryStore(ownerID: personID) }
            guard let historyStore else { return }
            try historyStore.save(pendingRecords)
            records = try historyStore.load()
            pendingRecords.removeAll()
            historyError = nil
        } catch {
            historyError = "履歴を保存できませんでした。参加中は再試行します。" + error.localizedDescription
        }
    }

    func retryHistory() {
        do {
            if historyStore == nil { historyStore = try EncounterHistoryStore(ownerID: personID) }
            if pendingRecords.isEmpty {
                records = try historyStore?.load() ?? []
                historyError = nil
            } else { persist([]) }
        } catch { historyError = error.localizedDescription }
    }

    func renameEncounter(id: UUID, title: String) throws {
        if historyStore == nil { historyStore = try EncounterHistoryStore(ownerID: personID) }
        guard let historyStore else { throw CocoaError(.fileNoSuchFile) }
        try historyStore.rename(id: id, title: title)
        records = try historyStore.load()
    }

    func deleteHistory() {
        do {
            if historyStore == nil { historyStore = try EncounterHistoryStore(ownerID: personID) }
            try historyStore?.deleteAll()
            pendingRecords.removeAll()
            records.removeAll()
            tracker = EncounterTracker(rules: tracker.rules)
            lastObservation.removeAll()
            historyError = nil
        } catch { historyError = "履歴を削除できませんでした。" + error.localizedDescription }
    }

    func enteredBackground() {
        guard isParticipating else { return }
        if !presenceActivity.permitsBackgroundRanging {
            stop()
            connectionError = "ライブアクティビティを開始できなかったため参加を終了しました。Bloomを開いて再び参加してください。"
        }
        // With the activity active, retain the Network connections and every NISession.
        // NI delegate suspension events still remove stale measurements and resume the configuration.
    }

    func becameActive() {
        guard isParticipating else { return }
        guard presenceActivity.permitsBackgroundRanging else {
            // Foreground-only participation is allowed when activities are disabled.
            refresh()
            return
        }
        refresh()
    }

    func stop() {
        presenceActivity.stop()
        persist(tracker.finishAll())
        lastObservation.removeAll()
        generation = UUID()
        monitor?.cancel()
        monitor = nil
        requests.values.forEach { $0.cancel() }
        requests.removeAll()
        requestIDs.removeAll()
        refreshAt.removeAll()
        expiresAt.removeAll()
        automaticRetry = AutomaticPeerRetry()
        nextDiscoveryRestart = nil
        authorizedPeople.removeAll()
        session.stop()
        isParticipating = false
        connectionError = nil
    }
}
