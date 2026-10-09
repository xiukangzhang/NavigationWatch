import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

public struct NavigationActivityAttributes: Codable, Sendable {
    public let navigationSessionID: UUID
    public init(navigationSessionID: UUID) { self.navigationSessionID = navigationSessionID }

    public struct ContentState: Codable, Hashable, Sendable {
        public var maneuver: String
        public var distanceToManeuver: Double?
        public var nextRoad: String?
        public var remainingDistance: Double?
        public var remainingDuration: Double?
        public var eta: Date?
        public var timestamp: Date
        public var navigationState: String
        public var trafficStatus: String?
    }
}
#if canImport(ActivityKit) && os(iOS)
extension NavigationActivityAttributes: ActivityAttributes {}
#endif
