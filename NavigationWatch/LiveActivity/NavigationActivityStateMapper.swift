import Foundation
#if canImport(NavigationWatchCore)
import NavigationWatchCore
#endif

public enum NavigationActivityStateMapper {
    public static func map(_ snapshot: NavigationSnapshot) -> NavigationActivityAttributes.ContentState {
        .init(maneuver: snapshot.maneuver.rawValue,
              distanceToManeuver: valid(snapshot.distanceToManeuver),
              nextRoad: snapshot.nextRoad.map { String($0.prefix(80)) },
              remainingDistance: valid(snapshot.remainingDistance),
              remainingDuration: valid(snapshot.remainingDuration), eta: snapshot.eta,
              timestamp: snapshot.timestamp, navigationState: snapshot.status.rawValue,
              trafficStatus: snapshot.traffic?.status.rawValue)
    }
    private static func valid(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }
}
