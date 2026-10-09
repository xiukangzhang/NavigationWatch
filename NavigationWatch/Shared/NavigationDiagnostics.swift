import Foundation
#if DEBUG
import os
#if os(watchOS)
import Synchronization
#endif
#endif

public struct LatencySummary: Sendable, Equatable {
    public let count: Int
    public let median: TimeInterval?
    public let p95: TimeInterval?
    public let p99: TimeInterval?
    public let max: TimeInterval?
}

public struct LatencySamples: Sendable {
    private var values: [TimeInterval] = []
    public init() {}
    public mutating func record(_ value: TimeInterval) {
        guard value >= 0, value.isFinite else { return }
        if values.count == 10_000 { values.removeFirst() }
        values.append(value)
    }
    public var summary: LatencySummary {
        let sorted = values.sorted()
        func percentile(_ fraction: Double) -> TimeInterval? {
            guard !sorted.isEmpty else { return nil }
            let index = Int((Double(sorted.count - 1) * fraction).rounded(.up))
            return sorted[index]
        }
        return LatencySummary(count: sorted.count, median: percentile(0.5), p95: percentile(0.95),
            p99: percentile(0.99), max: sorted.last)
    }
}

public struct StaleStatePolicy: Sendable {
    // Real SDK callbacks can be about one minute apart while stationary.
    // Keep a bounded source-age limit; receiving a duplicate never refreshes it.
    public static let watchDefaultThreshold: TimeInterval = NavigationFreshnessPolicy.standard.watchSnapshotStaleAfter
    public let threshold: TimeInterval
    public init(threshold: TimeInterval) { self.threshold = max(0, threshold) }
    public func isStale(_ snapshot: NavigationSnapshot?, at now: Date) -> Bool {
        guard let snapshot, snapshot.status != .stopped, snapshot.status != .arrived else { return false }
        return now.timeIntervalSince(snapshot.timestamp) > threshold
    }
}

public struct ConnectivityDiagnostics: Sendable {
    public var currentSessionID: UUID?
    public var lastSentSequence: UInt64?
    public var lastReceivedSequence: UInt64?
    public var lastAppliedSequence: UInt64?
    public var lastMessageAt: Date?
    public var snapshotAge: TimeInterval?
    public var activationState = "notActivated"
    public var isReachable = false
    public var isPaired: Bool?
    public var isWatchAppInstalled: Bool?
    public var applicationContextAt: Date?
    public var lastPullAt: Date?
    public var lastReconnectAt: Date?
    public var lastSessionChangeAt: Date?
    public var lastRecoveryDuration: TimeInterval?
    public var receivedCount = 0
    public var sentCount = 0
    public var appliedCount = 0
    public var duplicateCount = 0
    public var outOfOrderCount = 0
    public var oldSessionCount = 0
    public var staleCount = 0
    public var sequenceGaps = 0
    public var receiveLatency = LatencySamples()
    public var applyLatency = LatencySamples()
    public init() {}
}

public enum NavigationDebugLog {
    #if DEBUG
    public static let runID = UUID()
    #endif
    public static func event(_ category: String, _ name: String, session: UUID? = nil,
                             sequence: UInt64? = nil, detail: String = "") {
        #if DEBUG
        let suffix = "session=\(session?.uuidString ?? "-") sequence=\(sequence.map(String.init) ?? "-") \(detail)"
        #if os(watchOS)
        WatchDebugJournal.append(category: category, name: name, session: session, sequence: sequence, detail: detail)
        #endif
        Logger(subsystem: "dev.local.NavigationWatch", category: "Navigation").debug("[\(category, privacy: .public)] \(name, privacy: .public) \(suffix, privacy: .public)")
        #endif
    }
}


#if DEBUG
/// A missing marker is a clue only: watchOS may reclaim suspended processes without notice.
public struct PreviousRunState: Codable, Sendable, Equatable {
    public var runID: UUID
    public var processID: Int32
    public var lastLaunchAt: Date
    public var lastActiveAt: Date?
    public var lastBackgroundAt: Date?
    public var lastNavigationSequence: UInt64?
    public var lastSessionID: UUID?
    public var lastScene = "launch"
    public var cleanExitMarker = false
    public var lastConnectivityState: String?
    public var lastReceivedAt: Date?
    public var lastAppliedAt: Date?
}

@MainActor public final class PreviousRunStateStore {
    private let defaults: UserDefaults
    private let key: String
    public let previous: PreviousRunState?
    public let previousStateCorrupt: Bool
    public private(set) var current: PreviousRunState
    public var previousMayHaveTerminatedUnexpectedly: Bool { previous?.cleanExitMarker == false }

    public init(defaults: UserDefaults = .standard, key: String = "watch.previousRunState",
                now: Date = Date(), runID: UUID = NavigationDebugLog.runID,
                processID: Int32 = ProcessInfo.processInfo.processIdentifier) {
        self.defaults = defaults
        self.key = key
        let data = defaults.data(forKey: key)
        previous = data.flatMap { try? JSONDecoder().decode(PreviousRunState.self, from: $0) }
        previousStateCorrupt = data != nil && previous == nil
        current = PreviousRunState(runID: runID, processID: processID, lastLaunchAt: now)
        persist()
    }
    @discardableResult public func scene(_ name: String, at date: Date = Date()) -> Bool {
        guard name != current.lastScene else { return false }
        current.lastScene = name
        if name == "active" { current.lastActiveAt = date }
        if name == "background" { current.lastBackgroundAt = date }
        // Background is not proof of a clean process exit; never manufacture that marker.
        persist()
        return true
    }
    public func connectivity(_ state: String, at date: Date = Date(), received: Bool = false) {
        if received { current.lastReceivedAt = date }
        guard received || current.lastConnectivityState != state else { return }
        current.lastConnectivityState = state
        persist()
    }
    public func applied(session: UUID, sequence: UInt64, at date: Date = Date()) {
        current.lastAppliedAt = date
        current.lastSessionID = session
        current.lastNavigationSequence = sequence
        persist()
    }
    private func persist() {
        guard let data = try? JSONEncoder().encode(current) else { return }
        defaults.set(data, forKey: key)
    }
}
#endif

#if DEBUG && os(watchOS)
/// Extends the existing logger, not a second crash-reporting service.
/// JSONL is bounded, Debug only, and contains no coordinates, road names or key.
private struct WatchJournalState: Sendable {
    var file: FileHandle?
    var bytes: UInt64 = 0
    var received: UInt64?
    var applied: UInt64?
    var sourceTimestamp: Date?
    var activation = "notActivated"
    var reachable = false
}
public enum WatchDebugJournal {
    private static let sink = Mutex(WatchJournalState())
    private static let maximumBytes: UInt64 = 1_048_576
    private static var url: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("watch-diagnostics.jsonl")
    }
    public static func context(received: UInt64?, applied: UInt64?, timestamp: Date?,
                               activation: String, reachable: Bool) {
        sink.withLock {
            $0.received = received; $0.applied = applied; $0.sourceTimestamp = timestamp
            $0.activation = activation; $0.reachable = reachable
        }
    }
    fileprivate static func append(category: String, name: String, session: UUID?,
                                   sequence: UInt64?, detail: String) {
        sink.withLock { state in
            let now = Date()
            var row: [String: Any] = ["recordedAt": ISO8601DateFormatter().string(from: now),
                "runID": NavigationDebugLog.runID.uuidString,
                "processID": ProcessInfo.processInfo.processIdentifier,
                "category": category, "event": name, "detail": detail,
                "activation": state.activation, "reachable": state.reachable,
                "isMainThread": Thread.isMainThread]
            row["sessionID"] = session?.uuidString
            row["sequence"] = sequence
            row["lastReceivedSequence"] = state.received
            row["lastAppliedSequence"] = state.applied
            row["snapshotAge"] = state.sourceTimestamp.map { now.timeIntervalSince($0) }
            guard let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
            do {
                if state.file == nil {
                    if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
                    state.file = try FileHandle(forWritingTo: url)
                    state.bytes = try state.file?.seekToEnd() ?? 0
                }
                if state.bytes + UInt64(data.count + 1) > maximumBytes {
                    try state.file?.close(); state.file = nil
                    let previous = url.deletingLastPathComponent().appendingPathComponent("watch-diagnostics.previous.jsonl")
                    if FileManager.default.fileExists(atPath: previous.path) { try FileManager.default.removeItem(at: previous) }
                    try FileManager.default.moveItem(at: url, to: previous)
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                    state.file = try FileHandle(forWritingTo: url); state.bytes = 0
                }
                try state.file?.write(contentsOf: data + Data([0x0A]))
                state.bytes += UInt64(data.count + 1)
            } catch {
                // Diagnostics must never terminate navigation on an I/O failure.
                try? state.file?.close(); state.file = nil
            }
        }
    }
}
#endif

/// Project policy, not an SDK guarantee. Different source clocks have explicit budgets.
public struct NavigationFreshnessPolicy: Sendable {
    public static let standard = NavigationFreshnessPolicy()
    public var delayedAfter: TimeInterval = 5
    public var locationStaleAfter: TimeInterval = 15
    public var watchSnapshotStaleAfter: TimeInterval = 90
    public init() {}
    public func classify(source: Date?, available: Bool, at now: Date) -> NavigationFreshness {
        guard available, let source else { return .unavailable }
        let age = now.timeIntervalSince(source)
        guard age >= -2 else { return .unavailable }
        if age > locationStaleAfter { return .stale }
        return age > delayedAfter ? .delayed : .fresh
    }
}
public enum NavigationFreshness: String, Codable, Sendable { case fresh, delayed, stale, unavailable }
#if DEBUG
public enum LocationInterruptionReason: String, Codable, Sendable {
    case none, staleLocation, noRawLocationCallback, noNavigationCallback, poorAccuracy
    case authorizationRestricted, providerInactive, appLifecycleTransition, unknown
}
/// lastRawLocationAt means the observable AMap location callback, not its hidden CLLocation input.
public struct LocationPipelineTimeline: Codable, Sendable {
    public var lastRawLocationAt: Date?
    public var lastAMapNavigationCallbackAt: Date?
    public var lastSnapshotGeneratedAt: Date?
    public var lastSnapshotAppliedAt: Date?
    public var lastCoreConsumedAt: Date?
    public var coreConsumedSequence: UInt64?
    public var coreConsumedSessionID: UUID?
    public var upstreamProbeRequestedAt: Date?
    public var upstreamProbeCompletedAt: Date?
    public var upstreamResponseAt: Date?
    public var upstreamSourceAt: Date?
    public var upstreamAccuracy: Double?
    public var upstreamProbeErrorCode: Int?
    public var sourceLocationAt: Date?
    public var currentHorizontalAccuracy: Double?
    public var gpsSignal: GPSSignalQuality?
    public var isNetworkPosition: Bool?
    public var isMatchedToRoute: Bool?
    public var callbackQueueDelay: TimeInterval?
    public var lastSourceAdvancedAt: Date?
    public var sourceProgress: String?
    public var sdkPausesLocationAutomatically: Bool?
    public var sdkAllowsBackgroundLocation: Bool?
    public var navigationProviderState = "idle"
    public var appLifecycleState = "unknown"
    public var lifecycleChangedAt: Date?
    public var locationAuthorization = "unknown"
    public var sessionID: UUID?
    public var sequence: UInt64?
    public var sampleAvailable = false
    public init() {}
    /// Diagnostic correlation only. A new callback never makes an old source timestamp fresh.
    public mutating func observeLocation(source: Date?, available: Bool, receivedAt: Date, appliedAt: Date) {
        let previous = sourceLocationAt
        sourceProgress = !available || source == nil ? "unavailable" : source! > receivedAt.addingTimeInterval(2) ? "future"
            : previous == nil ? "first" : source! > previous! ? "advanced" : source! == previous! ? "repeated" : "regressed"
        if sourceProgress == "first" || sourceProgress == "advanced" { lastSourceAdvancedAt = receivedAt }
        lastRawLocationAt = receivedAt; sourceLocationAt = source; sampleAvailable = available
        callbackQueueDelay = max(0, appliedAt.timeIntervalSince(receivedAt))
    }
    public func diagnosis(at now: Date, policy: NavigationFreshnessPolicy = .standard) -> (NavigationFreshness, LocationInterruptionReason) {
        let freshness = policy.classify(source: sourceLocationAt, available: sampleAvailable, at: now)
        if locationAuthorization == "denied" || locationAuthorization == "restricted" { return (.unavailable, .authorizationRestricted) }
        if navigationProviderState != "navigating" { return (.unavailable, .providerInactive) }
        guard sampleAvailable, sourceLocationAt != nil else { return (.unavailable, .unknown) }
        if freshness == .unavailable { return (.unavailable, .unknown) }
        if let raw = lastRawLocationAt, now.timeIntervalSince(raw) > policy.locationStaleAfter { return (freshness, .noRawLocationCallback) }
        if freshness == .stale { return (.stale, .staleLocation) }
        if let navigation = lastAMapNavigationCallbackAt, now.timeIntervalSince(navigation) > policy.locationStaleAfter { return (freshness, .noNavigationCallback) }
        if let accuracy = currentHorizontalAccuracy, accuracy.isFinite, accuracy > 50 { return (freshness, .poorAccuracy) }
        return (freshness, .none)
    }
}
/// Observed boundary, not an assertion about the SDK's hidden CLLocationManager.
public enum LocationPipelineBoundary: String, Sendable {
    case flowing, coreConsumptionPending, upstreamProbePending, upstreamProbeFailed
    case upstreamSampleStale, upstreamUnobserved, amapCallbackGap, amapSourceStale
}
public extension LocationPipelineTimeline {
    func boundary(at now: Date) -> LocationPipelineBoundary {
        if lastSnapshotGeneratedAt != nil, let sequence,
           coreConsumedSessionID != sessionID || sequence > (coreConsumedSequence ?? 0),
           lastCoreConsumedAt == nil || now.timeIntervalSince(lastCoreConsumedAt!) > 2 {
            return .coreConsumptionPending
        }
        let sdkFreshness = NavigationFreshnessPolicy.standard.classify(source: sourceLocationAt, available: sampleAvailable, at: now)
        guard sdkFreshness == .stale || sdkFreshness == .unavailable else { return .flowing }
        guard let requested = upstreamProbeRequestedAt else { return .upstreamUnobserved }
        guard let completed = upstreamProbeCompletedAt, completed >= requested else { return .upstreamProbePending }
        // A one-shot sample is only a point-in-time comparison, never continuous upstream evidence.
        guard now.timeIntervalSince(completed) <= 15 else { return .upstreamUnobserved }
        if upstreamProbeErrorCode != nil { return .upstreamProbeFailed }
        guard let response = upstreamResponseAt, response >= requested, let source = upstreamSourceAt,
              let accuracy = upstreamAccuracy, accuracy.isFinite, accuracy >= 0 else { return .upstreamUnobserved }
        guard (0...15).contains(now.timeIntervalSince(source)) else { return .upstreamSampleStale }
        if lastRawLocationAt == nil || now.timeIntervalSince(lastRawLocationAt!) > 15 { return .amapCallbackGap }
        return .amapSourceStale
    }
}
/// At most two one-shot comparisons in the first 120 seconds; no continuous extra location service.
public struct LocationDiagnosticProbeBudget: Sendable {
    public private(set) var startedAt: Date?
    public private(set) var lastRequestAt: Date?
    public private(set) var requests = 0
    public init() {}
    public mutating func start(at now: Date) { startedAt = now; lastRequestAt = nil; requests = 0 }
    public mutating func take(at now: Date, stale: Bool, pending: Bool) -> Bool {
        guard let startedAt, (0..<120).contains(now.timeIntervalSince(startedAt)), stale, !pending, requests < 2,
              lastRequestAt == nil || now.timeIntervalSince(lastRequestAt!) >= 60 else { return false }
        lastRequestAt = now; requests += 1; return true
    }
    public mutating func stop() { startedAt = nil }
}
public enum WatchExitObservation: String, Sendable {
    case normalBackground, userExit, processReclaimed, connectivityLost, staleNavigation, possibleUnexpectedTermination, unknown
    public static func classify(scene: String?, reachable: Bool?, stale: Bool, missingCleanMarker: Bool) -> Self {
        // No public scene callback establishes user exit, reclamation, or a crash.
        if missingCleanMarker { return .possibleUnexpectedTermination }
        if scene == "background" { return .normalBackground }
        if stale { return .staleNavigation }
        if reachable == false { return .connectivityLost }
        return .unknown
    }
}
#endif

#if DEBUG
/// DEBUG measurements never enter the wire snapshot or control SDK recovery.
public enum PipelineStallClassification: String, Codable, Sendable {
    case none, coreLocationStalled, amapRawCallbackStalled, providerForwardingStalled
    case snapshotGenerationStalled, coreConsumptionStalled, freshnessClassificationMismatch, unknown
}
public enum PipelineLayer: String, Codable, Sendable, CaseIterable {
    case coreLocation, amapLocation, amapNavigation, amapStatus
    case providerLocation, providerNavigation, providerSnapshot, snapshot, coreConsumed
}
public struct PipelineCheckpoint: Codable, Sendable {
    public var at: Date?
    public var tick: Double?
    public var count = 0
    public init() {}
    public func age(at tick: Double) -> Double? { self.tick.map { max(0, tick - $0) } }
}
public struct NavigationPipelineDiagnosticSnapshot: Codable, Sendable {
    public var sessionID: UUID?
    public var sequence: UInt64?
    public var coreConsumedSessionID: UUID?
    public var coreConsumedSequence: UInt64?
    public var recordedAt: Date
    public var elapsed: Double
    public var checkpoints: [String: PipelineCheckpoint]
    public var ages: [String: Double]
    public var classification: PipelineStallClassification
    public var sourceAge: Double?
    public var amapLocationSourceTimestamp: Date?
    public var amapHorizontalAccuracy: Double?
    public var sdkBackgroundLocation: Bool?
    public var sdkAutomaticPause: Bool?
    public var screenLockObservation = "unknown: no screen lock API observed"
    public var coreLocationSourceTimestamp: Date?
    public var coreLocationSourceAge: Double?
    public var horizontalAccuracy: Double?
    public var authorization: String
    public var lifecycle: String
    public var navigationState: String
    public var sdkState: String
    public var routeActive: Bool
    public var observerActive: Bool
    public var watchConnectivity: String
    public var gpsState: String
    public var firstRecoveredLayer: String?
    public var staleDuration: Double?
    public var sameSession: Bool?
    public var sequenceContinued: Bool?
    public var sessionRebuilt: Bool?
}
public struct NavigationPipelineMeasurements: Sendable {
    public var checkpoints: [PipelineLayer: PipelineCheckpoint] = [:]
    public var sessionID: UUID?
    public var sequence: UInt64?
    public var observerActive = false
    public var routeActive = false
    public var navigationActive = false
    public var sdkState = "unknown"
    public var rawNavigationHasData = true
    public var amapSourceTimestamp: Date?
    public var amapAccuracy: Double?
    public var sdkBackgroundLocation: Bool?
    public var sdkAutomaticPause: Bool?
    public var coreConsumedSession: UUID?
    public var coreConsumedSequence: UInt64?
    public var sourceAgeAtCallback: Double?
    public var coreSourceAgeAtCallback: Double?
    public var coreSourceTimestamp: Date?
    public var coreAccuracy: Double?
    public var startedTick: Double = 0
    public var providerStarts = 0
    private var previousFreshness: NavigationFreshness?
    private var stalledAt: Double?
    private var stalledSession: UUID?
    private var stalledSequence: UInt64?
    private var stalledStarts: Int?
    private var countsAtStall: [PipelineLayer: Int] = [:]
    private var firstRecoveredLayer: PipelineLayer?
    public init() {}
    public mutating func observe(_ layer: PipelineLayer, tick: Double, date: Date) {
        var point = checkpoints[layer] ?? PipelineCheckpoint()
        // Callback entry can race across SDK queues. Do not move the clock backwards.
        if point.tick == nil || tick >= point.tick! { point.tick = tick; point.at = date }
        point.count += 1; checkpoints[layer] = point
        if stalledAt != nil, firstRecoveredLayer == nil,
           [.coreLocation, .amapLocation, .amapNavigation, .providerLocation, .providerNavigation, .snapshot].contains(layer),
           point.count > (countsAtStall[layer] ?? 0), (point.count - (countsAtStall[layer] ?? 0)) == 1 {
            // Report first resumed layer only if it was actually silent at stall entry.
            if let last = stallTicks[layer], let start = stalledAt, start - last > 5 { firstRecoveredLayer = layer }
        }
    }
    private var stallTicks: [PipelineLayer: Double] = [:]
    public func age(_ layer: PipelineLayer, at tick: Double) -> Double? { checkpoints[layer]?.age(at: tick) }
    public func sourceAge(at tick: Double) -> Double? {
        guard let initial = sourceAgeAtCallback, let elapsed = age(.amapLocation, at: tick) else { return nil }
        return initial + elapsed
    }
    public func coreSourceAge(at tick: Double) -> Double? {
        guard let initial = coreSourceAgeAtCallback, let elapsed = age(.coreLocation, at: tick) else { return nil }
        return initial + elapsed
    }
    public func classify(at tick: Double, freshness: NavigationFreshness) -> PipelineStallClassification {
        guard navigationActive, routeActive, tick - startedTick > 5 else { return .unknown }
        func fresh(_ layer: PipelineLayer) -> Bool { age(layer, at: tick).map { $0 <= 5 } ?? false }
        func stalled(_ layer: PipelineLayer) -> Bool { age(layer, at: tick).map { $0 > 15 } ?? false }
        func pending(_ input: PipelineLayer, _ output: PipelineLayer) -> Bool {
            fresh(input) && (checkpoints[input]?.count ?? 0) > (checkpoints[output]?.count ?? 0)
                && (age(output, at: tick) ?? (tick - startedTick)) > 2
        }
        if pending(.amapLocation, .providerLocation) || (rawNavigationHasData && pending(.amapNavigation, .providerNavigation)) || pending(.snapshot, .providerSnapshot) { return .providerForwardingStalled }
        if fresh(.providerNavigation), (age(.snapshot, at: tick) ?? (tick - startedTick)) > 2,
           (checkpoints[.providerNavigation]?.tick ?? 0) > (checkpoints[.snapshot]?.tick ?? startedTick) { return .snapshotGenerationStalled }
        if fresh(.providerSnapshot), (age(.coreConsumed, at: tick) ?? (tick - startedTick)) > 2,
           coreConsumedSession != sessionID || (sequence ?? 0) > (coreConsumedSequence ?? 0) { return .coreConsumptionStalled }
        if observerActive, stalled(.coreLocation) { return .coreLocationStalled }
        if observerActive, fresh(.coreLocation), let coreAge = coreSourceAge(at: tick), (0...5).contains(coreAge),
           let accuracy = coreAccuracy, accuracy.isFinite, accuracy >= 0, stalled(.amapLocation) { return .amapRawCallbackStalled }
        // Every callback can be flowing with an old SDK source. That is unknown, not a freshness bug.
        guard fresh(.amapLocation), fresh(.providerLocation), fresh(.snapshot), fresh(.coreConsumed),
              coreConsumedSession == sessionID, coreConsumedSequence == sequence, let sourceAge = sourceAge(at: tick), sourceAge >= -2 else { return .unknown }
        let expected: NavigationFreshness = sourceAge > 15 ? .stale : sourceAge > 5 ? .delayed : .fresh
        if freshness != expected { return .freshnessClassificationMismatch }
        return freshness == .fresh ? .none : .unknown
    }
    public mutating func diagnostic(at tick: Double, date: Date, freshness: NavigationFreshness,
        lifecycle: String, authorization: String, watchConnectivity: String, gps: String) -> (String?, NavigationPipelineDiagnosticSnapshot) {
        var event: String?
        let previous = previousFreshness
        if previous == .fresh && (freshness == .delayed || freshness == .stale) { event = "pipeline_stall_snapshot" }
        if freshness == .stale && previous != .stale && stalledAt == nil {
            stalledAt = tick; stalledSession = sessionID; stalledSequence = sequence; stalledStarts = providerStarts
            countsAtStall = checkpoints.mapValues(\.count); stallTicks = checkpoints.compactMapValues(\.tick); firstRecoveredLayer = nil
            event = "pipeline_stall_snapshot"
        }
        var row = NavigationPipelineDiagnosticSnapshot(sessionID: sessionID, sequence: sequence,
            coreConsumedSessionID: coreConsumedSession, coreConsumedSequence: coreConsumedSequence, recordedAt: date,
            elapsed: tick - startedTick, checkpoints: Dictionary(uniqueKeysWithValues: checkpoints.map { ($0.key.rawValue, $0.value) }),
            ages: Dictionary(uniqueKeysWithValues: checkpoints.compactMap { key, value in value.age(at: tick).map { (key.rawValue, $0) } }),
            classification: classify(at: tick, freshness: freshness), sourceAge: sourceAge(at: tick),
            amapLocationSourceTimestamp: amapSourceTimestamp, amapHorizontalAccuracy: amapAccuracy,
            sdkBackgroundLocation: sdkBackgroundLocation, sdkAutomaticPause: sdkAutomaticPause,
            coreLocationSourceTimestamp: coreSourceTimestamp, coreLocationSourceAge: coreSourceAge(at: tick), horizontalAccuracy: coreAccuracy,
            authorization: authorization, lifecycle: lifecycle, navigationState: navigationActive ? "navigating" : "inactive", sdkState: sdkState,
            routeActive: routeActive, observerActive: observerActive, watchConnectivity: watchConnectivity, gpsState: gps)
        if freshness == .fresh, let start = stalledAt {
            event = "pipeline_recovered"; row.staleDuration = tick - start
            row.sameSession = stalledSession == sessionID
            row.sequenceContinued = stalledSession == sessionID && (sequence ?? 0) > (stalledSequence ?? 0)
            row.sessionRebuilt = stalledSession != sessionID || stalledStarts != providerStarts
            row.firstRecoveredLayer = firstRecoveredLayer?.rawValue ?? "unknown"
            stalledAt = nil; firstRecoveredLayer = nil
        }
        previousFreshness = freshness
        return (event, row)
    }
}
/// Lock-protected synchronous entry instrumentation runs BEFORE MainActor/mapper/AsyncStream.
public final class NavigationPipelineRecorder: @unchecked Sendable {
    public static let shared = NavigationPipelineRecorder()
    private let lock = NSLock()
    private let clock = ContinuousClock()
    private let origin = ContinuousClock.now
    private var value = NavigationPipelineMeasurements()
    private var owner: UUID?
    public init() {}
    public func tick() -> Double {
        let parts = origin.duration(to: clock.now).components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
    public func begin(owner: UUID, session: UUID) {
        lock.lock(); defer { lock.unlock() }
        value = NavigationPipelineMeasurements(); value.startedTick = tick()
        value.sessionID = session; value.providerStarts = 1; value.navigationActive = true; value.routeActive = true
        self.owner = owner
    }
    public func update(owner: UUID? = nil, _ body: (inout NavigationPipelineMeasurements) -> Void) {
        lock.lock(); defer { lock.unlock() }
        guard owner == nil || owner == self.owner else { return }
        body(&value)
    }
    public func observe(_ layer: PipelineLayer, owner: UUID? = nil, source: Date? = nil, accuracy: Double? = nil) {
        let now = Date(), time = tick()
        lock.lock(); defer { lock.unlock() }
        guard value.navigationActive || layer == .amapStatus, owner == nil || owner == self.owner else { return }
        let newest = value.checkpoints[layer]?.tick.map { time >= $0 } ?? true
        value.observe(layer, tick: time, date: now)
        guard newest else { return }
        if layer == .amapLocation { value.sourceAgeAtCallback = source.map { now.timeIntervalSince($0) }; value.amapSourceTimestamp = source; value.amapAccuracy = accuracy }
        if layer == .coreLocation {
            value.coreSourceTimestamp = source; value.coreSourceAgeAtCallback = source.map { now.timeIntervalSince($0) }; value.coreAccuracy = accuracy
        }
    }
    public func diagnostic(freshness: NavigationFreshness, lifecycle: String, authorization: String,
                           watchConnectivity: String, gps: String) -> (String?, NavigationPipelineDiagnosticSnapshot) {
        let time = tick(), now = Date()
        lock.lock(); defer { lock.unlock() }
        return value.diagnostic(at: time, date: now, freshness: freshness, lifecycle: lifecycle,
            authorization: authorization, watchConnectivity: watchConnectivity, gps: gps)
    }
}
#endif
