import XCTest
import MapKit
@testable import NavigationWatchCore
@testable import AMapMappers
import AppleProvider
import NavigationLiveActivity

final class ProviderContractTests: XCTestCase {
    func place(_ id: String = "opaque") -> NavigationPlace {
        NavigationPlace(id: id, name: "Public test origin", latitude: 31.2304, longitude: 121.4737,
                        coordinateReference: .mapKit)
    }
    @MainActor func testAppleCreationAndDifferentCapabilities() throws {
        let second: any NavigationProvider = try AppleRouteProvider(origin: place())
        let first = AMapCapabilityProfile.capabilities
        XCTAssertTrue(first.supportsTurnByTurn)
        XCTAssertTrue(first.supportsBackgroundNavigation)
        XCTAssertTrue(first.supportsSearch) // RC1 adds official keyword Search SDK.
        XCTAssertFalse(second.capabilities.supportsTurnByTurn)
        XCTAssertFalse(second.capabilities.supportsCamera)
        XCTAssertNotEqual(first, second.capabilities)
    }
    func testAMapSnapshotContractUsesUnifiedSessionAndCapabilities() throws {
        let frame = AMapNavigationFrame(maneuverCode: 2, currentRoad: nil, nextRoad: nil,
            distanceToManeuver: 20, remainingDistance: 500, remainingDuration: 60, lanes: nil, traffic: nil)
        let session = UUID()
        let snapshot = AMapSnapshotMapper.snapshot(from: frame, sessionID: session, sequence: 5)
        XCTAssertEqual(snapshot.sessionID, session)
        XCTAssertEqual(snapshot.capabilities, AMapCapabilityProfile.capabilities)
        XCTAssertNil(snapshot.cameraEvent)
        XCTAssertEqual(try JSONDecoder().decode(NavigationSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
    }
    func testLegacyCapabilitiesAndPlaceDecode() throws {
        let caps = try JSONDecoder().decode(NavigationCapabilities.self, from: Data("{}".utf8))
        XCTAssertFalse(caps.supportsTurnByTurn)
        XCTAssertFalse(caps.supportsBackgroundNavigation)
        let old = Data(#"{"id":"old","name":"old","latitude":31,"longitude":121}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(NavigationPlace.self, from: old).coordinateReference)
    }
    @MainActor func testCoordinateBoundaryRejectsUnspecifiedInput() throws {
        let old = NavigationPlace(id: "old", name: "", latitude: 31, longitude: 121)
        XCTAssertThrowsError(try AppleRouteProvider(origin: old))
    }
    @MainActor func testRouteAndPlaceMappingUseOpaqueIDs() throws {
        let raw = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: 31, longitude: 121)))
        raw.name = "Fixture"
        let destination = AppleRouteMapper.place(raw)
        let mapped = AppleRouteMapper.route(MKRoute(), destination: destination)
        XCTAssertNotNil(UUID(uuidString: mapped.id))
        XCTAssertNotEqual(mapped.id, destination.id)
        XCTAssertEqual(mapped.destination.coordinateReference, .mapKit)
    }
    @MainActor func testRouteOnlyStartFailsWithoutNavigationSamples() async throws {
        let provider: any NavigationProvider = try AppleRouteProvider(origin: place())
        let route = NavigationRoute(id: "non-vendor-id", destination: place(), distance: 500, duration: 60)
        let core = NavigationCore(provider: provider)
        do { try await core.start(route: route); XCTFail("Route-only start must fail") }
        catch { XCTAssertEqual(error as? NavigationError, .unsupportedOperation) }
        XCTAssertNil(core.latest)
        for await _ in provider.navigationUpdates() { XCTFail("No fake samples") }
        await provider.stopNavigation()
    }
    func testMissingCapabilitiesWireAndConsumers() throws {
        let now = Date()
        let value = NavigationSnapshot(sessionID: UUID(), sequence: 12, timestamp: now, status: .navigating,
            maneuver: .unknown, instruction: "", currentRoad: nil, nextRoad: nil, distanceToManeuver: nil,
            remainingDistance: nil, remainingDuration: nil, eta: nil, routeProgress: nil, currentSpeed: nil,
            speedLimit: nil, traffic: nil, trafficLight: nil, laneGuidance: nil, camera: nil, roadEvent: nil,
            gpsAccuracy: nil, heading: nil, locationTimestamp: nil, watchConnectionState: .unknown,
            capabilities: NavigationCapabilities())
        let decoded = try JSONDecoder().decode(NavigationSnapshot.self, from: JSONEncoder().encode(value))
        XCTAssertNil(decoded.cameraEvent); XCTAssertNil(decoded.visibleLaneGuidance)
        XCTAssertNil(NavigationActivityStateMapper.map(decoded).distanceToManeuver)
        var gate = SnapshotGate()
        XCTAssertTrue(gate.accept(decoded))
        XCTAssertEqual(decoded.sessionID, value.sessionID)
    }
    @MainActor func testAMapInstantiationAvailabilityBoundary() throws {
        guard AMapNavigationProvider.sdkAvailable else {
            XCTAssertThrowsError(try AMapNavigationProvider(apiKey: "", privacyAccepted: false))
            throw XCTSkip("macOS contract package has no iOS AMap SDK; real creation requires signed iPhone execution")
        }
        XCTAssertThrowsError(try AMapNavigationProvider(apiKey: "", privacyAccepted: false))
    }
    @MainActor func testLiveAppleSearchAndRoute() async throws {
        guard ProcessInfo.processInfo.environment["PHASE11_LIVE_MAPKIT"] == "1" else {
            throw XCTSkip("Explicit live service probe only")
        }
        let provider = try AppleRouteProvider(origin: place())
        let timeout = Task { @MainActor in
            try? await Task.sleep(for: .seconds(35))
            if !Task.isCancelled { await provider.stopNavigation() }
        }
        defer { timeout.cancel() }
        let found = try await provider.search("Shanghai People's Square")
        let destination = try XCTUnwrap(found.first)
        let routes = try await provider.calculateRoute(to: destination)
        let route = try XCTUnwrap(routes.first)
        XCTAssertGreaterThan(route.distance, 0)
        XCTAssertGreaterThan(route.duration, 0)
        XCTAssertEqual(route.destination, destination)
        print("PHASE11_LIVE_MAPKIT mappedSearchCount=\(found.count) mappedRouteCount=\(routes.count)")
        await provider.stopNavigation()
    }
}
