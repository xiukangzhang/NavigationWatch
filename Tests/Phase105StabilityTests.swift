import XCTest
@testable import NavigationWatchCore

final class Phase105StabilityTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func pipeline() -> LocationPipelineTimeline {
        var p = LocationPipelineTimeline()
        p.navigationProviderState = "navigating"; p.locationAuthorization = "whenInUse"
        p.sampleAvailable = true; p.sourceLocationAt = now; p.lastRawLocationAt = now
        p.lastAMapNavigationCallbackAt = now; p.currentHorizontalAccuracy = 10
        return p
    }
    func testFreshDelayedStaleRecoveryAndAgeIsNotUnavailable() {
        var p = pipeline()
        XCTAssertEqual(p.diagnosis(at: now).0, .fresh)
        XCTAssertEqual(p.diagnosis(at: now.addingTimeInterval(6)).0, .delayed)
        XCTAssertEqual(p.diagnosis(at: now.addingTimeInterval(16)).0, .stale)
        XCTAssertEqual(p.diagnosis(at: now.addingTimeInterval(16)).1, .noRawLocationCallback)
        let later = now.addingTimeInterval(17)
        p.sourceLocationAt = later; p.lastRawLocationAt = later; p.lastAMapNavigationCallbackAt = later
        XCTAssertEqual(p.diagnosis(at: later).0, .fresh)
        XCTAssertEqual(p.diagnosis(at: later).1, .none)
    }
    func testRepeatedSDKSourceIsStillStaleAndQueueDelayIsSeparate() throws {
        var p = pipeline()
        let later = now.addingTimeInterval(20)
        p.observeLocation(source: now, available: true, receivedAt: later, appliedAt: later.addingTimeInterval(0.1))
        XCTAssertEqual(p.sourceProgress, "repeated")
        XCTAssertEqual(p.callbackQueueDelay!, 0.1, accuracy: 0.001)
        XCTAssertEqual(p.diagnosis(at: later).0, .stale)
        XCTAssertEqual(p.diagnosis(at: later).1, .staleLocation)
        p.observeLocation(source: later, available: true, receivedAt: later, appliedAt: later)
        XCTAssertEqual(p.sourceProgress, "advanced")
        XCTAssertEqual(p.lastSourceAdvancedAt, later)
        XCTAssertEqual(p.diagnosis(at: later).0, .fresh)
        p.observeLocation(source: now, available: true, receivedAt: later, appliedAt: later)
        XCTAssertEqual(p.sourceProgress, "regressed")
        XCTAssertEqual(p.lastSourceAdvancedAt, later)
        p.gpsSignal = .weak; p.isNetworkPosition = true; p.isMatchedToRoute = false
        let restored = try JSONDecoder().decode(LocationPipelineTimeline.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(restored.sourceProgress, "regressed")
        XCTAssertEqual(restored.gpsSignal, .weak); XCTAssertEqual(restored.isNetworkPosition, true)
    }
    func testNavigationCallbackPausedWhileLocationsFresh() {
        var p = pipeline(); p.lastAMapNavigationCallbackAt = now.addingTimeInterval(-16)
        XCTAssertEqual(p.diagnosis(at: now).1, .noNavigationCallback)
        XCTAssertEqual(p.diagnosis(at: now).0, .fresh)
    }
    func testCallbacksPresentButSourceStaleAndPermissionInactiveUnknown() {
        var p = pipeline(); p.sourceLocationAt = now.addingTimeInterval(-16)
        XCTAssertEqual(p.diagnosis(at: now).1, .staleLocation)
        p.locationAuthorization = "denied"
        XCTAssertEqual(p.diagnosis(at: now).1, .authorizationRestricted)
        p.locationAuthorization = "whenInUse"; p.navigationProviderState = "stopped"
        XCTAssertEqual(p.diagnosis(at: now).1, .providerInactive)
        p.navigationProviderState = "navigating"; p.sampleAvailable = false
        XCTAssertEqual(p.diagnosis(at: now).1, .unknown)
    }
    func testPoorAccuracyAndLifecycleDoNotInventCrashOrSuspension() {
        var p = pipeline(); p.currentHorizontalAccuracy = 100; p.appLifecycleState = "background"
        XCTAssertEqual(p.diagnosis(at: now).1, .poorAccuracy)
        p.currentHorizontalAccuracy = 10
        XCTAssertEqual(p.diagnosis(at: now).1, .none)
        XCTAssertEqual(WatchExitObservation.classify(scene: nil, reachable: nil, stale: false, missingCleanMarker: false), .unknown)
        XCTAssertEqual(WatchExitObservation.classify(scene: "background", reachable: false, stale: false, missingCleanMarker: false), .normalBackground)
        XCTAssertEqual(WatchExitObservation.classify(scene: "background", reachable: false, stale: false, missingCleanMarker: true), .possibleUnexpectedTermination)
    }
    func testConfigurablePolicyAndUIWarningRecovery() {
        var policy = NavigationFreshnessPolicy(); policy.delayedAfter = 2; policy.locationStaleAfter = 8
        XCTAssertEqual(policy.classify(source: now, available: true, at: now.addingTimeInterval(3)), .delayed)
        XCTAssertEqual(policy.classify(source: now, available: true, at: now.addingTimeInterval(9)), .stale)
        var state = snapshot(sequence: 1, at: now)
        state.locationQuality = LocationQualityMapper.map(accuracy: 10, timestamp: now, gpsSignal: .strong,
            providerAvailable: true, isNetworkPosition: false, isMatchedToRoute: true, at: now)
        XCTAssertEqual(state.locationWarning(at: now.addingTimeInterval(16)), "定位信息暂未更新")
        XCTAssertFalse(state.reliableGuidance(at: now.addingTimeInterval(16)))
        state.locationQuality = LocationQualityMapper.map(accuracy: 10, timestamp: now.addingTimeInterval(17), gpsSignal: .strong,
            providerAvailable: true, isNetworkPosition: false, isMatchedToRoute: true, at: now.addingTimeInterval(17))
        XCTAssertNil(state.locationWarning(at: now.addingTimeInterval(17)))
        XCTAssertTrue(state.reliableGuidance(at: now.addingTimeInterval(17)))
    }
    @MainActor func testPreviousRunConnectivityAndTimesRoundTrip() {
        let suite = "phase105.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreviousRunStateStore(defaults: defaults, now: now)
        store.scene("active", at: now); store.connectivity("activated", at: now, received: true)
        let id = UUID(); store.applied(session: id, sequence: 8, at: now)
        store.scene("background", at: now)
        let next = PreviousRunStateStore(defaults: defaults, now: now.addingTimeInterval(1))
        XCTAssertEqual(next.previous?.lastAppliedAt, now); XCTAssertEqual(next.previous?.lastReceivedAt, now)
        XCTAssertEqual(next.previous?.lastConnectivityState, "activated")
        XCTAssertTrue(next.previousMayHaveTerminatedUnexpectedly)
        XCTAssertFalse(next.previous?.cleanExitMarker ?? true)
    }
    @MainActor func testCoreAndWatchGateRecoverWithoutNewSessionOrRollback() async throws {
        let provider = ControlledProvider(); let core = NavigationCore(provider: provider)
        let place = NavigationPlace(id: "fixture", name: "fixture", latitude: 0, longitude: 0)
        try await core.start(route: NavigationRoute(id: "fixture", destination: place, distance: 10, duration: 10))
        var gate = SnapshotGate(); let id = UUID()
        for sequence in UInt64(1)...3 {
            var state = snapshot(sequence: sequence, at: now.addingTimeInterval(Double(sequence)), session: id)
            state.locationQuality = LocationQualityMapper.map(accuracy: 10,
                timestamp: sequence == 2 ? now.addingTimeInterval(-20) : state.timestamp,
                gpsSignal: .strong, providerAvailable: true, isNetworkPosition: false, isMatchedToRoute: true, at: state.timestamp)
            provider.output?.yield(state)
            for _ in 0..<100 where core.latest?.sequence != sequence { await Task.yield() }
            XCTAssertEqual(core.latest?.sequence, sequence); XCTAssertEqual(core.latest?.sessionID, id)
            XCTAssertEqual(gate.evaluate(state), .accepted)
            XCTAssertEqual(state.reliableGuidance(at: state.timestamp), sequence != 2)
        }
        XCTAssertEqual(gate.lastAppliedSequence, 3); XCTAssertEqual(provider.starts, 1)
        let older = snapshot(sequence: 2, at: now, session: id)
        XCTAssertEqual(gate.evaluate(older), .outOfOrder)
        XCTAssertNil(core.latest?.locationWarning(at: core.latest!.timestamp))
        await core.stop()
    }
    private func snapshot(sequence: UInt64, at date: Date, session: UUID = UUID()) -> NavigationSnapshot {
        NavigationSnapshot(sessionID: session, sequence: sequence, timestamp: date, status: .navigating,
            maneuver: .straight, instruction: "fixture", currentRoad: nil, nextRoad: nil,
            distanceToManeuver: 10, remainingDistance: 10, remainingDuration: 10, eta: nil, routeProgress: nil,
            currentSpeed: nil, speedLimit: nil, traffic: nil, trafficLight: nil, laneGuidance: nil,
            camera: nil, roadEvent: nil, gpsAccuracy: nil, heading: nil, locationTimestamp: nil,
            watchConnectionState: .unknown, capabilities: NavigationCapabilities())
    }
}
@MainActor private final class ControlledProvider: NavigationProvider {
    var capabilities = NavigationCapabilities(); var navigationStatus: NavigationStatus = .navigating
    var output: AsyncStream<NavigationSnapshot>.Continuation?; var starts = 0
    func navigationUpdates() -> AsyncStream<NavigationSnapshot> { AsyncStream { output = $0 } }
    func startNavigation(route: NavigationRoute) async throws { starts += 1 }
    func stopNavigation() async { output?.finish() }
    func search(_ query: String) async throws -> [NavigationPlace] { [] }
    func calculateRoute(to destination: NavigationPlace) async throws -> [NavigationRoute] { [] }
    func pauseNavigation() async throws {}
    func resumeNavigation() async throws {}
    func reroute() async throws {}
}
