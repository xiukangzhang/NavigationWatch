import Foundation

@MainActor public final class MockNavigationProvider: NavigationProvider {
    public var capabilities: NavigationCapabilities {
        var result = NavigationCapabilities()
        result.supportsSearch = true
        result.supportsRoutePlanning = true
        result.supportsTurnByTurn = true
        result.supportsTraffic = true
        result.supportsLaneGuidance = true
        result.supportsRerouting = true
        return result
    }
    public private(set) var navigationStatus: NavigationStatus = .idle
    private var continuation: AsyncStream<NavigationSnapshot>.Continuation?
    private var task: Task<Void, Never>?
    private var sessionID = UUID()
    private var sequence: UInt64 = 0
    private let tickInterval: Duration
    private let totalTicks: Int
    public init(tickInterval: Duration = .seconds(1), totalTicks: Int = 360) {
        self.tickInterval = tickInterval
        self.totalTicks = max(1, totalTicks)
    }
    public func search(_ query: String) async throws -> [NavigationPlace] {
        [NavigationPlace(id: "mock-destination", name: query.isEmpty ? "模拟终点" : query, latitude: 0, longitude: 0)]
    }
    public func calculateRoute(to destination: NavigationPlace) async throws -> [NavigationRoute] {
        [NavigationRoute(id: "mock-route", destination: destination, distance: 6_200, duration: 960)]
    }
    public func navigationUpdates() -> AsyncStream<NavigationSnapshot> {
        continuation?.finish()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in self.continuation = continuation }
    }
    public func startNavigation(route: NavigationRoute) async throws {
        task?.cancel()
        sessionID = UUID()
        sequence = 0
        navigationStatus = .navigating
        let output = continuation
        task = Task { [weak self] in
            guard let self else { return }
            let stages: [(NavigationStatus, Maneuver, String, Double, LaneGuidance?, TrafficState?)] = [
                (.navigating, .straight, "继续直行", 500, nil, nil),
                (.navigating, .right, "前方右转", 280, nil, nil),
                (.navigating, .right, "请靠右行驶", 120, LaneGuidance(lanes: [
                    Lane(index: 0, directions: [.straight], recommended: false, restricted: false, busOnly: false, variable: false),
                    Lane(index: 1, directions: [.straightRight], recommended: true, restricted: false, busOnly: false, variable: false),
                    Lane(index: 2, directions: [.right], recommended: true, restricted: false, busOnly: false, variable: false)
                ]), nil),
                (.navigating, .right, "前方右转", 40, nil, nil),
                (.navigating, .straight, "进入科苑南路", 900, nil, TrafficState(status: .congested, congestionDistance: 1_200, congestionLength: 600, estimatedDelay: nil)),
                (.offRoute, .unknown, "已偏离路线", 0, nil, nil),
                (.rerouting, .unknown, "正在重新规划", 0, nil, nil),
                (.navigating, .straight, "沿新路线直行", 300, nil, nil),
                (.arrived, .arrive, "已到达目的地", 0, nil, nil)
            ]
            for tick in 0...totalTicks {
                guard !Task.isCancelled else { break }
                let index = tick == totalTicks ? stages.count - 1 : min(tick / max(1, totalTicks / (stages.count - 1)), stages.count - 2)
                let stage = stages[index]
                navigationStatus = stage.0
                var snapshot = NavigationSnapshot(
                    sessionID: sessionID, sequence: sequence, timestamp: Date(), status: stage.0,
                    maneuver: stage.1, instruction: stage.2, currentRoad: "科技南路", nextRoad: "科苑南路",
                    distanceToManeuver: stage.3, remainingDistance: max(0, route.distance * (1 - Double(tick) / Double(totalTicks))),
                    remainingDuration: max(0, route.duration * (1 - Double(tick) / Double(totalTicks))), eta: Date().addingTimeInterval(max(0, route.duration * (1 - Double(tick) / Double(totalTicks)))),
                    routeProgress: min(1, Double(tick) / Double(totalTicks)), currentSpeed: 12, speedLimit: nil,
                    traffic: stage.5, trafficLight: nil, laneGuidance: stage.4, camera: nil, roadEvent: nil,
                    gpsAccuracy: 5, heading: nil, locationTimestamp: Date(), watchConnectionState: .unknown,
                    capabilities: capabilities)
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-phase105-soak") {
                    let phase = tick % 120
                    let now = Date()
                    let age = (20..<40).contains(phase) ? Double(phase - 20) : 0
                    snapshot.locationQuality = LocationQualityMapper.map(accuracy: 10,
                        timestamp: now.addingTimeInterval(-age), gpsSignal: .strong, providerAvailable: true,
                        isNetworkPosition: false, isMatchedToRoute: true, at: now)
                }
                #endif
                output?.yield(snapshot)
                sequence += 1
                if tick != totalTicks { try? await Task.sleep(for: tickInterval) }
            }
            output?.finish()
        }
    }
    public func stopNavigation() async { task?.cancel(); task = nil; navigationStatus = .stopped; continuation?.finish() }
    public func pauseNavigation() async throws { task?.cancel() }
    public func resumeNavigation() async throws { throw NavigationError.providerUnavailable }
    public func reroute() async throws { navigationStatus = .rerouting }
}
