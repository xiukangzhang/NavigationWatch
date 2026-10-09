import XCTest
@testable import NavigationWatchCore
import AMapMappers

final class ReleaseCandidateTests: XCTestCase {
    let place = NavigationPlace(id: "poi", name: "Fixture", latitude: 31, longitude: 121, coordinateReference: .gcj02, address: "Fixture address")
    func testRealRouteMetricsAndOpaqueChoice() throws {
        var catalog = AMapRouteCatalog()
        catalog.append(sdkID: 12, distance: 2200, duration: 180, destination: place, traffic: nil)
        catalog.append(sdkID: 13, distance: 3000, duration: 150, destination: place, traffic: nil)
        XCTAssertEqual(catalog.routes.count, 2)
        XCTAssertEqual(catalog.routes[0].distance, 2200)
        XCTAssertEqual(catalog.routes[1].duration, 150)
        XCTAssertNotEqual(catalog.routes[0].id, place.id)
        XCTAssertEqual(catalog.sdkID(for: catalog.routes[1]), 13)
        XCTAssertNil(catalog.routes[0].traffic)
    }
    func testStaleAndAlteredRouteCannotSelectSDKRoute() throws {
        var catalog = AMapRouteCatalog()
        catalog.append(sdkID: 12, distance: 2200, duration: 180, destination: place, traffic: nil)
        let previous = try XCTUnwrap(catalog.routes.first)
        let altered = NavigationRoute(id: previous.id, destination: place, distance: 1, duration: 1)
        XCTAssertNil(catalog.sdkID(for: altered))
        catalog.reset()
        catalog.append(sdkID: 12, distance: 2300, duration: 190, destination: place, traffic: nil)
        XCTAssertNil(catalog.sdkID(for: previous))
    }
    func testInvalidMetricsAreNotDisplayedAsRoutes() {
        var catalog = AMapRouteCatalog()
        catalog.append(sdkID: 1, distance: 0, duration: 180, destination: place, traffic: nil)
        catalog.append(sdkID: 2, distance: .nan, duration: 180, destination: place, traffic: nil)
        catalog.append(sdkID: 3, distance: 100, duration: -1, destination: place, traffic: nil)
        XCTAssertTrue(catalog.routes.isEmpty)
    }
    func testLocalModelRoundTripAndUnits() throws {
        let value = NavigationRoute(id: UUID().uuidString, destination: place, distance: 2200, duration: 180)
        XCTAssertEqual(try JSONDecoder().decode(NavigationRoute.self, from: JSONEncoder().encode(value)), value)
        XCTAssertEqual(NavigationUnits.distance(980), "980 m")
        XCTAssertEqual(NavigationUnits.distance(1200), "1.2 km")
        XCTAssertEqual(NavigationUnits.duration(61), "2 min")
        XCTAssertEqual(NavigationUnits.distance(-1), "—")
    }
    @MainActor func testCoreStopAndRestartCannotConsumeRetiredStream() async throws {
        let provider = RCStreamProvider()
        let core = NavigationCore(provider: provider)
        let route = NavigationRoute(id: "fixture", destination: place, distance: 100, duration: 60)
        let first = expectation(description: "first stream")
        core.onSnapshot = { _ in first.fulfill() }
        try await core.start(route: route)
        let oldSession = UUID()
        provider.emit(session: oldSession)
        await fulfillment(of: [first], timeout: 1)
        let retired = provider.output
        await core.stop()
        let next = expectation(description: "new stream only")
        let newSession = UUID()
        core.onSnapshot = { value in XCTAssertEqual(value.sessionID, newSession); next.fulfill() }
        try await core.start(route: route)
        retired?.yield(provider.sample(session: oldSession))
        provider.emit(session: newSession)
        await fulfillment(of: [next], timeout: 1)
        XCTAssertEqual(core.latest?.sessionID, newSession)
        await core.stop()
        XCTAssertEqual(provider.stops, 2)
    }
}

@MainActor private final class RCStreamProvider: NavigationProvider {
    var capabilities = NavigationCapabilities()
    var navigationStatus: NavigationStatus = .idle
    var output: AsyncStream<NavigationSnapshot>.Continuation?
    var stops = 0
    func navigationUpdates() -> AsyncStream<NavigationSnapshot> {
        AsyncStream { output = $0 }
    }
    func startNavigation(route: NavigationRoute) async throws { navigationStatus = .navigating }
    func stopNavigation() async { stops += 1; navigationStatus = .stopped; output?.finish() }
    func search(_ query: String) async throws -> [NavigationPlace] { [] }
    func calculateRoute(to destination: NavigationPlace) async throws -> [NavigationRoute] { [] }
    func pauseNavigation() async throws { throw NavigationError.unsupportedOperation }
    func resumeNavigation() async throws { throw NavigationError.unsupportedOperation }
    func reroute() async throws { throw NavigationError.unsupportedOperation }
    func emit(session: UUID) { output?.yield(sample(session: session)) }
    func sample(session: UUID) -> NavigationSnapshot {
        NavigationSnapshot(sessionID: session, sequence: 1, timestamp: Date(), status: .navigating,
            maneuver: .left, instruction: "Fixture", currentRoad: nil, nextRoad: nil, distanceToManeuver: 100,
            remainingDistance: 1000, remainingDuration: 100, eta: nil, routeProgress: nil, currentSpeed: nil,
            speedLimit: nil, traffic: nil, trafficLight: nil, laneGuidance: nil, camera: nil, roadEvent: nil,
            gpsAccuracy: nil, heading: nil, locationTimestamp: nil, watchConnectionState: .unknown, capabilities: capabilities)
    }
}
