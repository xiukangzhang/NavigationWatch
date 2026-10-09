import XCTest
@testable import NavigationWatchCore

final class Phase106DiagnosticTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_001_000)
    private func pipeline() -> LocationPipelineTimeline {
        var p = LocationPipelineTimeline()
        p.sessionID = UUID(); p.sequence = 4
        p.coreConsumedSessionID = p.sessionID; p.coreConsumedSequence = 4
        p.lastSnapshotGeneratedAt = now; p.lastCoreConsumedAt = now
        p.navigationProviderState = "navigating"; p.sampleAvailable = true
        p.sourceLocationAt = now.addingTimeInterval(-20); p.lastRawLocationAt = now
        return p
    }
    func testFreshUpstreamSeparatesAMapSourceFromCallbackGapAndCore() {
        var p = pipeline()
        XCTAssertEqual(p.boundary(at: now), .upstreamUnobserved)
        p.upstreamProbeRequestedAt = now; p.upstreamProbeCompletedAt = now
        p.upstreamResponseAt = now; p.upstreamSourceAt = now; p.upstreamAccuracy = 10
        XCTAssertEqual(p.boundary(at: now), .amapSourceStale)
        p.lastRawLocationAt = now.addingTimeInterval(-20)
        XCTAssertEqual(p.boundary(at: now), .amapCallbackGap)
        p.lastSnapshotGeneratedAt = now; p.coreConsumedSequence = 3; p.lastCoreConsumedAt = now.addingTimeInterval(-3)
        XCTAssertEqual(p.boundary(at: now), .coreConsumptionPending)
        p.coreConsumedSequence = 4; p.sourceLocationAt = now
        XCTAssertEqual(p.boundary(at: now), .flowing)
    }
    func testProbePendingFailureStaleAndExpiryDoNotClaimUpstreamContinuity() throws {
        var p = pipeline(); p.upstreamProbeRequestedAt = now
        XCTAssertEqual(p.boundary(at: now), .upstreamProbePending)
        p.upstreamProbeCompletedAt = now; p.upstreamProbeErrorCode = -106
        XCTAssertEqual(p.boundary(at: now), .upstreamProbeFailed)
        p.upstreamProbeErrorCode = nil; p.upstreamResponseAt = now; p.upstreamSourceAt = now.addingTimeInterval(-30)
        p.upstreamAccuracy = 10
        XCTAssertEqual(p.boundary(at: now), .upstreamSampleStale)
        XCTAssertEqual(p.boundary(at: now.addingTimeInterval(16)), .upstreamUnobserved)
        let restored = try JSONDecoder().decode(LocationPipelineTimeline.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(restored.upstreamSourceAt, p.upstreamSourceAt)
        XCTAssertEqual(restored.coreConsumedSessionID, p.sessionID)
    }
    func testProbeBudgetIsBoundedAndStopPreventsRequests() {
        var budget = LocationDiagnosticProbeBudget(); budget.start(at: now)
        XCTAssertFalse(budget.take(at: now, stale: false, pending: false))
        XCTAssertFalse(budget.take(at: now, stale: true, pending: true))
        XCTAssertTrue(budget.take(at: now, stale: true, pending: false))
        XCTAssertFalse(budget.take(at: now.addingTimeInterval(59), stale: true, pending: false))
        XCTAssertTrue(budget.take(at: now.addingTimeInterval(60), stale: true, pending: false))
        XCTAssertFalse(budget.take(at: now.addingTimeInterval(119), stale: true, pending: false))
        budget.start(at: now)
        XCTAssertFalse(budget.take(at: now.addingTimeInterval(120), stale: true, pending: false))
        budget.stop(); XCTAssertFalse(budget.take(at: now, stale: true, pending: false))
    }
    @MainActor func testRealCoreCheckpointAdvancesDuringStaleAndSameSessionRecovery() async throws {
        let provider = DiagnosticControlledProvider(); let core = NavigationCore(provider: provider)
        let place = NavigationPlace(id: "fixture", name: "fixture", latitude: 0, longitude: 0)
        try await core.start(route: NavigationRoute(id: "fixture", destination: place, distance: 10, duration: 10))
        let id = UUID(); var gate = SnapshotGate()
        for seq in UInt64(1)...3 {
            var s = NavigationSnapshot(sessionID: id, sequence: seq, timestamp: now.addingTimeInterval(Double(seq)), status: .navigating,
                maneuver: .straight, instruction: "fixture", currentRoad: nil, nextRoad: nil, distanceToManeuver: 10,
                remainingDistance: 10, remainingDuration: 10, eta: nil, routeProgress: nil, currentSpeed: nil, speedLimit: nil,
                traffic: nil, trafficLight: nil, laneGuidance: nil, camera: nil, roadEvent: nil, gpsAccuracy: nil, heading: nil,
                locationTimestamp: nil, watchConnectionState: .unknown, capabilities: NavigationCapabilities())
            s.locationQuality = LocationQualityMapper.map(accuracy: 10, timestamp: seq == 2 ? now.addingTimeInterval(-30) : s.timestamp,
                gpsSignal: .strong, providerAvailable: true, isNetworkPosition: false, isMatchedToRoute: true, at: s.timestamp)
            provider.output?.yield(s)
            for _ in 0..<1000 where core.diagnosticConsumedSequence != seq { await Task.yield() }
            XCTAssertEqual(core.diagnosticConsumedSequence, seq); XCTAssertEqual(core.diagnosticConsumedSessionID, id)
            XCTAssertNotNil(core.diagnosticConsumedAt); XCTAssertEqual(core.latest?.sessionID, id)
            XCTAssertEqual(gate.evaluate(s), .accepted)
            XCTAssertEqual(s.reliableGuidance(at: s.timestamp), seq != 2)
            XCTAssertEqual(s.locationWarning(at: s.timestamp), seq == 2 ? "定位信息暂未更新" : nil)
        }
        XCTAssertEqual(provider.starts, 1); await core.stop(); XCTAssertEqual(provider.stops, 1)
    }
}
@MainActor private final class DiagnosticControlledProvider: NavigationProvider {
    var capabilities = NavigationCapabilities(); var navigationStatus: NavigationStatus = .navigating
    var output: AsyncStream<NavigationSnapshot>.Continuation?; var starts = 0; var stops = 0
    func navigationUpdates() -> AsyncStream<NavigationSnapshot> { AsyncStream { output = $0 } }
    func startNavigation(route: NavigationRoute) async throws { starts += 1 }
    func stopNavigation() async { stops += 1; output?.finish() }
    func search(_ query: String) async throws -> [NavigationPlace] { [] }
    func calculateRoute(to destination: NavigationPlace) async throws -> [NavigationRoute] { [] }
    func pauseNavigation() async throws {}; func resumeNavigation() async throws {}; func reroute() async throws {}
}
