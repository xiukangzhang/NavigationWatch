import Foundation

@MainActor public protocol NavigationProvider: AnyObject {
    var capabilities: NavigationCapabilities { get }
    var navigationStatus: NavigationStatus { get }
    func search(_ query: String) async throws -> [NavigationPlace]
    func calculateRoute(to destination: NavigationPlace) async throws -> [NavigationRoute]
    func startNavigation(route: NavigationRoute) async throws
    func stopNavigation() async
    func pauseNavigation() async throws
    func resumeNavigation() async throws
    func reroute() async throws
    func navigationUpdates() -> AsyncStream<NavigationSnapshot>
}

@MainActor public final class NavigationCore {
    private let provider: any NavigationProvider
    private var updateTask: Task<Void, Never>?
    public private(set) var latest: NavigationSnapshot?
    #if DEBUG
    public private(set) var diagnosticConsumedAt: Date?
    public private(set) var diagnosticConsumedSequence: UInt64?
    public private(set) var diagnosticConsumedSessionID: UUID?
    #endif
    public var onSnapshot: ((NavigationSnapshot) -> Void)?
    public init(provider: any NavigationProvider) { self.provider = provider }
    public func start(route: NavigationRoute) async throws {
        updateTask?.cancel()
        latest = nil
        #if DEBUG
        diagnosticConsumedAt = nil; diagnosticConsumedSequence = nil; diagnosticConsumedSessionID = nil
        #endif
        let updates = provider.navigationUpdates()
        updateTask = Task { [weak self] in
            for await snapshot in updates {
                guard !Task.isCancelled else { break }
                #if DEBUG
                NavigationPipelineRecorder.shared.observe(.coreConsumed)
                NavigationPipelineRecorder.shared.update {
                    if $0.sessionID == snapshot.sessionID {
                        $0.coreConsumedSession = snapshot.sessionID; $0.coreConsumedSequence = snapshot.sequence
                    }
                }
                self?.diagnosticConsumedAt = Date()
                self?.diagnosticConsumedSequence = snapshot.sequence
                self?.diagnosticConsumedSessionID = snapshot.sessionID
                #endif
                self?.latest = snapshot
                self?.onSnapshot?(snapshot)
            }
        }
        do { try await provider.startNavigation(route: route) }
        catch { updateTask?.cancel(); throw error }
    }
    public func stop() async {
        await provider.stopNavigation()
        updateTask?.cancel()
        updateTask = nil
    }
}

public enum SnapshotDecision: Sendable, Equatable {
    case accepted, unsupportedVersion, duplicate, outOfOrder, oldSession
}

/// A new session can first arrive through context or pull at any sequence.
/// Source timestamps are produced on the same iPhone and protect against delayed old sessions.
public struct SnapshotGate: Sendable {
    public private(set) var activeSessionID: UUID?
    public private(set) var lastAppliedSequence: UInt64?
    public private(set) var sessionStartedAt: Date?
    public private(set) var lastAppliedTimestamp: Date?
    private var retiredSessionIDs: Set<UUID> = []
    public init() {}
    public mutating func beginSession(_ id: UUID, startedAt: Date = Date()) {
        activeSessionID = id
        lastAppliedSequence = nil
        sessionStartedAt = startedAt
    }
    public mutating func evaluate(_ snapshot: NavigationSnapshot) -> SnapshotDecision {
        guard snapshot.version == 1 else { return .unsupportedVersion }
        if snapshot.sessionID != activeSessionID {
            guard !retiredSessionIDs.contains(snapshot.sessionID) else { return .oldSession }
            guard snapshot.timestamp > (lastAppliedTimestamp ?? .distantPast) else { return .oldSession }
            if let activeSessionID { retiredSessionIDs.insert(activeSessionID) }
            beginSession(snapshot.sessionID, startedAt: snapshot.timestamp)
        }
        if let lastAppliedSequence {
            if snapshot.sequence == lastAppliedSequence { return .duplicate }
            if snapshot.sequence < lastAppliedSequence { return .outOfOrder }
        }
        lastAppliedSequence = snapshot.sequence
        lastAppliedTimestamp = snapshot.timestamp
        return .accepted
    }
    public mutating func accept(_ snapshot: NavigationSnapshot) -> Bool { evaluate(snapshot) == .accepted }
}

public enum ConnectionQuality: String, Codable, Sendable { case excellent, good, degraded, disconnected }
public struct ConnectionHealth: Codable, Sendable, Equatable {
    public var quality: ConnectionQuality = .disconnected
    public var lastMessageAt: Date?
    public var lastAckAt: Date?
    public var roundTripLatency: TimeInterval?
    public var lastSnapshotAge: TimeInterval?
    public init() {}
}
