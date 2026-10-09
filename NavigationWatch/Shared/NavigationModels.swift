import Foundation

public enum Maneuver: String, Codable, Sendable { case straight, left, right, slightLeft, slightRight, uTurn, arrive, unknown }
public enum LaneDirection: String, Codable, Sendable { case straight, left, right, uTurn, straightLeft, straightRight, leftUTurn, rightUTurn, unknown }
public struct Lane: Codable, Sendable, Equatable {
    public let index: Int
    public let directions: [LaneDirection]
    public let recommended: Bool
    public let restricted: Bool
    public let busOnly: Bool
    public let variable: Bool
    public init(index: Int,
                directions: [LaneDirection],
                recommended: Bool,
                restricted: Bool,
                busOnly: Bool,
                variable: Bool) {
        self.index = index
        self.directions = directions
        self.recommended = recommended
        self.restricted = restricted
        self.busOnly = busOnly
        self.variable = variable
    }

}
public struct LaneGuidance: Codable, Sendable, Equatable {
    public let lanes: [Lane]
    public var recommendedLanes: [Int] { lanes.filter(\.recommended).map(\.index) }
    public init(lanes: [Lane]) {
        self.lanes = lanes
    }

}
public enum TrafficStatus: String, Codable, Sendable { case smooth, slow, congested, severe, unknown }
public struct TrafficState: Codable, Sendable, Equatable {
    public let status: TrafficStatus
    public let congestionDistance: Double?
    public let congestionLength: Double?
    public let estimatedDelay: TimeInterval?
    public init(status: TrafficStatus,
                congestionDistance: Double?,
                congestionLength: Double?,
                estimatedDelay: TimeInterval?) {
        self.status = status
        self.congestionDistance = congestionDistance
        self.congestionLength = congestionLength
        self.estimatedDelay = estimatedDelay
    }

}
public enum TrafficLightState: String, Codable, Sendable { case red, yellow, green, unknown }
public struct TrafficLight: Codable, Sendable, Equatable {
    public let distance: Double?
    public let state: TrafficLightState?
    public let countdown: TimeInterval?
}
public enum WatchConnectionState: String, Codable, Sendable { case reachable, unavailable, unknown }
public enum NavigationStatus: String, Codable, Sendable { case idle, navigating, rerouting, offRoute, arrived, stopped, gpsUnavailable }

public enum CoordinateReference: String, Codable, Sendable { case mapKit, gcj02, bd09 }

public struct NavigationCapabilities: Codable, Sendable, Equatable {
    public var supportsSearch = false
    public var supportsRoutePlanning = false
    public var supportsTurnByTurn = false
    public var supportsBackgroundNavigation = false
    public var supportsTraffic = false
    public var supportsLaneGuidance = false
    public var supportsTrafficLight = false
    public var supportsTrafficLightState = false
    public var supportsTrafficLightCountdown = false
    public var supportsSpeedLimit = false
    public var supportsCamera = false
    public var supportsRoadEvents = false
    public var supportsVoiceGuidance = false
    public var supportsRerouting = false
    public init() {}
    private enum CodingKeys: String, CodingKey { case supportsSearch, supportsRoutePlanning, supportsTurnByTurn, supportsBackgroundNavigation, supportsTraffic, supportsLaneGuidance, supportsTrafficLight, supportsTrafficLightState, supportsTrafficLightCountdown, supportsSpeedLimit, supportsCamera, supportsRoadEvents, supportsVoiceGuidance, supportsRerouting }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        supportsSearch = try c.decodeIfPresent(Bool.self, forKey: .supportsSearch) ?? false
        supportsRoutePlanning = try c.decodeIfPresent(Bool.self, forKey: .supportsRoutePlanning) ?? false
        supportsTurnByTurn = try c.decodeIfPresent(Bool.self, forKey: .supportsTurnByTurn) ?? false
        supportsBackgroundNavigation = try c.decodeIfPresent(Bool.self, forKey: .supportsBackgroundNavigation) ?? false
        supportsTraffic = try c.decodeIfPresent(Bool.self, forKey: .supportsTraffic) ?? false
        supportsLaneGuidance = try c.decodeIfPresent(Bool.self, forKey: .supportsLaneGuidance) ?? false
        supportsTrafficLight = try c.decodeIfPresent(Bool.self, forKey: .supportsTrafficLight) ?? false
        supportsTrafficLightState = try c.decodeIfPresent(Bool.self, forKey: .supportsTrafficLightState) ?? false
        supportsTrafficLightCountdown = try c.decodeIfPresent(Bool.self, forKey: .supportsTrafficLightCountdown) ?? false
        supportsSpeedLimit = try c.decodeIfPresent(Bool.self, forKey: .supportsSpeedLimit) ?? false
        supportsCamera = try c.decodeIfPresent(Bool.self, forKey: .supportsCamera) ?? false
        supportsRoadEvents = try c.decodeIfPresent(Bool.self, forKey: .supportsRoadEvents) ?? false
        supportsVoiceGuidance = try c.decodeIfPresent(Bool.self, forKey: .supportsVoiceGuidance) ?? false
        supportsRerouting = try c.decodeIfPresent(Bool.self, forKey: .supportsRerouting) ?? false
    }
}

public struct NavigationSnapshot: Codable, Sendable, Equatable {
    public var version = 1
    public let sessionID: UUID
    public let sequence: UInt64
    public let timestamp: Date
    public let status: NavigationStatus
    public let maneuver: Maneuver
    public let instruction: String
    public let currentRoad: String?
    public let nextRoad: String?
    public let distanceToManeuver: Double?
    public let remainingDistance: Double?
    public let remainingDuration: TimeInterval?
    public let eta: Date?
    public let routeProgress: Double?
    public let currentSpeed: Double?
    public let speedLimit: Double?
    public let traffic: TrafficState?
    public let trafficLight: TrafficLight?
    public let laneGuidance: LaneGuidance?
    public let camera: String?
    public let roadEvent: String?
    public let gpsAccuracy: Double?
    public let heading: Double?
    public let locationTimestamp: Date?
    public let watchConnectionState: WatchConnectionState
    public let capabilities: NavigationCapabilities
    // Additive version-1 fields; legacy camera/roadEvent strings remain decodable.
    public var cameraEvent: CameraEvent? = nil
    public var roadEventInfo: RoadEvent? = nil
    public var averageSpeedZone: AverageSpeedZone? = nil
    public var trafficLightInfo: TrafficLightInfo? = nil
    public var locationQuality: LocationQuality? = nil
    public var speedLimitInfo: SpeedLimitInfo? = nil
    public var navigationEvents: [NavigationEvent]? = nil

    public init(version: Int = 1,
                sessionID: UUID,
                sequence: UInt64,
                timestamp: Date,
                status: NavigationStatus,
                maneuver: Maneuver,
                instruction: String,
                currentRoad: String?,
                nextRoad: String?,
                distanceToManeuver: Double?,
                remainingDistance: Double?,
                remainingDuration: TimeInterval?,
                eta: Date?,
                routeProgress: Double?,
                currentSpeed: Double?,
                speedLimit: Double?,
                traffic: TrafficState?,
                trafficLight: TrafficLight?,
                laneGuidance: LaneGuidance?,
                camera: String?,
                roadEvent: String?,
                gpsAccuracy: Double?,
                heading: Double?,
                locationTimestamp: Date?,
                watchConnectionState: WatchConnectionState,
                capabilities: NavigationCapabilities,
                cameraEvent: CameraEvent? = nil,
                roadEventInfo: RoadEvent? = nil,
                averageSpeedZone: AverageSpeedZone? = nil,
                trafficLightInfo: TrafficLightInfo? = nil, locationQuality: LocationQuality? = nil,
                speedLimitInfo: SpeedLimitInfo? = nil, navigationEvents: [NavigationEvent]? = nil) {
        self.version = version
        self.sessionID = sessionID
        self.sequence = sequence
        self.timestamp = timestamp
        self.status = status
        self.maneuver = maneuver
        self.instruction = instruction
        self.currentRoad = currentRoad
        self.nextRoad = nextRoad
        self.distanceToManeuver = distanceToManeuver
        self.remainingDistance = remainingDistance
        self.remainingDuration = remainingDuration
        self.eta = eta
        self.routeProgress = routeProgress
        self.currentSpeed = currentSpeed
        self.speedLimit = speedLimit
        self.traffic = traffic
        self.trafficLight = trafficLight
        self.laneGuidance = laneGuidance
        self.camera = camera
        self.roadEvent = roadEvent
        self.gpsAccuracy = gpsAccuracy
        self.heading = heading
        self.locationTimestamp = locationTimestamp
        self.watchConnectionState = watchConnectionState
        self.capabilities = capabilities
        self.cameraEvent = cameraEvent
        self.roadEventInfo = roadEventInfo
        self.averageSpeedZone = averageSpeedZone
        self.trafficLightInfo = trafficLightInfo; self.locationQuality = locationQuality
        self.speedLimitInfo = speedLimitInfo; self.navigationEvents = navigationEvents
    }
    public func stopped() -> NavigationSnapshot {
        NavigationSnapshot(version: version, sessionID: sessionID, sequence: sequence + 1, timestamp: Date(),
            status: .stopped, maneuver: .unknown, instruction: "导航已结束", currentRoad: nil, nextRoad: nil,
            distanceToManeuver: nil, remainingDistance: nil, remainingDuration: nil, eta: nil,
            routeProgress: nil, currentSpeed: nil, speedLimit: nil, traffic: nil, trafficLight: nil,
            laneGuidance: nil, camera: nil, roadEvent: nil, gpsAccuracy: nil, heading: nil,
            locationTimestamp: nil, watchConnectionState: watchConnectionState, capabilities: capabilities)
    }
}

public struct NavigationPlace: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public var coordinateReference: CoordinateReference? = nil
    public var address: String? = nil
    public init(id: String, name: String, latitude: Double, longitude: Double, coordinateReference: CoordinateReference? = nil, address: String? = nil) {
        self.id = id; self.name = name; self.latitude = latitude; self.longitude = longitude
        self.coordinateReference = coordinateReference; self.address = address
    }
}
/// Route planning facts, separate from live navigation progress.
public struct RoutePlanningInfo: Codable, Sendable, Equatable {
    public let trafficLightCount: Int?
    public let usesHighway: Bool?
    public let estimatedTollYuan: Int?
    public let slowDistance: Double?
    public let congestedDistance: Double?
    public let severeDistance: Double?
    public let unknownTrafficDistance: Double?
    public init(trafficLightCount: Int?, usesHighway: Bool?, estimatedTollYuan: Int?,
                slowDistance: Double?, congestedDistance: Double?, severeDistance: Double?, unknownTrafficDistance: Double?) {
        self.trafficLightCount = trafficLightCount; self.usesHighway = usesHighway
        self.estimatedTollYuan = estimatedTollYuan; self.slowDistance = slowDistance
        self.congestedDistance = congestedDistance; self.severeDistance = severeDistance
        self.unknownTrafficDistance = unknownTrafficDistance
    }
}

public struct NavigationRoute: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let destination: NavigationPlace
    public let distance: Double
    public let duration: TimeInterval
    public var traffic: TrafficState? = nil
    public var planningInfo: RoutePlanningInfo? = nil
    public init(id: String, destination: NavigationPlace, distance: Double, duration: TimeInterval, traffic: TrafficState? = nil, planningInfo: RoutePlanningInfo? = nil) {
        self.id = id; self.destination = destination; self.distance = distance; self.duration = duration; self.traffic = traffic; self.planningInfo = planningInfo
    }
}
public enum NavigationError: String, Error, Codable, Sendable {
    case locationPermissionDenied, locationUnavailable, networkUnavailable, routeCalculationFailed
    case unsupportedOperation, providerUnavailable, providerAuthorizationFailed, watchDisconnected, staleNavigationData, gpsWeak, unknown
}

public enum WatchMessageType: String, Codable, Sendable { case navigationSnapshot, requestCurrentState, stopNavigation, connectionPing, connectionPong }
public struct NavigationMessageEnvelope: Codable, Sendable, Equatable {
    public let protocolVersion: Int
    public let type: WatchMessageType
    public let sessionID: UUID?
    public let sequence: UInt64?
    public let sentAt: Date
    public let snapshot: NavigationSnapshot?
    public init(type: WatchMessageType, snapshot: NavigationSnapshot? = nil) {
        protocolVersion = 1
        self.type = type
        sessionID = snapshot?.sessionID
        sequence = snapshot?.sequence
        sentAt = Date()
        self.snapshot = snapshot
    }
}


// Presentation helpers do not alter the version-1 Codable wire format.
extension LaneDirection {
    public var displaySymbol: String {
        switch self {
        case .straight: "↑"
        case .left: "←"
        case .right: "→"
        case .uTurn: "↩"
        case .straightLeft: "↑←"
        case .straightRight: "↑→"
        case .leftUTurn: "←↩"
        case .rightUTurn: "→↩"
        case .unknown: "?"
        }
    }
}
extension NavigationSnapshot {
    /// SDK show/hide controls lane lifetime; only show on Watch within 500 m.
    public var visibleLaneGuidance: LaneGuidance? {
        guard let laneGuidance, !laneGuidance.lanes.isEmpty,
              let distanceToManeuver, distanceToManeuver.isFinite,
              (0...500).contains(distanceToManeuver) else { return nil }
        return laneGuidance
    }
}
extension TrafficState {
    public var displayText: String? {
        let message: String
        switch status {
        case .unknown: return nil
        case .smooth: return "路况通畅"
        case .slow: message = "缓行"
        case .congested: message = "拥堵"
        case .severe: message = "严重拥堵"
        }
        if let congestionDistance, congestionDistance.isFinite, congestionDistance >= 0 {
            if congestionDistance == 0 { return "当前\(message)" }
            return String(format: "前方 %.1f km %@", congestionDistance / 1_000, message)
        }
        return "前方\(message)"
    }
}


public enum CameraType: String, Codable, Sendable { case speed, redLight, busLane, surveillance, intervalSpeed, other, unknown }
public enum IntervalSpeedBoundary: String, Codable, Sendable { case start, end }
public struct CameraEvent: Codable, Sendable, Equatable {
    public var id: String? = nil
    public let type: CameraType
    public let distance: Double?
    public let speedLimit: Int?
    public let intervalBoundary: IntervalSpeedBoundary?
    public let timestamp: Date
    public init(type: CameraType, distance: Double?, speedLimit: Int?, intervalBoundary: IntervalSpeedBoundary? = nil, timestamp: Date, id: String? = nil) {
        self.id = id; self.type = type; self.distance = distance; self.speedLimit = speedLimit
        self.intervalBoundary = intervalBoundary; self.timestamp = timestamp
    }
}
public struct AverageSpeedZone: Codable, Sendable, Equatable {
    public let remainingDistance: Double?
    public let zoneSpeedLimit: Int?
    public let currentAverageSpeed: Int?
    public let timestamp: Date
    public init(remainingDistance: Double?, zoneSpeedLimit: Int?, currentAverageSpeed: Int?, timestamp: Date) {
        self.remainingDistance = remainingDistance; self.zoneSpeedLimit = zoneSpeedLimit
        self.currentAverageSpeed = currentAverageSpeed; self.timestamp = timestamp
    }
}
public enum RoadEventType: String, Codable, Sendable { case accident, construction, closure, control, unknown }
public enum RoadEventSeverity: String, Codable, Sendable { case minor, major, unknown }
public struct RoadEvent: Codable, Sendable, Equatable {
    public var id: String? = nil
    public let type: RoadEventType
    public let distance: Double?
    public let description: String?
    public let severity: RoadEventSeverity?
    public let timestamp: Date
    public init(type: RoadEventType, distance: Double? = nil, description: String? = nil,
                severity: RoadEventSeverity? = nil, timestamp: Date, id: String? = nil) {
        self.id = id; self.type = type; self.distance = distance; self.description = description
        self.severity = severity; self.timestamp = timestamp
    }
}
extension CameraType {
    public var displayName: String {
        switch self {
        case .speed: "测速"
        case .redLight: "闯红灯拍照"
        case .busLane: "公交车道拍照"
        case .surveillance: "监控"
        case .intervalSpeed: "区间测速"
        case .other, .unknown: "电子眼"
        }
    }
}
extension RoadEventType {
    public var displayName: String {
        switch self {
        case .accident: "路线事故"
        case .construction: "路线施工"
        case .closure: "路线封路"
        case .control: "路线管制"
        case .unknown: "路线事件"
        }
    }
}
extension NavigationSnapshot {
    public func cameraDisplayText(at now: Date = Date()) -> String? {
        guard let cameraEvent, (0...90).contains(now.timeIntervalSince(cameraEvent.timestamp)),
              let distance = cameraEvent.distance, distance.isFinite, (0...500).contains(distance) else { return nil }
        let limit = cameraEvent.speedLimit.map { " \($0)" } ?? ""
        return "前方 \(Int(distance)) m \(cameraEvent.type.displayName)\(limit)"
    }
    /// A route incident has no SDK distance: never label it as a measured nearby warning.
    public func roadEventDisplayText(at now: Date = Date()) -> String? {
        guard let roadEventInfo, (0...90).contains(now.timeIntervalSince(roadEventInfo.timestamp)) else { return nil }
        return roadEventInfo.type.displayName
    }
    public var speedLimitDisplayText: String? {
        if let info = speedLimitInfo, !(0...90).contains(Date().timeIntervalSince(info.timestamp)) { return nil }
        guard let speedLimit, let limit = Int(exactly: speedLimit), limit > 0 else { return nil }
        return "限速 \(limit)"
    }
}

/// Presentation units shared by phone and Watch, without altering source measurements.
public enum NavigationUnits {
    public static func distance(_ meters: Double?) -> String {
        guard let meters, meters.isFinite, meters >= 0 else { return "—" }
        return meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1000)
    }
    public static func duration(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "—" }
        return "\(max(1, Int((seconds / 60).rounded(.up)))) min"
    }
}
