import XCTest
@testable import AMapMappers
import NavigationWatchCore

final class AMapShareLinkTests: XCTestCase {
    private func place(_ text: String) throws -> NavigationPlace {
        guard case let .destination(value) = try AMapShareParser.parse(AMapShareParser.url(in: text)) else { throw AMapShareError.cannotResolve }
        return value
    }
    func testObservedRouteAndPlaceShareSchemas() throws {
        let route = try place("https://wb.amap.com/?r=31.1,121.1,Origin,31.2,121.2,%25E5%2585%25AC%25E5%259B%25AD,metadata")
        XCTAssertEqual(route.latitude,31.2); XCTAssertEqual(route.longitude,121.2); XCTAssertEqual(route.name,"公园"); XCTAssertEqual(route.coordinateReference,.gcj02)
        let point = try place("https://wb.amap.com/?p=B000000000,31.3,121.3,Library,address")
        XCTAssertEqual(point.latitude,31.3); XCTAssertEqual(point.longitude,121.3); XCTAssertEqual(point.name,"Library")
    }
    func testOfficialCoordinatesAndNames() throws {
        let route = try place("https://uri.amap.com/navigation?to=121.2,31.2,Park&mode=car")
        XCTAssertEqual(route.latitude,31.2); XCTAssertEqual(route.name,"Park")
        let marker = try place("https://uri.amap.com/marker?position=121.3,31.3&name=Library")
        XCTAssertEqual(marker.longitude,121.3)
        XCTAssertEqual(try place("iosamap://navi?lat=31.2&lon=121.2&dev=0&poiname=Park").latitude,31.2)
    }
    func testPastedMarkdownAndAppWrapper() throws {
        let parsed = try AMapShareParser.parse(AMapShareParser.url(in: "地点 [https://surl.amap.com/test123](https://surl.amap.com/test123)（分享）"))
        XCTAssertEqual(parsed,.shortLink(URL(string:"https://surl.amap.com/test123")!))
        XCTAssertEqual(try place("navigationwatch://import?url=https%3A%2F%2Furi.amap.com%2Fmarker%3Fposition%3D121.3%2C31.3").latitude,31.3)
        XCTAssertEqual(try AMapShareParser.parse(URL(string:"https://uri.amap.com/marker?poiid=B000000000")!),.poiID("B000000000"))
    }
    func testRejectsAmbiguousUnsafeOrUnsupportedInput() {
        for text in ["https://amap.com.evil.example/?to=121,31", "https://user@uri.amap.com/?to=121,31", "https://uri.amap.com/?to=121,31&to=122,32", "https://uri.amap.com/marker?position=NaN,31", "https://uri.amap.com/marker?position=121,91", "https://uri.amap.com/marker?position=121,31&coordinate=wgs84", "https://uri.amap.com/navigation?to=121,31&mode=walk", "navigationwatch://import?url=navigationwatch%3A%2F%2Fimport"] {
            XCTAssertThrowsError(try AMapShareParser.parse(URL(string:text)!))
        }
        XCTAssertFalse(AMapShareParser.allowedWebURL(URL(string:"https://127.0.0.1")!))
        XCTAssertFalse(AMapShareParser.allowedWebURL(URL(string:"http://surl.amap.com/test")!))
    }
    func testRealRouteShortLinkWhenSupplied() async throws {
        guard let url = ProcessInfo.processInfo.environment["AMAP_ROUTE_SHARE_SAMPLE"] else { throw XCTSkip("No external sample requested") }
        guard case let .destination(place) = try await AMapShareResolver().resolve(url) else { return XCTFail("Expected actual destination") }
        XCTAssertEqual(place.coordinateReference,.gcj02)
        XCTAssertFalse(place.name.isEmpty)
    }
    func testRealPlaceShortLinkWhenSupplied() async throws {
        guard let url = ProcessInfo.processInfo.environment["AMAP_PLACE_SHARE_SAMPLE"] else { throw XCTSkip("No external sample requested") }
        guard case let .destination(place) = try await AMapShareResolver().resolve(url) else { return XCTFail("Expected actual place") }
        XCTAssertEqual(place.coordinateReference,.gcj02)
        XCTAssertFalse(place.name.isEmpty)
    }

}
