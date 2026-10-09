import Foundation
import MapKit
#if SWIFT_PACKAGE
import NavigationWatchCore
#endif

/// MapKit objects remain within the Provider boundary. IDs are local opaque handles.
@MainActor public enum AppleRouteMapper {
    public static func place(_ item: MKMapItem) -> NavigationPlace {
        NavigationPlace(id: UUID().uuidString, name: item.name ?? "", latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude, coordinateReference: .mapKit)
    }
    public static func route(_ route: MKRoute, destination: NavigationPlace) -> NavigationRoute {
        NavigationRoute(id: UUID().uuidString, destination: destination, distance: route.distance,
                        duration: route.expectedTravelTime)
    }
}
