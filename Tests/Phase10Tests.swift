import XCTest
@testable import NavigationWatchCore
import AMapMappers

final class Phase10Tests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func quality(accuracy: Double? = 10, age: Double = 0, signal: GPSSignalQuality = .strong,
                 available: Bool = true, network: Bool = false, matched: Bool = true) -> LocationQuality {
        LocationQualityMapper.map(accuracy: accuracy, timestamp: available ? now.addingTimeInterval(-age) : nil,
            gpsSignal: signal, providerAvailable: available, isNetworkPosition: network,
            isMatchedToRoute: matched, at: now)
    }
    func testTrafficLightCountOnlyAndUnknownFallback() {
        let info = AMapTrafficLightMapper.map(remainingCount: 3, at: now)
        XCTAssertEqual(info?.remainingCount, 3); XCTAssertNil(info?.distance)
        XCTAssertNil(info?.state); XCTAssertNil(info?.countdown)
        XCTAssertEqual(AMapTrafficLightMapper.map(remainingCount: 0, at: now)?.remainingCount, 0)
        XCTAssertNil(AMapTrafficLightMapper.map(remainingCount: -1, at: now))
    }
    func testGoodLocation() { XCTAssertEqual(quality().state, .good) }
    func testWeakLocationUsesActualAccuracyAndSignal() {
        XCTAssertEqual(quality(accuracy: 100).state, .weak)
        XCTAssertEqual(quality(signal: .weak).state, .weak)
        XCTAssertEqual(quality(network: true).state, .weak)
        XCTAssertEqual(quality(matched: false).state, .weak)
        XCTAssertEqual(quality(signal: .smartPositioning).state, .weak)
        XCTAssertEqual(quality(accuracy: 100).accuracy, 100)
    }
    func testStaleLocationUsesSourceAge() { XCTAssertEqual(quality(age: 16).state, .stale) }
    func testUnavailableLocationAndInvalidMeasurements() {
        XCTAssertEqual(quality(available: false).state, .unavailable)
        for value in [Double.nan, .infinity, -1, 0] { XCTAssertEqual(quality(accuracy: value).state, .unavailable) }
        XCTAssertEqual(quality(age: -10).state, .unavailable)
    }
    func testLocationBecomesStaleWithoutCallbacks() {
        XCTAssertEqual(quality().effectiveState(at: now.addingTimeInterval(16)), .stale)
    }
    func testGPSKnownAndUnknownCodes() {
        XCTAssertEqual(AMapGPSMapper.signal(1), .strong); XCTAssertEqual(AMapGPSMapper.signal(2), .weak)
        XCTAssertEqual(AMapGPSMapper.signal(3), .smartPositioning); XCTAssertEqual(AMapGPSMapper.signal(999), .unknown)
    }
    func testCameraIdentityIgnoresDistanceAndTime() {
        let identity = AMapEventIdentity.camera(type: 0, latitude: 22.5, longitude: 113.9, routeID: 1, segment: 1, link: 1)
        let a = AMapCameraMapper.map(.init(type: 0, distance: 450, speed: 60, identity: identity), at: now)
        let b = AMapCameraMapper.map(.init(type: 0, distance: 300, speed: 60, identity: identity), at: now.addingTimeInterval(1))
        XCTAssertEqual(a.id, b.id); XCTAssertNotEqual(a.distance, b.distance)
        XCTAssertFalse(identity.contains("22.5")); XCTAssertFalse(identity.contains("113.9"))
        XCTAssertNotEqual(identity, AMapEventIdentity.camera(type: 0, latitude: 22.6, longitude: 113.9, routeID: 1, segment: 1, link: 1))
    }
    func testCameraDedupFirstSeenOnlyOnce() {
        var life = NavigationEventLifecycle()
        var firstSeenCount = 0
        for offset in 0...50 {
            let changes = life.reconcile([.init(id: "camera", kind: .camera, timestamp: now.addingTimeInterval(Double(offset)))], at: now.addingTimeInterval(Double(offset)))
            firstSeenCount += changes.filter { $0.action == .firstSeen }.count
            XCTAssertEqual(life.active.count, 1)
            XCTAssertEqual(life.active.first?.firstSeen, now)
        }
        XCTAssertEqual(firstSeenCount, 1)
    }
    func testCameraPassedRemovesAndCannotResurrect() {
        var life = NavigationEventLifecycle()
        life.reconcile([.init(id: "camera", kind: .camera, timestamp: now)], at: now)
        let changes = life.reconcile([.init(id: "camera", kind: .camera, timestamp: now, passed: true)], at: now)
        XCTAssertTrue(life.active.isEmpty); XCTAssertEqual(changes.first?.action, .passed)
        life.reconcile([.init(id: "camera", kind: .camera, timestamp: now.addingTimeInterval(1))], at: now.addingTimeInterval(1))
        XCTAssertTrue(life.active.isEmpty)
    }
    func testCameraEmptyCallbackRemovesImmediately() {
        var life = NavigationEventLifecycle()
        life.reconcile([.init(id: "camera", kind: .camera, timestamp: now)], at: now)
        XCTAssertEqual(life.reconcile([], at: now).first?.action, .removed)
        XCTAssertTrue(life.active.isEmpty)
    }
    func testEventExpiryDoesNotRefreshFromGuidance() {
        var life = NavigationEventLifecycle()
        let candidate = NavigationEventCandidate(id: "road", kind: .road, timestamp: now)
        life.reconcile([candidate], at: now)
        XCTAssertEqual(life.reconcile([candidate], at: now.addingTimeInterval(91)).first?.action, .expired)
        XCTAssertTrue(life.active.isEmpty)
    }
    func testMissingAndReturningEventDoesNotRepeatFirstSeen() {
        var life = NavigationEventLifecycle()
        let candidate = NavigationEventCandidate(id: "camera", kind: .camera, timestamp: now)
        life.reconcile([candidate], at: now); life.reconcile([], at: now)
        let changes = life.reconcile([candidate], at: now)
        XCTAssertFalse(changes.contains { $0.action == .firstSeen })
    }
    func testRouteResetAllowsNewEventAndDoesNotLeakOldEvents() {
        var life = NavigationEventLifecycle()
        let candidate = NavigationEventCandidate(id: "camera", kind: .camera, timestamp: now)
        life.reconcile([candidate], at: now); life.reset()
        XCTAssertTrue(life.active.isEmpty)
        XCTAssertEqual(life.reconcile([candidate], at: now).first?.action, .firstSeen)
    }
    func testRoadIdentityStableAcrossCallbackTimesAndPassedRemoval() {
        let input = AMapRoadEventInput(code: 2, startSegment: 1, startLink: 2, endSegment: 1, endLink: 3)
        let a = AMapRoadEventMapper.currentOrAhead([input], segment: 1, link: 2, at: now)
        let b = AMapRoadEventMapper.currentOrAhead([input], segment: 1, link: 3, at: now.addingTimeInterval(1))
        XCTAssertEqual(a?.id, b?.id)
        XCTAssertNil(AMapRoadEventMapper.currentOrAhead([input], segment: 1, link: 4, at: now))
    }
    func snapshot() -> NavigationSnapshot {
        var frame = AMapNavigationFrame(maneuverCode: 3, currentRoad: nil, nextRoad: "测试道路", distanceToManeuver: 150,
            remainingDistance: 2400, remainingDuration: 360)
        frame.locationQuality = quality(); frame.trafficLightInfo = AMapTrafficLightMapper.map(remainingCount: 3, at: now)
        return AMapSnapshotMapper.snapshot(from: frame, sessionID: UUID(), sequence: 1, at: now)
    }
    func testEventTextAppearsUpdatesAndDisappears() {
        var state = snapshot()
        state.cameraEvent = CameraEvent(type: .speed, distance: 450, speedLimit: 60, timestamp: now, id: "camera")
        XCTAssertEqual(state.cameraDisplayText(at: now), "前方 450 m 测速 60")
        state.cameraEvent = CameraEvent(type: .speed, distance: 300, speedLimit: 60, timestamp: now, id: "camera")
        XCTAssertEqual(state.cameraDisplayText(at: now), "前方 300 m 测速 60")
        state.cameraEvent = nil; state.roadEventInfo = RoadEvent(type: .construction, timestamp: now, id: "road")
        XCTAssertEqual(state.roadEventDisplayText(at: now), "路线施工")
        state.roadEventInfo = nil
        XCTAssertNil(state.cameraDisplayText(at: now)); XCTAssertNil(state.roadEventDisplayText(at: now))
        XCTAssertEqual(state.maneuver, .right); XCTAssertEqual(state.distanceToManeuver, 150)
    }
    func testLocationWarningHidesStaleGuidanceAndWeakRemainsVisible() {
        var state = snapshot()
        XCTAssertTrue(state.reliableGuidance(at: now)); XCTAssertNil(state.locationWarning(at: now))
        XCTAssertFalse(state.reliableGuidance(at: now.addingTimeInterval(16)))
        XCTAssertEqual(state.locationWarning(at: now.addingTimeInterval(16)), "定位信息暂未更新")
        state.locationQuality = quality(signal: .weak)
        XCTAssertTrue(state.reliableGuidance(at: now)); XCTAssertEqual(state.locationWarning(at: now), "GPS 信号较弱")
    }
    func testEnrichmentEncodingAndOldPayloadDefaults() throws {
        let state = snapshot()
        XCTAssertEqual(try JSONDecoder().decode(NavigationSnapshot.self, from: JSONEncoder().encode(state)), state)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        for key in ["locationQuality", "trafficLightInfo", "speedLimitInfo", "navigationEvents"] { json.removeValue(forKey: key) }
        var caps = try XCTUnwrap(json["capabilities"] as? [String:Any]); caps.removeValue(forKey: "supportsTrafficLightState"); json["capabilities"] = caps
        let old = try JSONDecoder().decode(NavigationSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.locationQuality); XCTAssertNil(old.trafficLightInfo); XCTAssertNil(old.navigationEvents)
        XCTAssertFalse(old.capabilities.supportsTrafficLightState)
        XCTAssertFalse(old.capabilities.supportsTrafficLightCountdown)
        XCTAssertEqual(old.version, 1)
        XCTAssertNil(state.stopped().locationQuality); XCTAssertNil(state.stopped().trafficLightInfo)
    }
    func testCapabilitiesDescribeImplementedCountButNoLightStateOrCountdown() {
        let caps = snapshot().capabilities
        XCTAssertTrue(caps.supportsTrafficLight); XCTAssertFalse(caps.supportsTrafficLightState)
        XCTAssertFalse(caps.supportsTrafficLightCountdown)
        XCTAssertTrue(caps.supportsCamera); XCTAssertTrue(caps.supportsRoadEvents); XCTAssertTrue(caps.supportsSpeedLimit)
    }
    func testTrafficLightTextDoesNotInventNearestDistance() {
        XCTAssertEqual(snapshot().trafficLightDisplayText(at: now), "路线剩余 3 个信号灯")
        XCTAssertNil(snapshot().trafficLightDisplayText(at: now.addingTimeInterval(91)))
    }
    func testAllEventKindsShareRemovalAndFirstSeenPolicy() {
        var life = NavigationEventLifecycle()
        let inputs = [NavigationEventCandidate(id: "camera", kind: .camera, timestamp: now),
            .init(id: "road", kind: .road, timestamp: now), .init(id: "speed", kind: .speedLimit, timestamp: now)]
        XCTAssertEqual(life.reconcile(inputs, at: now).filter { $0.action == .firstSeen }.count, 3)
        XCTAssertEqual(life.reconcile([], at: now).filter { $0.action == .removed }.count, 3)
        XCTAssertTrue(life.active.isEmpty)
    }
}
