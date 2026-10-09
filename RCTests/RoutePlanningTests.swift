import XCTest
import NavigationWatchCore
import AMapMappers

final class RoutePlanningTests: XCTestCase {
    func testMixedTrafficAndHighwayMapping() {
        let info = AMapRoutePlanningMapper.map(trafficLightCount: 7, tollYuan: 35, roadClassCodes: [6, 0],
            trafficSegments: [(1, 1000), (2, 120), (3, 80), (4, 50), (0, 100)], routeLength: 1500)
        XCTAssertEqual(info.trafficLightCount, 7)
        XCTAssertEqual(info.usesHighway, true)
        XCTAssertEqual(info.estimatedTollYuan, 35)
        XCTAssertEqual(info.slowDistance, 120)
        XCTAssertEqual(info.congestedDistance, 80)
        XCTAssertEqual(info.severeDistance, 50)
        XCTAssertEqual(info.unknownTrafficDistance, 250)
    }
    func testMissingDataStaysUnknownAndUrbanExpresswayIsNotHighway() {
        let missing = AMapRoutePlanningMapper.map(trafficLightCount: -1, tollYuan: -1, roadClassCodes: [], trafficSegments: [])
        XCTAssertNil(missing.trafficLightCount); XCTAssertNil(missing.estimatedTollYuan)
        XCTAssertNil(missing.usesHighway); XCTAssertNil(missing.congestedDistance)
        let urban = AMapRoutePlanningMapper.map(trafficLightCount: 0, tollYuan: 0, roadClassCodes: [6], trafficSegments: [(1, 1000)])
        XCTAssertEqual(urban.usesHighway, false); XCTAssertEqual(urban.trafficLightCount, 0)
        XCTAssertEqual(urban.estimatedTollYuan, 0); XCTAssertEqual(urban.congestedDistance, 0)
        XCTAssertNil(AMapRoutePlanningMapper.map(trafficLightCount: 0, tollYuan: 0, roadClassCodes: [99], trafficSegments: [(3, .nan)]).usesHighway)
    }
    func testOptionalRouteMetadataCodableAndCatalogIdentity() throws {
        let place = NavigationPlace(id: "place", name: "示例地点", latitude: 31, longitude: 121)
        let legacy = NavigationRoute(id: "route", destination: place, distance: 1000, duration: 300)
        let decoded = try JSONDecoder().decode(NavigationRoute.self, from: JSONEncoder().encode(legacy))
        XCTAssertNil(decoded.planningInfo)
        let info = AMapRoutePlanningMapper.map(trafficLightCount: 3, tollYuan: 5, roadClassCodes: [0], trafficSegments: [(1, 1000)])
        var catalog = AMapRouteCatalog()
        catalog.append(sdkID: 42, distance: 1000, duration: 300, destination: place, traffic: nil, planningInfo: info)
        let route = try XCTUnwrap(catalog.routes.first)
        XCTAssertEqual(catalog.sdkID(for: route), 42)
        XCTAssertEqual(try JSONDecoder().decode(NavigationRoute.self, from: JSONEncoder().encode(route)), route)
        XCTAssertEqual(route.planningInfo, info)
    }
}
