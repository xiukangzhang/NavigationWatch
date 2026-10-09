import Foundation
import MapKit
#if SWIFT_PACKAGE
import NavigationWatchCore
#endif

/// Experimental route-only implementation; never emits fabricated navigation samples.
@MainActor public final class AppleRouteProvider: NavigationProvider {
    public var capabilities: NavigationCapabilities {
        var value = NavigationCapabilities()
        value.supportsSearch = true
        value.supportsRoutePlanning = true
        return value
    }
    public private(set) var navigationStatus: NavigationStatus = .idle
    private let origin: NavigationPlace
    private var places: [String: MKMapItem] = [:]
    private var routes: [String: MKRoute] = [:]
    private var searchRequest: MKLocalSearch?
    private var directionRequest: MKDirections?
    private var generation = UUID()
    public init(origin: NavigationPlace) throws {
        guard origin.coordinateReference == .mapKit, Self.valid(origin) else {
            throw NavigationError.routeCalculationFailed
        }
        self.origin = origin
    }
    private static func valid(_ place: NavigationPlace) -> Bool {
        place.latitude.isFinite && place.longitude.isFinite && (-90...90).contains(place.latitude)
            && (-180...180).contains(place.longitude)
    }
    private func item(_ place: NavigationPlace) -> MKMapItem {
        MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: place.latitude, longitude: place.longitude)))
    }
    public func search(_ query: String) async throws -> [NavigationPlace] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard searchRequest == nil else { throw NavigationError.providerUnavailable }
        let token = generation
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: item(origin).placemark.coordinate,
                                             latitudinalMeters: 20_000, longitudinalMeters: 20_000)
        let service = MKLocalSearch(request: request)
        searchRequest = service
        defer { if generation == token { searchRequest = nil } }
        let result = try await service.start()
        try Task.checkCancellation()
        guard token == generation else { throw CancellationError() }
        places.removeAll()
        return result.mapItems.map { item in
            let value = AppleRouteMapper.place(item)
            places[value.id] = item
            return value
        }
    }
    public func calculateRoute(to destination: NavigationPlace) async throws -> [NavigationRoute] {
        guard destination.coordinateReference == .mapKit, Self.valid(destination), directionRequest == nil else {
            throw NavigationError.routeCalculationFailed
        }
        let token = generation
        let request = MKDirections.Request()
        request.source = item(origin)
        request.destination = places[destination.id] ?? item(destination)
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        let service = MKDirections(request: request)
        directionRequest = service
        defer { if generation == token { directionRequest = nil } }
        let result = try await service.calculate()
        try Task.checkCancellation()
        guard token == generation else { throw CancellationError() }
        routes.removeAll()
        return result.routes.map { raw in
            let value = AppleRouteMapper.route(raw, destination: destination)
            routes[value.id] = raw
            return value
        }
    }
    public func startNavigation(route: NavigationRoute) async throws { throw NavigationError.unsupportedOperation }
    public func pauseNavigation() async throws { throw NavigationError.unsupportedOperation }
    public func resumeNavigation() async throws { throw NavigationError.unsupportedOperation }
    public func reroute() async throws { throw NavigationError.unsupportedOperation }
    public func stopNavigation() async {
        generation = UUID()
        searchRequest?.cancel(); directionRequest?.cancel()
        searchRequest = nil; directionRequest = nil
        places.removeAll(); routes.removeAll()
        navigationStatus = .stopped
    }
    public func navigationUpdates() -> AsyncStream<NavigationSnapshot> { AsyncStream { $0.finish() } }
}
