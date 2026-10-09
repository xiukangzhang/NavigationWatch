import XCTest
@testable import NavigationWatchCore
import AMapMappers

final class NavigationCoreTests: XCTestCase {
    private func sample(session: UUID, sequence: UInt64, date: Date = Date()) -> NavigationSnapshot {
        NavigationSnapshot(sessionID: session, sequence: sequence, timestamp: date, status: .navigating,
            maneuver: .right, instruction: "右转", currentRoad: "甲路", nextRoad: "乙路",
            distanceToManeuver: 100, remainingDistance: 2_000, remainingDuration: 300,
            eta: date.addingTimeInterval(300), routeProgress: 0.5, currentSpeed: nil, speedLimit: nil,
            traffic: nil, trafficLight: TrafficLight(distance: nil, state: nil, countdown: nil),
            laneGuidance: nil, camera: nil, roadEvent: nil, gpsAccuracy: nil, heading: nil,
            locationTimestamp: nil, watchConnectionState: .unknown, capabilities: NavigationCapabilities())
    }
    func testSnapshotCodingAndOptionalTrafficLight() throws {
        let value = sample(session: UUID(), sequence: 7)
        XCTAssertEqual(try JSONDecoder().decode(NavigationSnapshot.self, from: JSONEncoder().encode(value)), value)
        XCTAssertNil(value.trafficLight?.countdown)
    }
    func testSequenceOrderingAndSessionIsolation() {
        var gate = SnapshotGate()
        let old = UUID(), newer = UUID()
        let start = Date()
        XCTAssertTrue(gate.accept(sample(session: old, sequence: 0, date: start)))
        XCTAssertTrue(gate.accept(sample(session: old, sequence: 2, date: start.addingTimeInterval(2))))
        XCTAssertFalse(gate.accept(sample(session: old, sequence: 1, date: start.addingTimeInterval(1))))
        XCTAssertFalse(gate.accept(sample(session: old, sequence: 2, date: start.addingTimeInterval(2))))
        XCTAssertTrue(gate.accept(sample(session: newer, sequence: 0, date: start.addingTimeInterval(10))))
        XCTAssertFalse(gate.accept(sample(session: old, sequence: 3, date: start.addingTimeInterval(3))))
        let reconnected = UUID()
        XCTAssertTrue(gate.accept(sample(session: reconnected, sequence: 8, date: start.addingTimeInterval(20))))
        XCTAssertFalse(gate.accept(sample(session: newer, sequence: 4, date: start.addingTimeInterval(11))))
        XCTAssertEqual(gate.evaluate(sample(session: old, sequence: 101, date: start.addingTimeInterval(30))), .oldSession)
    }
    func testEnvelopeRoundTrip() throws {
        let snapshot = sample(session: UUID(), sequence: 3)
        let envelope = NavigationMessageEnvelope(type: .navigationSnapshot, snapshot: snapshot)
        XCTAssertEqual(try JSONDecoder().decode(NavigationMessageEnvelope.self, from: JSONEncoder().encode(envelope)), envelope)
    }
    func testLatencyStatisticsAndStalePolicy() {
        var samples = LatencySamples()
        for value in [0.1, 0.2, 0.3, 0.4, 0.5] { samples.record(value) }
        samples.record(-1)
        XCTAssertEqual(samples.summary.count, 5)
        XCTAssertEqual(samples.summary.median, 0.3)
        XCTAssertEqual(samples.summary.p95, 0.5)
        XCTAssertEqual(samples.summary.p99, 0.5)
        XCTAssertEqual(samples.summary.max, 0.5)
        let now = Date()
        let policy = StaleStatePolicy(threshold: 5)
        XCTAssertFalse(policy.isStale(sample(session: UUID(), sequence: 0, date: now.addingTimeInterval(-4)), at: now))
        XCTAssertTrue(policy.isStale(sample(session: UUID(), sequence: 0, date: now.addingTimeInterval(-6)), at: now))
    }
    func testWatchStalePolicyAllowsObservedCallbackGapButExpiresSourceData() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let policy = StaleStatePolicy(threshold: StaleStatePolicy.watchDefaultThreshold)
        let session = UUID()
        for age: TimeInterval in [5, 23.6, 52, 60, 90] {
            let value = sample(session: session, sequence: 30, date: now.addingTimeInterval(-age))
            XCTAssertFalse(policy.isStale(value, at: now), "source age \(age)")
        }
        let old = sample(session: session, sequence: 30, date: now.addingTimeInterval(-90.1))
        XCTAssertTrue(policy.isStale(old, at: now))
        // Pulling the same snapshot does not change its original source time.
        let decoded = try JSONDecoder().decode(NavigationSnapshot.self, from: JSONEncoder().encode(old))
        XCTAssertTrue(policy.isStale(decoded, at: now))
        XCTAssertFalse(policy.isStale(old.stopped(), at: now))
        XCTAssertFalse(policy.isStale(nil, at: now))
    }
    #if DEBUG
    @MainActor func testPhase75PreviousRunStateIsOnlyTerminationClue() throws {
        let suite = "NavigationWatchTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date(timeIntervalSince1970: 1000)
        let first = PreviousRunStateStore(defaults: defaults, now: now, runID: UUID(), processID: 1)
        XCTAssertNil(first.previous)
        XCTAssertFalse(first.previousMayHaveTerminatedUnexpectedly)
        XCTAssertTrue(first.scene("active", at: now))
        XCTAssertFalse(first.scene("active", at: now))
        let session = UUID()
        first.applied(session: session, sequence: 12)
        first.scene("background", at: now.addingTimeInterval(10))
        XCTAssertFalse(first.current.cleanExitMarker) // background never certifies exit
        let second = PreviousRunStateStore(defaults: defaults, now: now.addingTimeInterval(20), runID: UUID(), processID: 2)
        XCTAssertTrue(second.previousMayHaveTerminatedUnexpectedly)
        XCTAssertEqual(second.previous?.lastScene, "background")
        XCTAssertEqual(second.previous?.lastNavigationSequence, 12)
        XCTAssertEqual(second.previous?.lastSessionID, session)
        XCTAssertEqual(second.previous?.lastActiveAt, now)
        XCTAssertEqual(second.current.lastNavigationSequence, nil)
        XCTAssertEqual(second.current.processID, 2)
    }
    @MainActor func testPhase75CorruptPreviousRunStateDoesNotInventCrash() throws {
        let suite = "NavigationWatchTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid".utf8), forKey: "watch.previousRunState")
        let state = PreviousRunStateStore(defaults: defaults)
        XCTAssertTrue(state.previousStateCorrupt)
        XCTAssertNil(state.previous)
        XCTAssertFalse(state.previousMayHaveTerminatedUnexpectedly)
    }
    #endif
    func testPhase7LaneCodesMatchPublicSDK() {
        let expected: [Int: [LaneDirection]] = [0:[.straight],1:[.left],2:[.straightLeft],3:[.right],
            4:[.straightRight],5:[.uTurn],6:[.left,.right],7:[.straight,.left,.right],8:[.uTurn],
            9:[.straight,.uTurn],10:[.straight,.uTurn],11:[.leftUTurn],12:[.rightUTurn],13:[.straight],
            14:[.leftUTurn],16:[.straight,.leftUTurn],17:[.right,.uTurn],18:[.leftUTurn,.right],
            19:[.straightRight,.uTurn],20:[.left,.uTurn],21:[.unknown],23:[.unknown]]
        for (code, directions) in expected { XCTAssertEqual(AMapLaneMapper.directions(for: code), directions, "code \(code)") }
        for code in [-1,15,22,255,999] { XCTAssertEqual(AMapLaneMapper.directions(for: code), [.unknown]) }
    }
    func testPhase7LaneRecommendationsFlagsAndMalformedData() throws {
        let value = try XCTUnwrap(AMapLaneMapper.map(background: "1|0|0|4", selected: "255|0|0|0"))
        XCTAssertEqual(value.recommendedLanes, [1,2,3])
        XCTAssertTrue(value.lanes[0].restricted)
        let flags = try XCTUnwrap(AMapLaneMapper.map(background: "21|23|999|0", selected: "255|23|0|oops"))
        XCTAssertTrue(flags.lanes[0].busOnly)
        XCTAssertTrue(flags.lanes[1].variable)
        XCTAssertEqual(flags.recommendedLanes, [1])
        XCTAssertFalse(flags.lanes[3].restricted) // malformed is not a confirmed restriction
        XCTAssertNil(AMapLaneMapper.map(background: "", selected: ""))
        XCTAssertNil(AMapLaneMapper.map(background: "0|1", selected: "0"))
    }
    func testPhase7TrafficStatusesAndNoInventedDelay() {
        let expected: [Int: TrafficStatus] = [0:.unknown,1:.smooth,2:.slow,3:.congested,4:.severe,5:.unknown,6:.smooth,999:.unknown]
        for (code, value) in expected { XCTAssertEqual(AMapTrafficMapper.status(for: code), value) }
        XCTAssertNil(AMapTrafficMapper.route(statusCodes: []))
        XCTAssertEqual(AMapTrafficMapper.route(statusCodes: [1,6])?.status, .smooth)
        XCTAssertEqual(AMapTrafficMapper.route(statusCodes: [1,3])?.status, .unknown)
        let congestion = AMapTrafficMapper.congestion(statusCode: 3, remainingLength: 1200, inArea: false)
        XCTAssertEqual(congestion.congestionLength, 1200)
        XCTAssertNil(congestion.congestionDistance)
        XCTAssertNil(congestion.estimatedDelay)
        XCTAssertEqual(congestion.displayText, "前方拥堵")
        XCTAssertEqual(AMapTrafficMapper.congestion(statusCode: 4, remainingLength: 100, inArea: true).displayText, "当前严重拥堵")
        XCTAssertNil(AMapTrafficMapper.congestion(statusCode: 3, remainingLength: -1, inArea: false).congestionLength)
        XCTAssertNil(AMapTrafficMapper.congestion(statusCode: 3, remainingLength: .nan, inArea: false).congestionLength)
        XCTAssertEqual(AMapTrafficMapper.congestion(statusCode: 1, remainingLength: 500, inArea: false).status, .unknown)
        XCTAssertNil(AMapTrafficMapper.route(statusCodes: [0])?.displayText)
    }
    func testPhase7SnapshotAndWatchVisibility() throws {
        let lanes = try XCTUnwrap(AMapLaneMapper.map(background: "0|4", selected: "255|3"))
        let traffic = AMapTrafficMapper.congestion(statusCode: 3, remainingLength: 1200, inArea: false)
        let id = UUID(), date = Date(timeIntervalSince1970: 1_000)
        var frame = AMapNavigationFrame(maneuverCode: 3, currentRoad: nil, nextRoad: "示例道路",
            distanceToManeuver: 150, remainingDistance: 2000, remainingDuration: 300, lanes: lanes, traffic: traffic)
        let near = AMapSnapshotMapper.snapshot(from: frame, sessionID: id, sequence: 7, at: date)
        XCTAssertEqual(near.visibleLaneGuidance, lanes)
        XCTAssertEqual(near.traffic, traffic)
        XCTAssertEqual(near.timestamp, date)
        XCTAssertTrue(near.capabilities.supportsTraffic)
        XCTAssertTrue(near.capabilities.supportsLaneGuidance)
        frame.distanceToManeuver = 501
        XCTAssertNil(AMapSnapshotMapper.snapshot(from: frame, sessionID: id, sequence: 8).visibleLaneGuidance)
        frame.distanceToManeuver = 150; frame.lanes = LaneGuidance(lanes: [])
        XCTAssertNil(AMapSnapshotMapper.snapshot(from: frame, sessionID: id, sequence: 9).visibleLaneGuidance)
        frame.lanes = nil; frame.traffic = nil
        let absent = AMapSnapshotMapper.snapshot(from: frame, sessionID: id, sequence: 10)
        XCTAssertNil(absent.visibleLaneGuidance)
        XCTAssertNil(absent.traffic?.displayText)
        XCTAssertEqual(LaneDirection.straightRight.displaySymbol, "↑→")
        XCTAssertEqual(LaneDirection.leftUTurn.displaySymbol, "←↩")
    }
    func testAMapFrameMapsToWatchSnapshot() {
        let id = UUID()
        let now = Date()
        let frame = AMapNavigationFrame(maneuverCode: 3, currentRoad: "甲路", nextRoad: "乙路",
            distanceToManeuver: 120, remainingDistance: 2_000, remainingDuration: 300)
        let snapshot = AMapSnapshotMapper.snapshot(from: frame, sessionID: id, sequence: 4, at: now)
        XCTAssertEqual(snapshot.sessionID, id)
        XCTAssertEqual(snapshot.sequence, 4)
        XCTAssertEqual(snapshot.maneuver, .right)
        XCTAssertEqual(snapshot.distanceToManeuver, 120)
        XCTAssertEqual(snapshot.remainingDistance, 2_000)
        XCTAssertEqual(snapshot.eta, now.addingTimeInterval(300))
        XCTAssertEqual(snapshot.nextRoad, "乙路")
    }
    func testAMapLaneCodesRejectUnavailableLane() throws {
        let guidance = try XCTUnwrap(AMapSnapshotMapper.lanes(background: "1|4|3", selected: "255|4|3"))
        XCTAssertEqual(guidance.recommendedLanes, [1, 2])
        XCTAssertTrue(guidance.lanes[0].restricted)
        XCTAssertEqual(guidance.lanes[1].directions, [.straightRight])
    }

    func testAMapRoundaboutExitIsNotUTurn() {
        XCTAssertEqual(AMapSnapshotMapper.maneuver(for: 18), .unknown)
        XCTAssertEqual(AMapSnapshotMapper.maneuver(for: 19), .uTurn)
        XCTAssertEqual(AMapSnapshotMapper.maneuver(for: 20), .straight)
    }
    @MainActor func testMockRestartUsesNewSessionAndZeroSequence() async throws {
        let provider = MockNavigationProvider(tickInterval: .milliseconds(2), totalTicks: 6)
        let destination = NavigationPlace(id: "x", name: "终点", latitude: 0, longitude: 0)
        let routes = try await provider.calculateRoute(to: destination)
        let route = try XCTUnwrap(routes.first)
        let firstStream = provider.navigationUpdates()
        try await provider.startNavigation(route: route)
        var firstIterator = firstStream.makeAsyncIterator()
        let firstValue = await firstIterator.next()
        let first = try XCTUnwrap(firstValue)
        await provider.stopNavigation()
        let secondStream = provider.navigationUpdates()
        try await provider.startNavigation(route: route)
        var secondIterator = secondStream.makeAsyncIterator()
        let secondValue = await secondIterator.next()
        let second = try XCTUnwrap(secondValue)
        XCTAssertEqual(second.sequence, 0)
        XCTAssertNotEqual(first.sessionID, second.sessionID)
        await provider.stopNavigation()
    }
    @MainActor func testMockProducesConsecutiveUpdatesAndArrival() async throws {
        let provider = MockNavigationProvider(tickInterval: .milliseconds(10), totalTicks: 3)
        let destination = NavigationPlace(id: "x", name: "终点", latitude: 0, longitude: 0)
        let routes = try await provider.calculateRoute(to: destination)
        let route = try XCTUnwrap(routes.first)
        let stream = provider.navigationUpdates()
        try await provider.startNavigation(route: route)
        var values: [NavigationSnapshot] = []
        for await value in stream { values.append(value) }
        XCTAssertEqual(values.map(\.sequence), [0, 1, 2, 3])
        XCTAssertEqual(values.last?.status, .arrived)
        await provider.stopNavigation()
    }
    @MainActor func testMockProviderEmitsInitialSnapshot() async throws {
        let provider = MockNavigationProvider()
        let destination = NavigationPlace(id: "x", name: "终点", latitude: 0, longitude: 0)
        let routes = try await provider.calculateRoute(to: destination)
        let route = try XCTUnwrap(routes.first)
        let stream = provider.navigationUpdates()
        try await provider.startNavigation(route: route)
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first?.sequence, 0)
        XCTAssertEqual(first?.status, .navigating)
        await provider.stopNavigation()
    }
}
