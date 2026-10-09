import Foundation
import WatchConnectivity

@MainActor final class WatchConnectivityClient: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: NavigationSnapshot?
    @Published private(set) var health = ConnectionHealth()
    @Published private(set) var diagnostics = ConnectivityDiagnostics()
    @Published private(set) var isStale = false

    @Published private(set) var isStopping = false
    @Published private(set) var stopError: String?
    private var stopTimeout: Task<Void, Never>?

    private var gate = SnapshotGate()
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let staleThreshold: TimeInterval
    private var monitorTask: Task<Void, Never>?
    private var recoveryStartedAt: Date?
    #if DEBUG
    private let runState = PreviousRunStateStore()
    private let monitorID = UUID()
    #endif

    init(staleThreshold: TimeInterval = StaleStatePolicy.watchDefaultThreshold) {
        self.staleThreshold = staleThreshold
        super.init()
        #if DEBUG
        NavigationDebugLog.event("LIFECYCLE", "app_launch", detail: "run=\(NavigationDebugLog.runID) pid=\(ProcessInfo.processInfo.processIdentifier)")
        if runState.previousMayHaveTerminatedUnexpectedly, let previous = runState.previous {
            NavigationDebugLog.event("LIFECYCLE", "previous_run_may_have_terminated_unexpectedly",
                session: previous.lastSessionID, sequence: previous.lastNavigationSequence,
                detail: "previousRun=\(previous.runID) previousScene=\(previous.lastScene) clue_only_not_crash; system_reclamation_possible")
        }
        if runState.previousStateCorrupt {
            NavigationDebugLog.event("LIFECYCLE", "previous_run_state_unreadable")
        }
        NavigationDebugLog.event("LIFECYCLE", "monitor_task_started", detail: "id=\(monitorID)")
        #endif
        session?.delegate = self
        session?.activate()
        refreshSessionState()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { break }
                self.refreshHealth()
            }
        }
    }

    func sceneDidChange(_ name: String) {
        #if DEBUG
        let previous = runState.current.lastScene
        guard runState.scene(name) else { return }
        NavigationDebugLog.event("LIFECYCLE", "scene_\(name)", session: snapshot?.sessionID, sequence: snapshot?.sequence,
            detail: "observation=\(WatchExitObservation.classify(scene: name, reachable: diagnostics.isReachable, stale: isStale, missingCleanMarker: false).rawValue) terminationCause=unknown")
        if name == "active", previous == "background" {
            NavigationDebugLog.event("LIFECYCLE", "foreground", session: snapshot?.sessionID, sequence: snapshot?.sequence)
        }
        #endif
    }

    func resume() {
        #if DEBUG
        NavigationDebugLog.event("LIFECYCLE", "resume_requested", session: snapshot?.sessionID, sequence: snapshot?.sequence)
        #endif
        recoveryStartedAt = Date()
        if session?.activationState != .activated { session?.activate() }
        refreshSessionState()
        if let data = session?.receivedApplicationContext["envelope"] as? Data {
            receive(data, channel: "context", at: Date())
        }
        requestCurrentState()
    }

    private func refreshSessionState() {
        diagnostics.activationState = String(describing: session?.activationState ?? .notActivated)
        diagnostics.isReachable = session?.isReachable ?? false
        // isPaired and isWatchAppInstalled are only available on the iPhone side.
        diagnostics.isPaired = nil
        diagnostics.isWatchAppInstalled = nil
        #if DEBUG
        runState.connectivity("activation=\(diagnostics.activationState) reachable=\(diagnostics.isReachable)")
        WatchDebugJournal.context(received: diagnostics.lastReceivedSequence, applied: diagnostics.lastAppliedSequence,
            timestamp: snapshot?.timestamp, activation: diagnostics.activationState, reachable: diagnostics.isReachable)
        #endif
    }

    private func refreshHealth() {
        refreshSessionState()
        diagnostics.snapshotAge = snapshot.map { Date().timeIntervalSince($0.timestamp) }
        health.lastSnapshotAge = diagnostics.snapshotAge
        guard let snapshot, snapshot.status != .stopped, snapshot.status != .arrived else {
            if isStale {
                NavigationDebugLog.event("CONNECTIVITY", "stale_recovered", session: self.snapshot?.sessionID,
                    sequence: self.snapshot?.sequence, detail: "terminal_or_empty_state")
            }
            isStale = false
            health.quality = diagnostics.isReachable ? .good : .disconnected
            return
        }
        let stale = StaleStatePolicy(threshold: staleThreshold).isStale(snapshot, at: Date())
        if stale && !isStale {
            diagnostics.staleCount += 1
            NavigationDebugLog.event("CONNECTIVITY", "stale_entered", session: snapshot.sessionID,
                                     sequence: snapshot.sequence)
        }
        if isStale && !stale {
            NavigationDebugLog.event("CONNECTIVITY", "stale_recovered", session: snapshot.sessionID, sequence: snapshot.sequence)
        }
        isStale = stale
        // Reachability only describes live messaging, not the physical pairing.
        health.quality = diagnostics.isReachable ? (stale ? .degraded : .good) : .degraded
        if stale && diagnostics.isReachable,
           Date().timeIntervalSince(diagnostics.lastPullAt ?? .distantPast) >= 5 {
            requestCurrentState()
        }
    }

    func stopNavigation() {
        guard !isStopping, let snapshot, snapshot.status != .stopped, snapshot.status != .arrived else { return }
        guard let session, session.activationState == .activated, session.isReachable else {
            stopError = "无法连接 iPhone，请在手机上停止导航。"
            return
        }
        guard let data = try? JSONEncoder().encode(NavigationMessageEnvelope(type: .stopNavigation, snapshot: snapshot)) else { return }
        isStopping = true; stopError = nil
        stopTimeout?.cancel()
        stopTimeout = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, isStopping else { return }
            isStopping = false
            stopError = "尚未收到结束状态，请检查 iPhone。"
        }
        session.sendMessage(["envelope": data], replyHandler: { @Sendable [weak self] _ in
            self?.handleStopReply()
        }, errorHandler: { @Sendable [weak self] _ in
            Task { @MainActor in
                self?.stopTimeout?.cancel()
                self?.isStopping = false
                self?.stopError = "停止请求未送达，请在 iPhone 上停止导航。"
            }
        })
    }

    private nonisolated func handleStopReply() {
        Task { @MainActor in requestCurrentState() }
    }

    func requestCurrentState() {
        guard let session, session.isReachable,
              let data = try? JSONEncoder().encode(NavigationMessageEnvelope(type: .requestCurrentState)) else { return }
        diagnostics.lastPullAt = Date()
        NavigationDebugLog.event("PULL", "request_current_state")
        session.sendMessage(["envelope": data], replyHandler: { @Sendable [weak self] response in
            self?.handleCurrentStateReply(response)
        }, errorHandler: { @Sendable error in
            NavigationDebugLog.event("PULL", "request_failed", detail: String(describing: error))
        })
    }

    private nonisolated func handleCurrentStateReply(_ response: [String: Any]) {
        guard let data = response["envelope"] as? Data else { return }
        let receivedAt = Date()
        Task { @MainActor in receive(data, channel: "pull", at: receivedAt) }
    }

    private func receive(_ data: Data, channel: String, at receivedAt: Date) {
        guard let envelope = try? JSONDecoder().decode(NavigationMessageEnvelope.self, from: data),
              envelope.protocolVersion == 1, envelope.type == .navigationSnapshot,
              let candidate = envelope.snapshot,
              candidate.sessionID == envelope.sessionID, candidate.sequence == envelope.sequence else {
            NavigationDebugLog.event("DROP", "invalid_envelope")
            return
        }
        #if DEBUG
        runState.connectivity("activation=\(diagnostics.activationState) reachable=\(diagnostics.isReachable)", at: receivedAt, received: true)
        #endif
        diagnostics.receivedCount += 1
        diagnostics.lastReceivedSequence = candidate.sequence
        diagnostics.lastMessageAt = receivedAt
        if channel == "context" { diagnostics.applicationContextAt = envelope.sentAt }
        diagnostics.receiveLatency.record(receivedAt.timeIntervalSince(envelope.sentAt))
        NavigationDebugLog.event("RECEIVE", "snapshot", session: candidate.sessionID,
                                 sequence: candidate.sequence, detail: "channel=\(channel)")
        let previousSession = gate.activeSessionID
        let previousSequence = gate.lastAppliedSequence
        let decision = gate.evaluate(candidate)
        switch decision {
        case .accepted:
            if previousSession != candidate.sessionID {
                diagnostics.lastSessionChangeAt = receivedAt
                NavigationDebugLog.event("RECOVERY", "latest_snapshot_applied", session: candidate.sessionID,
                                         sequence: candidate.sequence)
            } else if let previousSequence, candidate.sequence > previousSequence,
                      candidate.sequence - previousSequence > 1 {
                diagnostics.sequenceGaps += Int(candidate.sequence - previousSequence - 1)
            }
            if let recoveryStartedAt {
                diagnostics.lastRecoveryDuration = receivedAt.timeIntervalSince(recoveryStartedAt)
                self.recoveryStartedAt = nil
            }
            #if DEBUG
            runState.applied(session: candidate.sessionID, sequence: candidate.sequence)
            #endif
            snapshot = candidate
            if candidate.status == .stopped || candidate.status == .arrived {
                stopTimeout?.cancel(); stopTimeout = nil
                isStopping = false; stopError = nil
            }
            diagnostics.currentSessionID = candidate.sessionID
            diagnostics.lastAppliedSequence = candidate.sequence
            diagnostics.appliedCount += 1
            diagnostics.snapshotAge = receivedAt.timeIntervalSince(candidate.timestamp)
            health.lastMessageAt = receivedAt
            health.lastSnapshotAge = diagnostics.snapshotAge
            refreshHealth()
        case .duplicate:
            diagnostics.duplicateCount += 1
            NavigationDebugLog.event("DROP", "duplicate", session: candidate.sessionID,
                                     sequence: candidate.sequence, detail: "current=\(previousSequence.map(String.init) ?? "-")")
        case .outOfOrder:
            diagnostics.outOfOrderCount += 1
            NavigationDebugLog.event("DROP", "out_of_order", session: candidate.sessionID,
                                     sequence: candidate.sequence, detail: "current=\(previousSequence.map(String.init) ?? "-")")
        case .oldSession:
            diagnostics.oldSessionCount += 1
            NavigationDebugLog.event("DROP", "old_session", session: candidate.sessionID,
                                     sequence: candidate.sequence, detail: "current=\(previousSession?.uuidString ?? "-")")
        case .unsupportedVersion:
            NavigationDebugLog.event("DROP", "unsupported_version")
        }
    }

    /// Called by the SwiftUI page when the accepted state reaches the view update cycle.
    func markUIApplied(_ value: NavigationSnapshot) {
        guard snapshot?.sessionID == value.sessionID, snapshot?.sequence == value.sequence else { return }
        diagnostics.applyLatency.record(Date().timeIntervalSince(value.timestamp))
        NavigationDebugLog.event("APPLY", "watch_ui", session: value.sessionID, sequence: value.sequence)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["envelope"] as? Data else { return }
        let receivedAt = Date()
        Task { @MainActor in receive(data, channel: "message", at: receivedAt) }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["envelope"] as? Data else { return }
        let receivedAt = Date()
        Task { @MainActor in receive(data, channel: "context", at: receivedAt) }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            refreshSessionState()
            NavigationDebugLog.event("CONNECTIVITY", "watch_session_activated",
                                     detail: "state=\(diagnostics.activationState)")
            resume()
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            let wasReachable = diagnostics.isReachable
            refreshSessionState()
            NavigationDebugLog.event("CONNECTIVITY", "reachability_changed", detail: "reachable=\(reachable)")
            if !wasReachable && reachable {
                diagnostics.lastReconnectAt = Date()
                recoveryStartedAt = Date()
                NavigationDebugLog.event("CONNECTIVITY", "watch_reconnected")
                requestCurrentState()
            } else if !reachable {
                NavigationDebugLog.event("CONNECTIVITY", "watch_unreachable")
            }
            refreshHealth()
        }
    }
}
