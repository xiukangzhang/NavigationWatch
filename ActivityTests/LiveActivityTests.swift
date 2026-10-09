import XCTest
import NavigationWatchCore
@testable import NavigationLiveActivity

@MainActor private final class Driver: NavigationActivityDriver {
    var starts: [(UUID, NavigationActivityAttributes.ContentState)] = []
    var updates: [NavigationActivityAttributes.ContentState] = []
    var ends: [String] = []
    var order: [String] = []
    var staleDates: [Date] = []
    func start(session: UUID, state: NavigationActivityAttributes.ContentState, staleDate: Date) async throws -> String {
        starts.append((session, state)); order.append("start"); staleDates.append(staleDate)
        return String(starts.count)
    }
    func update(id: String, state: NavigationActivityAttributes.ContentState, staleDate: Date) async {
        updates.append(state); order.append("update"); staleDates.append(staleDate)
    }
    func end(id: String, reason: String) async { ends.append(reason); order.append("end") }
    func endOrphans() async {}
}
@MainActor private final class Clock { var date = Date(timeIntervalSince1970: 1000) }

final class LiveActivityTests: XCTestCase {
    @MainActor func fixture(_ id: UUID = UUID(), _ seq: UInt64 = 1, _ time: Date = Date(timeIntervalSince1970: 1000),
                           distance: Double? = 278, maneuver: Maneuver = .right,
                           status: NavigationStatus = .navigating) -> NavigationSnapshot {
        .init(sessionID: id, sequence: seq, timestamp: time, status: status, maneuver: maneuver,
            instruction: "fixture", currentRoad: nil, nextRoad: "科苑南路", distanceToManeuver: distance,
            remainingDistance: 6200, remainingDuration: 960, eta: time.addingTimeInterval(960),
            routeProgress: nil, currentSpeed: nil, speedLimit: nil, traffic: nil, trafficLight: nil,
            laneGuidance: nil, camera: nil, roadEvent: nil, gpsAccuracy: nil, heading: nil,
            locationTimestamp: nil, watchConnectionState: .unknown, capabilities: .init())
    }
    @MainActor private func setup() -> (Driver, Clock, LiveActivityCoordinator) {
        let d = Driver(), clock = Clock()
        let coordinator = LiveActivityCoordinator(driver: d, now: { clock.date })
        coordinator.enable()
        return (d, clock, coordinator)
    }
    @MainActor func testPhase105ActivityResumesSameIDAfterLocationRecovery() async {
        let (driver, clock, coordinator) = setup(), session = UUID()
        var first = fixture(session, 1, clock.date)
        first.locationQuality = LocationQualityMapper.map(accuracy: 10, timestamp: clock.date, gpsSignal: .strong,
            providerAvailable: true, isNetworkPosition: false, isMatchedToRoute: true, at: clock.date)
        coordinator.submit(first); await coordinator.flush()
        clock.date += 20
        var stale = fixture(session, 2, clock.date)
        stale.locationQuality = first.locationQuality
        coordinator.submit(stale); await coordinator.flush()
        clock.date += 10
        var recovered = fixture(session, 3, clock.date)
        recovered.locationQuality = LocationQualityMapper.map(accuracy: 10, timestamp: clock.date, gpsSignal: .strong,
            providerAvailable: true, isNetworkPosition: false, isMatchedToRoute: true, at: clock.date)
        coordinator.submit(recovered); await coordinator.flush()
        XCTAssertEqual(driver.starts.count, 1); XCTAssertTrue(driver.ends.isEmpty)
        XCTAssertEqual(driver.updates.count, 2); XCTAssertEqual(driver.starts.first?.0, session)
        await coordinator.end(reason: "cleanup")
    }

    @MainActor func testMappingAndEncoding() throws {
        let snapshot = fixture()
        let state = NavigationActivityStateMapper.map(snapshot)
        XCTAssertEqual(state.maneuver, "right"); XCTAssertEqual(state.distanceToManeuver, 278)
        XCTAssertEqual(state.nextRoad, "科苑南路"); XCTAssertEqual(state.eta, snapshot.eta)
        let bytes = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(NavigationActivityAttributes.ContentState.self, from: bytes), state)
        XCTAssertLessThan(bytes.count, 4096)
        let payload = String(decoding: bytes, as: UTF8.self)
        XCTAssertFalse(payload.contains("latitude")); XCTAssertFalse(payload.contains("camera"))
    }
    @MainActor func testSingleStartAndRepeatedUpdates() async {
        let (d, _, c) = setup(), id = UUID()
        for seq in 1...20 { c.submit(fixture(id, UInt64(seq))) }
        await c.flush()
        XCTAssertEqual(d.starts.count, 1); XCTAssertEqual(d.updates.count, 0)
        await c.end(reason: "cleanup")
    }
    @MainActor func testMeaninglessDistanceDedup() async {
        let (d, _, c) = setup(), id = UUID()
        for (i, distance) in [278.0, 277, 276, 275].enumerated() { c.submit(fixture(id, UInt64(i+1), distance: distance)) }
        await c.flush(); XCTAssertEqual(d.starts.count, 1); XCTAssertEqual(d.updates.count, 0)
        await c.end(reason: "cleanup")
    }
    @MainActor func testThrottleThenLatestSnapshot() async {
        let (d, clock, c) = setup(), id = UUID()
        c.submit(fixture(id)); await c.flush()
        clock.date += 1
        c.submit(fixture(id, 2, clock.date, distance: 240)); await c.flush()
        XCTAssertEqual(d.updates.count, 0)
        clock.date += 5
        c.submit(fixture(id, 3, clock.date, distance: 230)); await c.flush()
        XCTAssertEqual(d.updates.last?.distanceToManeuver, 230)
        await c.end(reason: "cleanup")
    }
    @MainActor func testManeuverBypassesThrottle() async {
        let (d, _, c) = setup(), id = UUID()
        c.submit(fixture(id)); await c.flush()
        c.submit(fixture(id, 2, maneuver: .left)); await c.flush()
        XCTAssertEqual(d.updates.last?.maneuver, "left")
        await c.end(reason: "cleanup")
    }
    @MainActor func testStopEndsAndRejectsLateSnapshot() async {
        let (d, _, c) = setup(), id = UUID()
        c.submit(fixture(id)); await c.flush(); await c.end(reason: "stop")
        c.submit(fixture(id, 2)); await c.flush()
        XCTAssertEqual(d.ends, ["stop"]); XCTAssertEqual(d.starts.count, 1)
    }
    @MainActor func testSessionReplacementAndRejectOldSession() async {
        let (d, clock, c) = setup(), a = UUID(), b = UUID()
        c.submit(fixture(a)); await c.flush()
        clock.date += 1; c.submit(fixture(b, 1, clock.date)); await c.flush()
        clock.date += 1; c.submit(fixture(a, 100, clock.date)); await c.flush()
        XCTAssertEqual(d.order, ["start", "end", "start"])
        XCTAssertEqual(d.starts.last?.0, b)
        await c.end(reason: "cleanup")
    }
    @MainActor func testStopAStartB() async {
        let (d, clock, c) = setup(), a = UUID(), b = UUID()
        c.submit(fixture(a)); await c.flush(); await c.end(reason: "stop")
        c.enable(); clock.date += 1; c.submit(fixture(b, 1, clock.date)); await c.flush()
        c.submit(fixture(a, 99, clock.date.addingTimeInterval(1))); await c.flush()
        XCTAssertEqual(d.order, ["start", "end", "start"])
        await c.end(reason: "cleanup")
    }
    @MainActor func testArrivalDoesNotRestartFromLateSnapshot() async {
        let (d, _, c) = setup(), id = UUID()
        c.submit(fixture(id)); c.submit(fixture(id, 2, status: .arrived)); c.submit(fixture(id, 3))
        await c.flush(); XCTAssertEqual(d.ends, ["arrived"]); XCTAssertEqual(d.starts.count, 1)
    }
    @MainActor func testNoStartBeforeSuccessfulNavigationOrOnIdle() async {
        let d = Driver(), c = LiveActivityCoordinator(driver: d)
        c.submit(fixture()); await c.flush(); XCTAssertTrue(d.starts.isEmpty)
        c.enable(); c.submit(fixture(status: .idle)); await c.flush(); XCTAssertTrue(d.starts.isEmpty)
    }
    @MainActor func testStaleDateAndFreshnessHeartbeat() async {
        let (d, clock, c) = setup(), id = UUID()
        c.submit(fixture(id)); await c.flush()
        XCTAssertEqual(d.staleDates.first, clock.date.addingTimeInterval(15))
        clock.date += 10; c.submit(fixture(id, 2, clock.date)); await c.flush()
        XCTAssertEqual(d.updates.count, 1)
        await c.end(reason: "cleanup")
    }
    @MainActor func testStaleStartRejectedAndInvalidDistanceSanitized() async {
        let (d, clock, c) = setup()
        c.submit(fixture(UUID(), 1, clock.date.addingTimeInterval(-20))); await c.flush()
        XCTAssertTrue(d.starts.isEmpty)
        XCTAssertNil(NavigationActivityStateMapper.map(fixture(distance: .nan)).distanceToManeuver)
        await c.end(reason: "cleanup")
    }
    @MainActor func testFailureEndsActivity() async {
        let (d, _, c) = setup()
        c.submit(fixture()); await c.flush(); await c.end(reason: "provider_failure")
        XCTAssertEqual(d.ends, ["provider_failure"])
    }
    @MainActor func testPendingThrottleCancelledByStop() async {
        let (d, _, c) = setup(), id = UUID()
        c.submit(fixture(id)); await c.flush()
        c.submit(fixture(id, 2, distance: 240)); await c.flush()
        await c.end(reason: "stop"); await c.flush()
        XCTAssertEqual(d.starts.count, 1); XCTAssertTrue(d.updates.isEmpty)
        XCTAssertEqual(d.ends, ["stop"])
    }
    @MainActor func testDelayedThrottlePublishesWithoutAnotherSnapshot() async throws {
        let d = Driver()
        var policy = LiveActivityCoordinator.Policy()
        policy.farInterval = 0.05
        let c = LiveActivityCoordinator(driver: d, policy: policy)
        c.enable(); let id = UUID()
        c.submit(fixture(id, 1, Date())); await c.flush()
        c.submit(fixture(id, 2, Date(), distance: 240)); await c.flush()
        XCTAssertTrue(d.updates.isEmpty)
        try await Task.sleep(for: .milliseconds(120))
        await c.flush()
        XCTAssertEqual(d.updates.last?.distanceToManeuver, 240)
        await c.end(reason: "cleanup")
    }
    @MainActor func testOlderOrDuplicateSequenceCannotChangeManeuver() async {
        let (d, _, c) = setup(), id = UUID()
        c.submit(fixture(id, 3)); await c.flush()
        c.submit(fixture(id, 3, maneuver: .left)); c.submit(fixture(id, 2, maneuver: .left))
        await c.flush(); XCTAssertTrue(d.updates.isEmpty)
        await c.end(reason: "cleanup")
    }

}
