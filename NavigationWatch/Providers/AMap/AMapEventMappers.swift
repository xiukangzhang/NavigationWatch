import Foundation
import CryptoKit
#if SWIFT_PACKAGE
import NavigationWatchCore
#endif

/// Only scalar copies of public SDK fields cross the callback/actor boundary.
public enum AMapSpeedLimitMapper {
    public static func map(_ speed: Int) -> Double? { speed > 0 ? Double(speed) : nil }
}
public struct AMapCameraInput: Sendable {
    public let type: Int
    public let distance: Int
    public let speed: Int
    public let identity: String?
    public init(type: Int, distance: Int, speed: Int, identity: String? = nil) { self.type = type; self.distance = distance; self.speed = speed; self.identity = identity }
}
public enum AMapCameraMapper {
    public static func map(_ raw: AMapCameraInput, at date: Date) -> CameraEvent {
        let type: CameraType
        switch raw.type {
        case 0, 10: type = .speed
        case 1: type = .surveillance
        case 2: type = .redLight
        case 4: type = .busLane
        case 8, 9: type = .intervalSpeed
        case 3, 5, 6, 11: type = .other
        default: type = .unknown
        }
        return CameraEvent(type: type, distance: raw.distance >= 0 ? Double(raw.distance) : nil,
            speedLimit: raw.speed > 0 ? raw.speed : nil,
            intervalBoundary: raw.type == 8 ? .start : (raw.type == 9 ? .end : nil), timestamp: date, id: raw.identity)
    }
    public static func nearest(_ inputs: [AMapCameraInput], at date: Date) -> CameraEvent? {
        inputs.filter { $0.distance >= 0 }.min { $0.distance < $1.distance }.map { map($0, at: date) }
    }
    public static func zone(state: Int, remaining: Int?, average: Int?, limit: Int?, at date: Date) -> AverageSpeedZone? {
        guard state == 2 else { return nil } // public PositionStateIn only
        return AverageSpeedZone(remainingDistance: remaining.flatMap { $0 >= 0 ? Double($0) : nil },
            zoneSpeedLimit: limit.flatMap { $0 > 0 ? $0 : nil },
            currentAverageSpeed: average.flatMap { $0 >= 0 ? $0 : nil }, timestamp: date)
    }
}
public struct AMapRoadEventInput: Sendable {
    public let code: Int
    public let startSegment: Int
    public let startLink: Int
    public let endSegment: Int
    public let endLink: Int
    public init(code: Int, startSegment: Int, startLink: Int, endSegment: Int, endLink: Int) {
        self.code = code; self.startSegment = startSegment; self.startLink = startLink
        self.endSegment = endSegment; self.endLink = endLink
    }
}
public enum AMapRoadEventMapper {
    public static func map(code: Int, at date: Date) -> RoadEvent {
        let type: RoadEventType
        switch code {
        case 1: type = .accident
        case 2: type = .construction
        case 3: type = .closure
        case 4: type = .control
        default: type = .unknown
        }
        // API does not supply direct remaining distance, severity, or a reliable event description.
        return RoadEvent(type: type, timestamp: date)
    }
    public static func currentOrAhead(_ inputs: [AMapRoadEventInput], segment: Int, link: Int, at date: Date) -> RoadEvent? {
        guard segment >= 0, link >= 0 else { return nil }
        let valid = inputs.filter {
            $0.startSegment >= 0 && $0.startLink >= 0 && $0.endSegment >= $0.startSegment && $0.endLink >= 0 &&
            ($0.endSegment > $0.startSegment || $0.endLink >= $0.startLink) &&
            ($0.endSegment > segment || ($0.endSegment == segment && $0.endLink >= link))
        }.sorted { ($0.startSegment, $0.startLink) < ($1.startSegment, $1.startLink) }
        return valid.first.map { raw in
            var event = map(code: raw.code, at: date)
            event.id = "road:\(raw.code):\(raw.startSegment):\(raw.startLink):\(raw.endSegment):\(raw.endLink)"
            return event
        }
    }
}


public enum AMapTrafficLightMapper {
    public static func map(remainingCount: Int, at date: Date) -> TrafficLightInfo? {
        guard remainingCount >= 0 else { return nil }
        // Only routeRemainTrafficLightCount is consumed. No nearest-light distance/state/countdown API.
        return TrafficLightInfo(remainingCount: remainingCount, timestamp: date)
    }
}
public enum AMapGPSMapper {
    public static func signal(_ code: Int) -> GPSSignalQuality {
        switch code { case 1: .strong; case 2: .weak; case 3: .smartPositioning; default: .unknown }
    }
}
public enum AMapEventIdentity {
    public static func camera(type: Int, latitude: Double?, longitude: Double?, routeID: Int,
                              segment: Int, link: Int) -> String {
        let seed: String
        if let lat = latitude, let lon = longitude, lat.isFinite, lon.isFinite,
           (-90...90).contains(lat), (-180...180).contains(lon), lat != 0 || lon != 0 {
            // Hash before leaving Provider; never send coordinates to Shared/Watch/logs.
            seed = "\(routeID):\(type):\(Int((lat*1_000_000).rounded())):\(Int((lon*1_000_000).rounded()))"
        } else {
            // Conservative slot identity when SDK coordinate is absent. No random UUID/distance/time.
            seed = "\(routeID):\(type):slot:\(segment):\(link)"
        }
        return "camera:" + SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
