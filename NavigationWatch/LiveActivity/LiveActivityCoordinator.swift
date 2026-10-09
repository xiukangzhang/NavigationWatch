import Foundation
#if canImport(NavigationWatchCore)
import NavigationWatchCore
#endif

@MainActor public protocol NavigationActivityDriver: AnyObject {
    func start(session: UUID, state: NavigationActivityAttributes.ContentState, staleDate: Date) async throws -> String
    func update(id: String, state: NavigationActivityAttributes.ContentState, staleDate: Date) async
    func end(id: String, reason: String) async
    func endOrphans() async
}

/// A serialized consumer of Core snapshots, never a navigation state owner.
@MainActor public final class LiveActivityCoordinator {
    public struct Policy: Sendable {
        public var farDistanceStep = 50.0
        public var nearDistanceStep = 10.0
        public var nearDistance = 100.0
        public var farInterval = 5.0
        public var nearInterval = 2.0
        public var durationStep = 60.0
        public var etaStep = 60.0
        public var staleAfter = 15.0
        public var freshnessInterval = 10.0
        public init() {}
    }
    private let driver: any NavigationActivityDriver
    private let policy: Policy
    private let now: () -> Date
    private let log: (String, UUID?, String?) -> Void
    private var gate = SnapshotGate()
    private var accepting = false
    private var terminalSessions: Set<UUID> = []
    private var id: String?
    private var session: UUID?
    private var last: NavigationActivityAttributes.ContentState?
    private var lastWrite: Date = .distantPast
    private var pending: NavigationSnapshot?
    private var timer: Task<Void, Never>?
    private var queue: [Event] = []
    private var worker: Task<Void, Never>?
    private enum Event {
        case snapshot(NavigationSnapshot)
        case barrierUpdate(NavigationSnapshot)
        case end(String, CheckedContinuation<Void, Never>)
        case barrier(CheckedContinuation<Void, Never>)
    }
    public init(driver: any NavigationActivityDriver, policy: Policy = Policy(),
                now: @escaping () -> Date = Date.init,
                log: @escaping (String, UUID?, String?) -> Void = { _, _, _ in }) {
        self.driver = driver; self.policy = policy; self.now = now; self.log = log
    }
    /// Only enable after provider.startNavigation succeeds, not after route search.
    public func enable() { accepting = true }
    public func submit(_ snapshot: NavigationSnapshot) {
        guard accepting else { return }
        queue.append(.snapshot(snapshot)); pump()
    }
    public func end(reason: String) async {
        accepting = false
        if let session = session ?? gate.activeSessionID { terminalSessions.insert(session) }
        timer?.cancel(); timer = nil; pending = nil
        queue.removeAll { switch $0 { case .snapshot, .barrierUpdate: return true; default: return false } }
        await withCheckedContinuation { queue.append(.end(reason, $0)); pump() }
    }
    public func flush() async {
        await withCheckedContinuation { queue.append(.barrier($0)); pump() }
    }
    private func pump() {
        guard worker == nil else { return }
        worker = Task {
            while !queue.isEmpty {
                switch queue.removeFirst() {
                case .snapshot(let snapshot): await consume(snapshot)
                case .barrierUpdate(let snapshot):
                    if accepting && gate.activeSessionID == snapshot.sessionID && gate.lastAppliedSequence == snapshot.sequence {
                        await consume(snapshot, admitted: true)
                    }
                case .end(let reason, let continuation):
                    await finish(reason); await driver.endOrphans(); continuation.resume()
                case .barrier(let continuation): continuation.resume()
                }
            }
            worker = nil
        }
    }
    private func consume(_ snapshot: NavigationSnapshot, admitted: Bool = false) async {
        guard !terminalSessions.contains(snapshot.sessionID) else { return }
        guard admitted || gate.accept(snapshot) else { log("drop_session_or_sequence", snapshot.sessionID, id); return }
        if session != nil && session != snapshot.sessionID { await finish("session_replaced") }
        if [.stopped, .arrived, .idle].contains(snapshot.status) {
            terminalSessions.insert(snapshot.sessionID)
            await finish(snapshot.status.rawValue); return
        }
        let state = NavigationActivityStateMapper.map(snapshot)
        let staleDate = state.timestamp.addingTimeInterval(policy.staleAfter)
        guard id != nil || snapshot.status == .navigating else { return }
        if id == nil {
            guard staleDate > now() else { log("skip_stale_start", snapshot.sessionID, nil); return }
            await driver.endOrphans()
            do {
                id = try await driver.start(session: snapshot.sessionID, state: state, staleDate: staleDate)
                session = snapshot.sessionID; last = state; lastWrite = now()
                log("started", session, id)
            } catch { log("ActivityKit_error_\(String(describing: error))", snapshot.sessionID, nil) }
            return
        }
        log("update_requested", session, id)
        guard let last, let id else { return }
        let urgent = state.maneuver != last.maneuver || state.nextRoad != last.nextRoad ||
            state.navigationState != last.navigationState
        let age = now().timeIntervalSince(lastWrite)
        let near = (state.distanceToManeuver ?? .infinity) <= policy.nearDistance
        let distanceStep = near ? policy.nearDistanceStep : policy.farDistanceStep
        let changed = urgent || bucket(state.distanceToManeuver, distanceStep) != bucket(last.distanceToManeuver, distanceStep) ||
            bucket(state.remainingDistance, 100) != bucket(last.remainingDistance, 100) ||
            difference(state.remainingDuration, last.remainingDuration) >= policy.durationStep ||
            difference(state.eta?.timeIntervalSince1970, last.eta?.timeIntervalSince1970) >= policy.etaStep ||
            state.trafficStatus != last.trafficStatus || age >= policy.freshnessInterval ||
            (last.timestamp.addingTimeInterval(policy.staleAfter) <= now() && staleDate > now())
        guard changed else {
            // Clear an older throttled value if the latest snapshot returns to the published state.
            pending = nil; timer?.cancel(); timer = nil
            log("skipped_dedup", session, id); return
        }
        let interval = near ? policy.nearInterval : policy.farInterval
        guard urgent || age >= interval else {
            pending = snapshot
            if timer == nil {
                timer = Task {
                    try? await Task.sleep(for: .seconds(max(0.01, interval - age)))
                    guard !Task.isCancelled else { return }
                    self.timer = nil
                    guard self.accepting, let pending = self.pending else { return }
                    self.pending = nil
                    // The sequence was already admitted; route delayed work through the same worker.
                    self.queue.append(.barrierUpdate(pending))
                    self.pump()
                }
            }
            log("skipped_throttle", session, id); return
        }
        pending = nil; timer?.cancel(); timer = nil
        await driver.update(id: id, state: state, staleDate: staleDate)
        self.last = state; lastWrite = now(); log("updated", session, id)
    }
    private func finish(_ reason: String) async {
        timer?.cancel(); timer = nil; pending = nil
        if let id { await driver.end(id: id, reason: reason); log("ended_\(reason)", session, id) }
        id = nil; session = nil; last = nil; lastWrite = .distantPast
    }
    private func bucket(_ value: Double?, _ step: Double) -> Int? {
        value.map { Int(min(Double(Int.max / 2), floor($0 / max(1, step)))) }
    }
    private func difference(_ a: Double?, _ b: Double?) -> Double {
        switch (a, b) { case (nil, nil): 0; case (.some(let a), .some(let b)): abs(a - b); default: .infinity }
    }
}
