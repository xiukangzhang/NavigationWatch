import XCTest
@testable import NavigationWatchCore
import AMapMappers

final class Phase8Tests: XCTestCase {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    func testSpeedLimitMapper() {
        XCTAssertEqual(AMapSpeedLimitMapper.map(60), 60)
        XCTAssertNil(AMapSpeedLimitMapper.map(0))
        XCTAssertNil(AMapSpeedLimitMapper.map(-1))
        XCTAssertNil(AMapSpeedLimitMapper.map(-2))
    }
    func testCameraMapperAndZone() {
        let types: [(Int, CameraType)] = [(0,.speed),(1,.surveillance),(2,.redLight),(3,.other),
            (4,.busLane),(5,.other),(6,.other),(8,.intervalSpeed),(9,.intervalSpeed),(10,.speed),(11,.other),(7,.unknown),(999,.unknown)]
        for (code, type) in types {
            XCTAssertEqual(AMapCameraMapper.map(.init(type: code, distance: 450, speed: 60), at: date).type, type)
        }
        let missing = AMapCameraMapper.map(.init(type: 9, distance: -1, speed: -2), at: date)
        XCTAssertNil(missing.distance); XCTAssertNil(missing.speedLimit)
        XCTAssertEqual(missing.intervalBoundary, .end)
        XCTAssertNil(AMapCameraMapper.nearest([], at: date))
        let near = AMapCameraMapper.nearest([.init(type: 2, distance: 800, speed: 0), .init(type: 0, distance: 100, speed: 60)], at: date)
        XCTAssertEqual(near?.distance, 100)
        XCTAssertNil(AMapCameraMapper.zone(state: 3, remaining: 100, average: 55, limit: 60, at: date))
        let zone = AMapCameraMapper.zone(state: 2, remaining: 100, average: 55, limit: 60, at: date)
        XCTAssertEqual(zone?.currentAverageSpeed, 55); XCTAssertEqual(zone?.zoneSpeedLimit, 60)
        let unknown = AMapCameraMapper.zone(state: 2, remaining: nil, average: nil, limit: nil, at: date)
        XCTAssertNil(unknown?.remainingDistance); XCTAssertNil(unknown?.currentAverageSpeed)
    }
    func testRoadEventMapperAndPassedEvents() {
        for (code,type) in [(1,RoadEventType.accident),(2,.construction),(3,.closure),(4,.control),(999,.unknown)] {
            let value = AMapRoadEventMapper.map(code: code, at: date)
            XCTAssertEqual(value.type,type); XCTAssertNil(value.distance); XCTAssertNil(value.severity); XCTAssertNil(value.description)
        }
        let raw = AMapRoadEventInput(code: 2, startSegment: 1, startLink: 2, endSegment: 1, endLink: 3)
        XCTAssertEqual(AMapRoadEventMapper.currentOrAhead([raw], segment: 1, link: 2, at: date)?.type, .construction)
        XCTAssertNil(AMapRoadEventMapper.currentOrAhead([raw], segment: 1, link: 4, at: date))
        XCTAssertNil(AMapRoadEventMapper.currentOrAhead([raw], segment: -1, link: 0, at: date))
        XCTAssertNil(AMapRoadEventMapper.currentOrAhead([], segment: 0, link: 0, at: date))
    }
    private func snapshot() -> NavigationSnapshot {
        var frame = AMapNavigationFrame(maneuverCode: 2, currentRoad: nil, nextRoad: nil,
            distanceToManeuver: 150, remainingDistance: 1000, remainingDuration: 100)
        frame.speedLimit = 60
        frame.cameraEvent = CameraEvent(type: .speed, distance: 450, speedLimit: 60, timestamp: date)
        frame.roadEventInfo = RoadEvent(type: .construction, timestamp: date)
        frame.averageSpeedZone = AverageSpeedZone(remainingDistance: 1000, zoneSpeedLimit: 60, currentAverageSpeed: 55, timestamp: date)
        return AMapSnapshotMapper.snapshot(from: frame, sessionID: UUID(), sequence: 1, at: date)
    }
    func testSnapshotAndConnectivityCodingCompatibility() throws {
        let original = snapshot()
        let envelope = NavigationMessageEnvelope(type: .navigationSnapshot, snapshot: original)
        XCTAssertEqual(try JSONDecoder().decode(NavigationMessageEnvelope.self, from: JSONEncoder().encode(envelope)), envelope)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String:Any])
        old.removeValue(forKey: "cameraEvent"); old.removeValue(forKey: "roadEventInfo"); old.removeValue(forKey: "averageSpeedZone")
        old["camera"] = "旧电子眼字段"; old["roadEvent"] = "旧道路字段"
        var caps = try XCTUnwrap(old["capabilities"] as? [String:Any]); caps.removeValue(forKey:"supportsRoadEvents"); old["capabilities"] = caps
        let decoded = try JSONDecoder().decode(NavigationSnapshot.self, from: JSONSerialization.data(withJSONObject:old))
        XCTAssertEqual(decoded.version, 1); XCTAssertNil(decoded.cameraEvent); XCTAssertNil(decoded.roadEventInfo)
        XCTAssertEqual(decoded.camera,"旧电子眼字段"); XCTAssertFalse(decoded.capabilities.supportsRoadEvents)
        let stopped = original.stopped()
        XCTAssertNil(stopped.cameraEvent); XCTAssertNil(stopped.roadEventInfo); XCTAssertNil(stopped.averageSpeedZone); XCTAssertNil(stopped.speedLimit)
    }
    func testMinimalDisplayLifetimeAndEmptyStates() {
        var value = snapshot()
        for limit in [Double.infinity, Double(Int.max), 60.5, -1] {
            var frame = AMapNavigationFrame(maneuverCode: 1, currentRoad: nil, nextRoad: nil,
                distanceToManeuver: 10, remainingDistance: 100, remainingDuration: 10)
            frame.speedLimit = limit
            XCTAssertNil(AMapSnapshotMapper.snapshot(from: frame, sessionID: UUID(), sequence: 1, at: date).speedLimitDisplayText)
        }
        XCTAssertEqual(value.speedLimitDisplayText,"限速 60")
        XCTAssertEqual(value.cameraDisplayText(at:date),"前方 450 m 测速 60")
        XCTAssertEqual(value.roadEventDisplayText(at:date),"路线施工")
        XCTAssertNil(value.cameraDisplayText(at:date.addingTimeInterval(91)))
        XCTAssertNil(value.roadEventDisplayText(at:date.addingTimeInterval(91)))
        value.cameraEvent = CameraEvent(type:.speed,distance:501,speedLimit:60,timestamp:date)
        XCTAssertNil(value.cameraDisplayText(at:date))
        value.cameraEvent = nil; value.roadEventInfo = nil
        XCTAssertNil(value.cameraDisplayText(at:date)); XCTAssertNil(value.roadEventDisplayText(at:date))
    }
}
