import Foundation
#if SWIFT_PACKAGE
import NavigationWatchCore
#endif

/// Values copied from the iPhone SDK callback before crossing an actor boundary.
public struct AMapNavigationFrame: Sendable {
    public var maneuverCode: Int
    public var currentRoad: String?
    public var nextRoad: String?
    public var distanceToManeuver: Double
    public var remainingDistance: Double
    public var remainingDuration: TimeInterval
    public var lanes: LaneGuidance?
    public var traffic: TrafficState?
    public var speedLimit: Double? = nil
    public var cameraEvent: CameraEvent? = nil
    public var roadEventInfo: RoadEvent? = nil
    public var averageSpeedZone: AverageSpeedZone? = nil
    public var trafficLightInfo: TrafficLightInfo? = nil
    public var locationQuality: LocationQuality? = nil
    public var speedLimitInfo: SpeedLimitInfo? = nil
    public var navigationEvents: [NavigationEvent]? = nil

    public init(maneuverCode: Int, currentRoad: String?, nextRoad: String?,
                distanceToManeuver: Double, remainingDistance: Double,
                remainingDuration: TimeInterval, lanes: LaneGuidance? = nil, traffic: TrafficState? = nil) {
        self.maneuverCode = maneuverCode
        self.currentRoad = currentRoad
        self.nextRoad = nextRoad
        self.distanceToManeuver = distanceToManeuver
        self.remainingDistance = remainingDistance
        self.remainingDuration = remainingDuration
        self.lanes = lanes
        self.traffic = traffic
    }
}

public enum AMapSnapshotMapper {
    /// AMapNaviIconType values are defined in AMapNaviCommonObj.h.
    public static func maneuver(for code: Int) -> Maneuver {
        switch code {
        case 1, 9, 20: .straight
        case 2: .left
        case 3: .right
        case 4: .slightLeft
        case 5: .slightRight
        case 8, 19, 24, 28: .uTurn
        case 15: .arrive
        default: .unknown
        }
    }

    public static func snapshot(from frame: AMapNavigationFrame, sessionID: UUID,
                                sequence: UInt64, at date: Date = Date()) -> NavigationSnapshot {
        let maneuver = maneuver(for: frame.maneuverCode)
        let destination = frame.nextRoad?.trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction: String
        switch maneuver {
        case .straight: instruction = "继续直行"
        case .left: instruction = "向左转"
        case .right: instruction = "向右转"
        case .slightLeft: instruction = "向左前方行驶"
        case .slightRight: instruction = "向右前方行驶"
        case .uTurn: instruction = "掉头"
        case .arrive: instruction = "已到达目的地"
        case .unknown: instruction = "按路线继续行驶"
        }
        let text = destination.flatMap { $0.isEmpty ? nil : $0 }.map { "\(instruction)，进入\($0)" } ?? instruction
        let capabilities = AMapCapabilityProfile.capabilities
        return NavigationSnapshot(sessionID: sessionID, sequence: sequence, timestamp: date,
            status: maneuver == .arrive ? .arrived : .navigating,
            maneuver: maneuver, instruction: text,
            currentRoad: frame.currentRoad, nextRoad: frame.nextRoad,
            distanceToManeuver: max(0, frame.distanceToManeuver),
            remainingDistance: max(0, frame.remainingDistance),
            remainingDuration: max(0, frame.remainingDuration),
            eta: date.addingTimeInterval(max(0, frame.remainingDuration)),
            routeProgress: nil, currentSpeed: nil, speedLimit: frame.speedLimit,
            traffic: frame.traffic, trafficLight: nil, laneGuidance: frame.lanes,
            camera: nil, roadEvent: nil, gpsAccuracy: frame.locationQuality?.accuracy, heading: nil,
            locationTimestamp: frame.locationQuality?.locationTimestamp, watchConnectionState: .unknown,
            capabilities: capabilities, cameraEvent: frame.cameraEvent,
            roadEventInfo: frame.roadEventInfo, averageSpeedZone: frame.averageSpeedZone,
            trafficLightInfo: frame.trafficLightInfo, locationQuality: frame.locationQuality,
            speedLimitInfo: frame.speedLimitInfo, navigationEvents: frame.navigationEvents)
    }

    // Keep the existing entry point for compatibility with callers/tests.
    public static func lanes(background: String, selected: String) -> LaneGuidance? {
        AMapLaneMapper.map(background: background, selected: selected)
    }
}

/// Raw scalar inputs only; no SDK types cross into Shared or Watch.
/// Source: installed 11.2.100 AMapNaviDriveDataRepresentable.h.
public enum AMapLaneMapper {
    public static func directions(for code: Int) -> [LaneDirection] {
        switch code {
        case 0, 13: [.straight]
        case 1: [.left]
        case 2: [.straightLeft]
        case 3: [.right]
        case 4: [.straightRight]
        // 5/8 are a single left/right U-turn. Unified uTurn loses handedness.
        case 5, 8: [.uTurn]
        case 6: [.left, .right]
        case 7: [.straight, .left, .right]
        case 9, 10: [.straight, .uTurn]
        case 11, 14: [.leftUTurn]
        case 12: [.rightUTurn]
        case 16: [.straight, .leftUTurn]
        case 17: [.right, .uTurn]
        case 18: [.leftUTurn, .right]
        case 19: [.straightRight, .uTurn]
        case 20: [.left, .uTurn]
        // Bus/variable lane codes provide no reliable turn direction.
        default: [.unknown]
        }
    }
    private static func known(_ code: Int) -> Bool {
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 20, 21, 23].contains(code)
    }
    public static func map(background: String, selected: String) -> LaneGuidance? {
        guard !background.isEmpty, !selected.isEmpty else { return nil }
        let back = background.split(separator: "|", omittingEmptySubsequences: false)
        let front = selected.split(separator: "|", omittingEmptySubsequences: false)
        guard back.count == front.count else { return nil }
        return LaneGuidance(lanes: zip(back, front).enumerated().map { index, values in
            let code = Int(values.0.trimmingCharacters(in: .whitespaces)) ?? -1
            let choice = Int(values.1.trimmingCharacters(in: .whitespaces)) ?? -1
            return Lane(index: index, directions: directions(for: code),
                recommended: known(code) && known(choice), restricted: choice == 255,
                busOnly: code == 21, variable: code == 23)
        })
    }
}

public enum AMapTrafficMapper {
    public static func status(for code: Int) -> TrafficStatus {
        switch code {
        case 1, 6: .smooth
        case 2: .slow
        case 3: .congested
        case 4: .severe
        default: .unknown // 0 unknown, 5 internal road, future codes
        }
    }
    /// Route segments do not establish a single local status when mixed.
    /// Never synthesize nearest congestion distance from their lengths.
    public static func route(statusCodes: [Int]) -> TrafficState? {
        guard let first = statusCodes.first else { return nil }
        let states = statusCodes.map(status(for:))
        let value = states.allSatisfy { $0 == status(for: first) } ? status(for: first) : .unknown
        return TrafficState(status: value, congestionDistance: nil, congestionLength: nil, estimatedDelay: nil)
    }
    public static func congestion(statusCode: Int, remainingLength: Double, inArea: Bool) -> TrafficState {
        let mapped = status(for: statusCode)
        let valid = [.slow, .congested, .severe].contains(mapped)
        return TrafficState(status: valid ? mapped : .unknown,
            congestionDistance: valid && inArea ? 0 : nil,
            congestionLength: valid && remainingLength.isFinite && remainingLength >= 0 ? remainingLength : nil,
            // SDK remainTime is passage time, not delay compared to free flow.
            estimatedDelay: nil)
    }
}

/// Capabilities of the actual SDK-backed AMap implementation, not the unavailable stub.
public enum AMapCapabilityProfile {
    public static var capabilities: NavigationCapabilities {
        var value = NavigationCapabilities()
        value.supportsSearch = true
        value.supportsRoutePlanning = true
        value.supportsTurnByTurn = true
        value.supportsBackgroundNavigation = true
        value.supportsLaneGuidance = true
        value.supportsTraffic = true
        value.supportsSpeedLimit = true
        value.supportsCamera = true
        value.supportsRoadEvents = true
        value.supportsTrafficLight = true
        value.supportsRerouting = true
        return value
    }
}

/// Pure mapping and opaque selection handles for one successful planning request.
public struct AMapRouteCatalog: Sendable {
    public private(set) var routes: [NavigationRoute] = []
    private var sdkIDs: [String: Int] = [:]
    public init() {}
    public mutating func reset() { routes = []; sdkIDs = [:] }
    public mutating func append(sdkID: Int, distance: Double, duration: TimeInterval,
                                destination: NavigationPlace, traffic: TrafficState?, planningInfo: RoutePlanningInfo? = nil) {
        guard distance.isFinite, duration.isFinite, distance > 0, duration > 0 else { return }
        let id = UUID().uuidString
        sdkIDs[id] = sdkID
        routes.append(NavigationRoute(id: id, destination: destination, distance: distance, duration: duration, traffic: traffic, planningInfo: planningInfo))
    }
    public func sdkID(for route: NavigationRoute) -> Int? {
        guard routes.contains(route) else { return nil }
        return sdkIDs[route.id]
    }
}

/// Map SDK route facts without treating missing traffic or road classes as a negative answer.
public enum AMapRoutePlanningMapper {
    public static func map(trafficLightCount: Int, tollYuan: Int, roadClassCodes: [Int],
                           trafficSegments: [(status: Int, length: Double)], routeLength: Double? = nil) -> RoutePlanningInfo {
        let knownRoads = !roadClassCodes.isEmpty && roadClassCodes.allSatisfy { (0...10).contains($0) }
        let highway: Bool? = roadClassCodes.contains(0) ? true : (knownRoads ? false : nil)
        let segments = trafficSegments.filter { $0.length.isFinite && $0.length > 0 }
        func length(_ status: TrafficStatus) -> Double? {
            guard !segments.isEmpty else { return nil }
            return segments.filter { AMapTrafficMapper.status(for: $0.status) == status }.reduce(0) { $0 + $1.length }
        }
        return RoutePlanningInfo(trafficLightCount: trafficLightCount >= 0 ? trafficLightCount : nil,
            usesHighway: highway, estimatedTollYuan: tollYuan >= 0 ? tollYuan : nil,
            slowDistance: length(.slow), congestedDistance: length(.congested), severeDistance: length(.severe),
            unknownTrafficDistance: length(.unknown).map { $0 + max(0, (routeLength ?? 0) - segments.reduce(0) { $0 + $1.length }) })
    }
}
