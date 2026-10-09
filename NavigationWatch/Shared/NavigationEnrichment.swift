import Foundation

public struct TrafficLightInfo: Codable, Sendable, Equatable {
    public let remainingCount: Int?
    public let distance: Double?
    public let state: TrafficLightState?
    public let countdown: TimeInterval?
    public let timestamp: Date
    public init(remainingCount: Int?, distance: Double? = nil, state: TrafficLightState? = nil,
                countdown: TimeInterval? = nil, timestamp: Date) {
        self.remainingCount = remainingCount; self.distance = distance; self.state = state
        self.countdown = countdown; self.timestamp = timestamp
    }
}
public enum LocationQualityState: String, Codable, Sendable { case good, weak, stale, unavailable }
public enum GPSSignalQuality: String, Codable, Sendable { case strong, weak, smartPositioning, unknown }
public struct LocationQuality: Codable, Sendable, Equatable {
    public let state: LocationQualityState
    public let accuracy: Double?
    public let locationTimestamp: Date?
    public let gpsSignal: GPSSignalQuality
    public let isNetworkPosition: Bool
    public let isMatchedToRoute: Bool
    public let providerAvailable: Bool
    public let staleAfter: TimeInterval
    public func effectiveState(at now: Date) -> LocationQualityState {
        guard providerAvailable, let date = locationTimestamp else { return .unavailable }
        let age = now.timeIntervalSince(date)
        if age < -2 { return .unavailable }
        return age > staleAfter ? .stale : state
    }
}
public enum LocationQualityMapper {
    public struct Policy: Sendable {
        public var goodAccuracyMaximum = 50.0
        public var staleAfter = NavigationFreshnessPolicy.standard.locationStaleAfter
        public init() {}
    }
    public static func map(accuracy: Double?, timestamp: Date?, gpsSignal: GPSSignalQuality,
                           providerAvailable: Bool, isNetworkPosition: Bool, isMatchedToRoute: Bool,
                           at now: Date, policy: Policy = Policy()) -> LocationQuality {
        let validAccuracy = accuracy.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let status: LocationQualityState
        if !providerAvailable || timestamp == nil || validAccuracy == nil { status = .unavailable }
        else if now.timeIntervalSince(timestamp!) < -2 { status = .unavailable }
        else if now.timeIntervalSince(timestamp!) > policy.staleAfter { status = .stale }
        else if gpsSignal == .weak || gpsSignal == .smartPositioning || isNetworkPosition || !isMatchedToRoute ||
                    validAccuracy! > policy.goodAccuracyMaximum { status = .weak }
        else { status = .good }
        return LocationQuality(state: status, accuracy: validAccuracy, locationTimestamp: timestamp,
            gpsSignal: gpsSignal, isNetworkPosition: isNetworkPosition, isMatchedToRoute: isMatchedToRoute,
            providerAvailable: providerAvailable, staleAfter: policy.staleAfter)
    }
}

public struct SpeedLimitInfo: Codable, Sendable, Equatable {
    public let id: String
    public let speedLimit: Double
    public let timestamp: Date
    public init(id: String, speedLimit: Double, timestamp: Date) {
        self.id = id; self.speedLimit = speedLimit; self.timestamp = timestamp
    }
}
public enum NavigationEventKind: String, Codable, Sendable { case camera, road, speedLimit }
public enum NavigationEventPhase: String, Codable, Sendable { case firstSeen, updated }
public struct NavigationEvent: Codable, Sendable, Equatable {
    public let id: String
    public let kind: NavigationEventKind
    public let firstSeen: Date
    public let lastUpdated: Date
    public let phase: NavigationEventPhase
}
public struct NavigationEventCandidate: Sendable {
    public let id: String
    public let kind: NavigationEventKind
    public let timestamp: Date
    public let passed: Bool
    public init(id: String, kind: NavigationEventKind, timestamp: Date, passed: Bool = false) {
        self.id = id; self.kind = kind; self.timestamp = timestamp; self.passed = passed
    }
}
public struct NavigationEventTransition: Sendable, Equatable {
    public enum Action: String, Sendable { case firstSeen, updated, removed, passed, expired }
    public let id: String
    public let action: Action
}
/// Small route-scoped event ledger; typed Phase 8 payloads are retained.
public struct NavigationEventLifecycle: Sendable {
    public var maxAge: TimeInterval = 90
    public private(set) var active: [NavigationEvent] = []
    private var firstSeen: [String: Date] = [:]
    private var passedIDs: Set<String> = []
    public init() {}
    public mutating func reset() { active = []; firstSeen = [:]; passedIDs = [] }
    @discardableResult public mutating func reconcile(_ candidates: [NavigationEventCandidate], at now: Date) -> [NavigationEventTransition] {
        var next: [String: NavigationEvent] = [:]
        var transitions: [NavigationEventTransition] = []
        let previous = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
        for candidate in candidates {
            if candidate.passed {
                if passedIDs.insert(candidate.id).inserted { transitions.append(.init(id: candidate.id, action: .passed)) }
                continue
            }
            guard !passedIDs.contains(candidate.id), next[candidate.id] == nil else { continue }
            let age = now.timeIntervalSince(candidate.timestamp)
            guard age >= -2 && age <= maxAge else { continue }
            let isFirst = firstSeen[candidate.id] == nil
            let first = firstSeen[candidate.id] ?? candidate.timestamp
            firstSeen[candidate.id] = first
            let phase: NavigationEventPhase = isFirst ? .firstSeen : .updated
            next[candidate.id] = NavigationEvent(id: candidate.id, kind: candidate.kind,
                firstSeen: first, lastUpdated: candidate.timestamp, phase: phase)
            // Identical callbacks refresh freshness without repeating a logical alert.
            if isFirst { transitions.append(.init(id: candidate.id, action: .firstSeen)) }
            else if previous[candidate.id]?.lastUpdated != candidate.timestamp { transitions.append(.init(id: candidate.id, action: .updated)) }
        }
        for event in active where next[event.id] == nil && !passedIDs.contains(event.id) {
            let reason: NavigationEventTransition.Action = now.timeIntervalSince(event.lastUpdated) > maxAge ? .expired : .removed
            transitions.append(.init(id: event.id, action: reason))
        }
        active = next.values.sorted { $0.id < $1.id }
        return transitions
    }
}
extension NavigationSnapshot {
    public func locationWarning(at now: Date = Date()) -> String? {
        guard let locationQuality else { return nil } // Old payloads/Mock do not pretend to have GPS measurements.
        switch locationQuality.effectiveState(at: now) {
        case .good: return nil
        case .weak: return "GPS 信号较弱"
        case .stale: return "定位信息暂未更新"
        case .unavailable: return "定位暂不可用"
        }
    }
    public func reliableGuidance(at now: Date = Date()) -> Bool {
        guard let quality = locationQuality else { return true }
        return [.good, .weak].contains(quality.effectiveState(at: now))
    }
    public func trafficLightDisplayText(at now: Date = Date()) -> String? {
        guard let info = trafficLightInfo, (0...90).contains(now.timeIntervalSince(info.timestamp)),
              let count = info.remainingCount, count > 0 else { return nil }
        return "路线剩余 \(count) 个信号灯"
    }
}
