import Foundation
import WatchConnectivity
import os

@MainActor final class WatchSyncCoordinator: NSObject, ObservableObject, WCSessionDelegate {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private let latestData = OSAllocatedUnfairLock<Data?>(initialState: nil)
    private(set) var latest: NavigationSnapshot?
    @Published private(set) var diagnostics = ConnectivityDiagnostics()
    var onStopRequest: (() -> Void)?

    func activate() {
        session?.delegate = self
        session?.activate()
        refreshSessionState()
    }
    private func refreshSessionState() {
        diagnostics.activationState = String(describing: session?.activationState ?? .notActivated)
        diagnostics.isReachable = session?.isReachable ?? false
        diagnostics.isPaired = session?.isPaired
        diagnostics.isWatchAppInstalled = session?.isWatchAppInstalled
    }
    func publish(_ snapshot: NavigationSnapshot) {
        latest = snapshot
        let envelope = NavigationMessageEnvelope(type: .navigationSnapshot, snapshot: snapshot)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        latestData.withLock { $0 = data }
        diagnostics.currentSessionID = snapshot.sessionID
        diagnostics.lastSentSequence = snapshot.sequence
        diagnostics.sentCount += 1
        refreshSessionState()
        #if DEBUG
        NavigationSnapshotTrace.record(
            "wc_state_\(session?.activationState.rawValue ?? -1)_paired_\(session?.isPaired == true)_installed_\(session?.isWatchAppInstalled == true)_reachable_\(session?.isReachable == true)",
            snapshot: snapshot
        )
        #endif
        // Context replaces pending older state. A reachable Watch also gets a low latency message.
        do {
            try session?.updateApplicationContext(["envelope": data])
            diagnostics.applicationContextAt = envelope.sentAt
            #if DEBUG
            NavigationSnapshotTrace.record("wc_context_accepted", snapshot: snapshot)
            #endif
        } catch {
            NavigationDebugLog.event("CONNECTIVITY", "context_failed", detail: String(describing: error))
            #if DEBUG
            NavigationSnapshotTrace.record("wc_context_error_\((error as NSError).code)", snapshot: snapshot)
            #endif
        }
        if session?.isReachable == true {
            session?.sendMessage(["envelope": data], replyHandler: nil, errorHandler: { @Sendable error in
                NavigationDebugLog.event("SEND", "message_failed", session: snapshot.sessionID,
                                         sequence: snapshot.sequence, detail: String(describing: error))
                #if DEBUG
                Task { @MainActor in
                    NavigationSnapshotTrace.record("wc_message_error_\((error as NSError).code)", snapshot: snapshot)
                }
                #endif
            })
        }
        NavigationDebugLog.event("SEND", "snapshot", session: snapshot.sessionID, sequence: snapshot.sequence,
                                 detail: "reachable=\(diagnostics.isReachable)")
    }
    #if DEBUG
    func sendDiagnostic(_ snapshot: NavigationSnapshot) -> Bool {
        guard session?.isReachable == true,
              let data = try? JSONEncoder().encode(NavigationMessageEnvelope(type: .navigationSnapshot, snapshot: snapshot)) else { return false }
        session?.sendMessage(["envelope": data], replyHandler: nil, errorHandler: { @Sendable error in
            NavigationDebugLog.event("SEND", "diagnostic_failed", session: snapshot.sessionID,
                                     sequence: snapshot.sequence, detail: String(describing: error))
        })
        NavigationDebugLog.event("SEND", "diagnostic_snapshot", session: snapshot.sessionID, sequence: snapshot.sequence)
        return true
    }
    #endif
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let data = message["envelope"] as? Data,
              let envelope = try? JSONDecoder().decode(NavigationMessageEnvelope.self, from: data),
              envelope.protocolVersion == 1 else { replyHandler([:]); return }
        switch envelope.type {
        case .requestCurrentState:
            Task { @MainActor in
                diagnostics.lastPullAt = Date()
                diagnostics.lastMessageAt = Date()
                NavigationDebugLog.event("PULL", "request_current_state")
            }
            replyHandler(latestData.withLock { $0 }.map { ["envelope": $0] } ?? [:])
        case .stopNavigation:
            replyHandler([:])
            // Never let a delayed Watch request stop a replacement navigation session.
            guard let requestedSession = envelope.sessionID else { return }
            Task { @MainActor in
                guard let data = latestData.withLock({ $0 }),
                      let latest = try? JSONDecoder().decode(NavigationMessageEnvelope.self, from: data),
                      latest.sessionID == requestedSession,
                      latest.snapshot?.status != .stopped else { return }
                onStopRequest?()
            }
        case .connectionPing:
            let response = try? JSONEncoder().encode(NavigationMessageEnvelope(type: .connectionPong))
            replyHandler(response.map { ["envelope": $0] } ?? [:])
        default:
            replyHandler([:])
        }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            refreshSessionState()
            NavigationDebugLog.event("CONNECTIVITY", "phone_session_activated", detail: "state=\(diagnostics.activationState)")
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            let wasReachable = diagnostics.isReachable
            refreshSessionState()
            if !wasReachable && diagnostics.isReachable { diagnostics.lastReconnectAt = Date() }
            NavigationDebugLog.event("CONNECTIVITY", "phone_reachability_changed", detail: "reachable=\(diagnostics.isReachable)")
        }
    }
    #if os(iOS)
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            let wasInstalled = diagnostics.isWatchAppInstalled == true
            refreshSessionState()
            if !wasInstalled, diagnostics.isWatchAppInstalled == true, let latest {
                // A pending context may have failed while the system still reported no Watch app.
                // Resend the current state as soon as companion registration recovers.
                publish(latest)
            }
        }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in refreshSessionState() }
    }
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
