import Foundation
#if SWIFT_PACKAGE
import NavigationWatchCore
#endif

#if canImport(AMapNaviKit) && canImport(AMapFoundationKit)
import AMapNaviKit
import AMapFoundationKit

private enum AMapRouteError: LocalizedError {
    case requestRejected, timedOut, missingSDKResources, sdk(Int)

    var errorDescription: String? {
        switch self {
        case .missingSDKResources: "高德导航资源缺失，请重新安装完整构建。"
        case .requestRejected: "高德未接受算路请求，请检查定位状态后重试。"
        case .timedOut: "高德算路超过 30 秒未返回，请检查网络后重试。"
        case .sdk(let code):
            switch code {
            case 2: "网络连接失败，请检查网络后重试。（高德错误码 2）"
            case 3, 10: "当前位置无法用于驾车算路，请确认已开启精确位置。（高德错误码 \(code)）"
            case 6, 11: "终点附近没有可用驾车道路，请换一个道路附近的终点。（高德错误码 \(code)）"
            case 3000: "请允许 App 使用位置后重试。（高德错误码 3000）"
            case 3001: "请开启精确位置后重试。（高德错误码 3001）"
            default: "高德算路失败，错误码 \(code)。"
            }
        }
    }
}

@MainActor final class AMapNavigationProvider: NSObject, NavigationProvider,
    AMapNaviDriveManagerDelegate, AMapNaviDriveDataRepresentable {
    static let sdkAvailable = true
    var capabilities: NavigationCapabilities { AMapCapabilityProfile.capabilities }
    private(set) var navigationStatus: NavigationStatus = .idle
    #if DEBUG
    nonisolated private let diagnosticOwner = UUID()
    #endif
    private let manager: AMapNaviDriveManager
    private let apiKey: String
    private var destinationSearch: AMapDestinationSearch?
    private var routeCatalog = AMapRouteCatalog()
    var onNavigationError: ((String) -> Void)?
    var onFatalError: ((String) -> Void)?
    private var continuation: AsyncStream<NavigationSnapshot>.Continuation?
    private var routeContinuation: CheckedContinuation<[NavigationRoute], Error>?
    private var routeRequestID: UUID?
    private var routeTimeoutTask: Task<Void, Never>?
    private var destination: NavigationPlace?
    private var sessionID = UUID()
    private var sequence: UInt64 = 0
    private var lanes: LaneGuidance?
    private var routeTraffic: TrafficState?
    private var congestionTraffic: TrafficState?
    private var lastFrame: AMapNavigationFrame?
    private var lastGuidanceAt: Date?
    private var cameraEvent: CameraEvent?
    private var averageSpeedZone: AverageSpeedZone?
    private var roadInputs: [AMapRoadEventInput] = []
    private var roadEventsAt: Date?
    private var currentSegment = -1
    private var currentLink = -1
    private var trafficLightInfo: TrafficLightInfo?
    private var locationQuality: LocationQuality?
    private var gpsSignal: GPSSignalQuality = .unknown
    private var speedLimitInfo: SpeedLimitInfo?
    private var eventLifecycle = NavigationEventLifecycle()
    private func clearPhase8() {
        cameraEvent = nil; averageSpeedZone = nil
        roadInputs = []; roadEventsAt = nil; currentSegment = -1; currentLink = -1
        trafficLightInfo = nil; speedLimitInfo = nil; eventLifecycle.reset()
    }

    init(apiKey: String, privacyAccepted: Bool) throws {
        guard !apiKey.isEmpty, privacyAccepted else { throw NavigationError.providerAuthorizationFailed }
        guard Bundle.main.url(forResource: "AMapNavi", withExtension: "bundle") != nil,
              Bundle.main.url(forResource: "AMap", withExtension: "bundle") != nil else {
            throw AMapRouteError.missingSDKResources
        }
        // AMap requires privacy state before the navigation manager singleton is created.
        let config = AMapNaviManagerConfig.shared()
        config.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        config.updatePrivacyAgree(.didAgree)
        AMapServices.shared().apiKey = apiKey
        self.apiKey = apiKey
        manager = AMapNaviDriveManager.sharedInstance()
        super.init()
        manager.delegate = self
        manager.addDataRepresentative(self)
    }

    func search(_ query: String) async throws -> [NavigationPlace] {
        if destinationSearch == nil { destinationSearch = try AMapDestinationSearch(apiKey: apiKey, privacyAccepted: true) }
        return try await destinationSearch!.search(query)
    }

    func calculateRoute(to destination: NavigationPlace) async throws -> [NavigationRoute] {
        guard (-90...90).contains(destination.latitude), (-180...180).contains(destination.longitude),
              routeContinuation == nil, navigationStatus != .navigating,
              destination.coordinateReference == nil || destination.coordinateReference == .gcj02 else { throw NavigationError.routeCalculationFailed }
        routeCatalog.reset()
        clearPhase8()
        self.destination = destination
        routeTraffic = nil
        congestionTraffic = nil
        lanes = nil
        lastFrame = nil
        lastGuidanceAt = nil
        let end = AMapNaviPOIInfo()
        end.locPoint = AMapNaviPoint.location(withLatitude: CGFloat(destination.latitude),
                                                longitude: CGFloat(destination.longitude))
        return try await withCheckedThrowingContinuation { continuation in
            routeContinuation = continuation
            let requestID = UUID()
            routeRequestID = requestID
            let accepted = manager.calculateDriveRoute(withStart: nil, end: end,
                wayPOIInfos: nil, drivingStrategy: AMapNaviDrivingStrategy(rawValue: 10)!)
            if !accepted {
                routeContinuation = nil
                routeRequestID = nil
                continuation.resume(throwing: AMapRouteError.requestRejected)
            } else {
                routeTimeoutTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(30))
                    guard routeRequestID == requestID, let pending = routeContinuation else { return }
                    routeTimeoutTask = nil
                    routeRequestID = nil
                    routeContinuation = nil
                    pending.resume(throwing: AMapRouteError.timedOut)
                }
            }
        }
    }

    func navigationUpdates() -> AsyncStream<NavigationSnapshot> {
        continuation?.finish()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.continuation = continuation
        }
    }

    /// Read-only preview lookup; never select a route or start navigation to display a map.
    func overviewRoute(for route: NavigationRoute) -> AMapNaviRoute? {
        guard navigationStatus != .navigating, let sdkID = routeCatalog.sdkID(for: route) else { return nil }
        return manager.naviRoutes?[NSNumber(value: sdkID)]
    }

    func startNavigation(route: NavigationRoute) async throws {
        guard navigationStatus != .navigating, let routeID = routeCatalog.sdkID(for: route),
              manager.selectNaviRoute(withRouteID: routeID) else { throw NavigationError.routeCalculationFailed }
        clearPhase8()
        sessionID = UUID()
        sequence = 0
        lanes = nil
        lastFrame = nil
        lastGuidanceAt = nil
        locationQuality = nil; gpsSignal = .unknown
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        #if DEBUG
        NavigationPipelineRecorder.shared.begin(owner: diagnosticOwner, session: sessionID)
        #endif
        guard manager.startGPSNavi() else {
            #if DEBUG
            NavigationPipelineRecorder.shared.update(owner: diagnosticOwner) { $0.navigationActive = false }
            #endif
            manager.allowsBackgroundLocationUpdates = false
            manager.pausesLocationUpdatesAutomatically = true
            throw NavigationError.providerUnavailable
        }
        navigationStatus = .navigating
        #if DEBUG
        NavigationSnapshotTrace.timeline.navigationProviderState = navigationStatus.rawValue
        #endif
    }

    func stopNavigation() async {
        destinationSearch?.cancel(); destinationSearch = nil
        routeCatalog.reset()
        routeTimeoutTask?.cancel()
        routeTimeoutTask = nil
        clearPhase8()
        #if DEBUG
        NavigationPipelineRecorder.shared.update(owner: diagnosticOwner) { $0.navigationActive = false; $0.sdkState = "stopNavi requested" }
        #endif
        manager.stopNavi()
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.removeDataRepresentative(self)
        manager.delegate = nil
        navigationStatus = .stopped
        #if DEBUG
        NavigationSnapshotTrace.timeline.navigationProviderState = navigationStatus.rawValue
        #endif
        locationQuality = nil; gpsSignal = .unknown
        lanes = nil
        routeTraffic = nil
        congestionTraffic = nil
        lastFrame = nil
        lastGuidanceAt = nil
        continuation?.finish()
        continuation = nil
        if let routeContinuation {
            self.routeContinuation = nil
            routeRequestID = nil
            routeContinuation.resume(throwing: NavigationError.routeCalculationFailed)
        }
        _ = AMapNaviDriveManager.destroyInstance()
    }

    func pauseNavigation() async throws { throw NavigationError.providerUnavailable }
    func resumeNavigation() async throws { throw NavigationError.providerUnavailable }
    func reroute() async throws { throw NavigationError.providerUnavailable }

    #if DEBUG
    func refreshPipelineSDKContext() {
        NavigationPipelineRecorder.shared.update(owner: diagnosticOwner) {
            $0.routeActive = manager.naviRoute != nil
            $0.sdkState = "naviMode=\(manager.naviMode.rawValue); delegateAttached=\(manager.delegate === self)"
            $0.sdkBackgroundLocation = manager.allowsBackgroundLocationUpdates
            $0.sdkAutomaticPause = manager.pausesLocationUpdatesAutomatically
        }
    }
    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager, didStartNavi mode: AMapNaviMode) {
        NavigationPipelineRecorder.shared.observe(.amapStatus, owner: diagnosticOwner)
        let state = "didStartNavi=\(mode.rawValue)"
        NavigationPipelineRecorder.shared.update(owner: diagnosticOwner) { $0.sdkState = state }
    }
    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager, didStopNavi stopped: Bool) {
        NavigationPipelineRecorder.shared.observe(.amapStatus, owner: diagnosticOwner)
        NavigationPipelineRecorder.shared.update(owner: diagnosticOwner) { $0.sdkState = "didStopNavi=\(stopped)" }
    }
    #endif

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager, error: Error) {
        #if DEBUG
        NavigationPipelineRecorder.shared.observe(.amapStatus, owner: diagnosticOwner)
        #endif
        let code = (error as NSError).code
        Task { @MainActor in
            if navigationStatus == .navigating && manager.naviMode == .none {
                onFatalError?("导航服务已结束，请重新规划路线。（高德错误码 \(code)）")
            } else {
                onNavigationError?("导航服务暂时异常，请留意道路情况。（高德错误码 \(code)）")
            }
            #if DEBUG
            NavigationSnapshotTrace.record("sdk_internal_error", details: ["code": code, "providerState": navigationStatus.rawValue])
            NavigationSnapshotTrace.pipeline("sdk_error_timeline", force: true)
            #endif
        }
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager,
                                  onCalculateRouteSuccessWith type: AMapNaviRoutePlanType) {
        #if DEBUG
        NavigationPipelineRecorder.shared.observe(.amapStatus, owner: diagnosticOwner)
        #endif
        Task { @MainActor in
            guard let continuation = routeContinuation, let destination else { return }
            routeTimeoutTask?.cancel()
            routeTimeoutTask = nil
            routeContinuation = nil
            routeRequestID = nil
            routeCatalog.reset()
            for (id, route) in (manager.naviRoutes ?? [:]).sorted(by: { $0.key.intValue < $1.key.intValue }) {
                let traffic = AMapTrafficMapper.route(statusCodes: (route.routeTrafficStatuses ?? []).map { $0.status.rawValue })
                let planningInfo = AMapRoutePlanningMapper.map(
                    trafficLightCount: route.routeTrafficLightCount, tollYuan: route.routeTollCost,
                    roadClassCodes: route.routeSegments.flatMap { $0.links }.map { $0.roadClass.rawValue },
                    trafficSegments: (route.routeTrafficStatuses ?? []).map { (status: $0.status.rawValue, length: Double($0.length)) }, routeLength: Double(route.routeLength))
                routeCatalog.append(sdkID: id.intValue, distance: Double(route.routeLength), duration: Double(route.routeTime),
                    destination: destination, traffic: traffic, planningInfo: planningInfo)
            }
            guard !routeCatalog.routes.isEmpty else { continuation.resume(throwing: NavigationError.routeCalculationFailed); return }
            continuation.resume(returning: routeCatalog.routes)
        }
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager,
                                  onCalculateRouteFailure error: Error) {
        #if DEBUG
        NavigationPipelineRecorder.shared.observe(.amapStatus, owner: diagnosticOwner)
        #endif
        Task { @MainActor in
            guard let continuation = routeContinuation else {
                if navigationStatus == .navigating { onNavigationError?("路线重新计算失败，当前引导可能暂未更新，请留意道路情况。") }
                return
            }
            routeTimeoutTask?.cancel()
            routeTimeoutTask = nil
            routeContinuation = nil
            routeRequestID = nil
            continuation.resume(throwing: AMapRouteError.sdk((error as NSError).code))
        }
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager,
                                  onCalculateRouteFailure error: Error,
                                  routePlanType type: AMapNaviRoutePlanType) {
        self.driveManager(driveManager, onCalculateRouteFailure: error)
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager,
                                  update naviInfo: AMapNaviInfo?) {
        #if DEBUG
        NavigationPipelineRecorder.shared.observe(.amapNavigation, owner: diagnosticOwner)
        #endif
        #if DEBUG
        let hasInfo = naviInfo != nil
        NavigationPipelineRecorder.shared.update(owner: diagnosticOwner) { $0.rawNavigationHasData = hasInfo }
        Task { @MainActor in
            NavigationSnapshotTrace.record(hasInfo ? "sdk_info_callback" : "sdk_info_nil")
        }
        #endif
        guard let naviInfo else { return }
        let frame = AMapNavigationFrame(maneuverCode: naviInfo.iconType.rawValue,
            currentRoad: naviInfo.currentRoadName, nextRoad: naviInfo.nextRoadName,
            distanceToManeuver: Double(naviInfo.segmentRemainDistance),
            remainingDistance: Double(naviInfo.routeRemainDistance),
            remainingDuration: Double(naviInfo.routeRemainTime))
        let lightCount = naviInfo.routeRemainTrafficLightCount
        let callbackAt = Date()
        let segment = naviInfo.currentSegmentIndex
        let link = naviInfo.currentLinkIndex
        Task { @MainActor in
            guard navigationStatus == .navigating else { return }
            #if DEBUG
            NavigationPipelineRecorder.shared.observe(.providerNavigation, owner: diagnosticOwner)
            #endif
            currentSegment = segment; currentLink = link
            lastFrame = frame
            lastGuidanceAt = callbackAt
            #if DEBUG
            NavigationSnapshotTrace.timeline.lastAMapNavigationCallbackAt = callbackAt
            #endif
            trafficLightInfo = AMapTrafficLightMapper.map(remainingCount: lightCount, at: callbackAt)
            publishCurrentFrame()
            if AMapSnapshotMapper.maneuver(for: frame.maneuverCode) == .arrive {
                navigationStatus = .arrived
                #if DEBUG
                NavigationSnapshotTrace.timeline.navigationProviderState = navigationStatus.rawValue
                NavigationSnapshotTrace.pipeline("provider_arrived", force: true)
                #endif
                #if DEBUG
        NavigationPipelineRecorder.shared.update(owner: diagnosticOwner) { $0.navigationActive = false; $0.sdkState = "stopNavi requested" }
        #endif
        manager.stopNavi()
                manager.allowsBackgroundLocationUpdates = false
                manager.pausesLocationUpdatesAutomatically = true
                continuation?.finish()
            }
        }
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager,
                                  update naviLocation: AMapNaviLocation?) {
        #if DEBUG
        NavigationPipelineRecorder.shared.observe(.amapLocation, owner: diagnosticOwner, source: naviLocation?.timestamp as Date?, accuracy: naviLocation?.accuracy)
        #endif
        // Copy public scalar fields before hopping actors; no CLLocation/SDK object crosses.
        let accuracy = naviLocation?.accuracy
        let timestamp = naviLocation?.timestamp as Date?
        let available = naviLocation != nil
        let network = naviLocation?.isNetworkNavi ?? false
        let matched = naviLocation?.isMatchNaviPath ?? false
        let signal = AMapGPSMapper.signal(driveManager.gpsSignalStrength.rawValue)
        let receivedAt = Date()
        Task { @MainActor in
            guard navigationStatus == .navigating else { return }
            gpsSignal = signal
            #if DEBUG
            NavigationSnapshotTrace.timeline.observeLocation(source: timestamp, available: available,
                receivedAt: receivedAt, appliedAt: Date())
            NavigationSnapshotTrace.timeline.currentHorizontalAccuracy = accuracy
            NavigationSnapshotTrace.timeline.gpsSignal = signal
            NavigationSnapshotTrace.timeline.isNetworkPosition = network
            NavigationSnapshotTrace.timeline.isMatchedToRoute = matched
            NavigationSnapshotTrace.timeline.sdkPausesLocationAutomatically = manager.pausesLocationUpdatesAutomatically
            NavigationSnapshotTrace.timeline.sdkAllowsBackgroundLocation = manager.allowsBackgroundLocationUpdates
            NavigationSnapshotTrace.pipeline("raw_location_callback")
            #endif
            locationQuality = LocationQualityMapper.map(accuracy: accuracy, timestamp: timestamp,
                gpsSignal: signal, providerAvailable: available, isNetworkPosition: network,
                isMatchedToRoute: matched, at: receivedAt)
            #if DEBUG
            NavigationPipelineRecorder.shared.observe(.providerLocation, owner: diagnosticOwner)
            NavigationSnapshotTrace.record("location_quality", details: ["quality": locationQuality!.state.rawValue,
                "accuracy": accuracy as Any? ?? NSNull(), "gpsSignal": signal.rawValue,
                "isNetworkPosition": network, "isMatchedToRoute": matched,
                "sourceProgress": NavigationSnapshotTrace.timeline.sourceProgress ?? "unknown",
                "callbackQueueDelay": NavigationSnapshotTrace.timeline.callbackQueueDelay ?? -1,
                "sourceTimestamp": timestamp?.timeIntervalSince1970 as Any? ?? NSNull(),
                "pausesLocationAutomatically": manager.pausesLocationUpdatesAutomatically,
                "allowsBackgroundLocation": manager.allowsBackgroundLocationUpdates,
                "locationAge": timestamp.map { receivedAt.timeIntervalSince($0) } as Any? ?? NSNull()])
            #endif
            publishCurrentFrame()
        }
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager,
                                  update strength: AMapNaviGPSSignalStrength) {
        let signal = AMapGPSMapper.signal(strength.rawValue)
        Task { @MainActor in
            guard navigationStatus == .navigating else { return }
            gpsSignal = signal
            if let quality = locationQuality {
                locationQuality = LocationQualityMapper.map(accuracy: quality.accuracy, timestamp: quality.locationTimestamp,
                    gpsSignal: signal, providerAvailable: quality.providerAvailable,
                    isNetworkPosition: quality.isNetworkPosition, isMatchedToRoute: quality.isMatchedToRoute, at: Date())
            }
            publishCurrentFrame()
        }
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager, updateNaviRouteID naviRouteID: Int) {
        #if DEBUG
        NavigationPipelineRecorder.shared.observe(.amapStatus, owner: diagnosticOwner)
        #endif
        Task { @MainActor in
            clearPhase8()
            lanes = nil
            routeTraffic = nil
            congestionTraffic = nil
            // Require the new route's guidance before publishing supplementary data.
            lastFrame = nil
            lastGuidanceAt = nil
            #if DEBUG
            NavigationSnapshotTrace.record("route_auxiliary_reset")
            #endif
        }
    }

    /// Supplementary callbacks advance sequence but preserve guidance source age.
    private func publishCurrentFrame() {
        guard navigationStatus == .navigating, var frame = lastFrame, let lastGuidanceAt else { return }
        frame.lanes = lanes
        frame.traffic = congestionTraffic ?? routeTraffic
        frame.trafficLightInfo = trafficLightInfo
        frame.locationQuality = locationQuality
        frame.cameraEvent = cameraEvent
        frame.averageSpeedZone = averageSpeedZone
        frame.roadEventInfo = roadEventsAt.flatMap {
            AMapRoadEventMapper.currentOrAhead(roadInputs, segment: currentSegment, link: currentLink, at: $0)
        }
        if var road = frame.roadEventInfo {
            road.id = "route:\(manager.naviRouteID):\(road.id ?? road.type.rawValue)"
            frame.roadEventInfo = road
        }
        var candidates: [NavigationEventCandidate] = []
        if let camera = cameraEvent, let id = camera.id {
            candidates.append(.init(id: id, kind: .camera, timestamp: camera.timestamp,
                passed: (camera.distance ?? .infinity) <= 0))
        }
        if let road = frame.roadEventInfo, let id = road.id {
            candidates.append(.init(id: id, kind: .road, timestamp: road.timestamp))
        }
        if let speed = speedLimitInfo {
            candidates.append(.init(id: speed.id, kind: .speedLimit, timestamp: speed.timestamp))
        }
        let transitions = eventLifecycle.reconcile(candidates, at: Date())
        let activeIDs = Set(eventLifecycle.active.map(\.id))
        if let id = frame.cameraEvent?.id, !activeIDs.contains(id) { frame.cameraEvent = nil }
        if let id = frame.roadEventInfo?.id, !activeIDs.contains(id) { frame.roadEventInfo = nil }
        frame.speedLimitInfo = speedLimitInfo.flatMap { activeIDs.contains($0.id) ? $0 : nil }
        frame.speedLimit = frame.speedLimitInfo?.speedLimit
        frame.navigationEvents = eventLifecycle.active
        #if DEBUG
        for transition in transitions where transition.action != .updated {
            NavigationSnapshotTrace.record("event_\(transition.action.rawValue)", details: ["eventID": transition.id])
        }
        #endif
        let snapshot = AMapSnapshotMapper.snapshot(from: frame, sessionID: sessionID,
            sequence: sequence, at: lastGuidanceAt)
        #if DEBUG
        NavigationPipelineRecorder.shared.observe(.snapshot, owner: diagnosticOwner)
        NavigationPipelineRecorder.shared.update(owner: diagnosticOwner) { $0.sessionID = sessionID; $0.sequence = sequence
            $0.routeActive = manager.naviRoute != nil; $0.sdkState = "naviMode=\(manager.naviMode.rawValue)"
        }
        NavigationSnapshotTrace.timeline.lastSnapshotGeneratedAt = Date()
        NavigationSnapshotTrace.timeline.sessionID = sessionID
        NavigationSnapshotTrace.timeline.sequence = sequence
        NavigationSnapshotTrace.pipeline("snapshot_generated")
        #endif
        sequence += 1
        #if DEBUG
        let diagnosticYieldResult = continuation?.yield(snapshot)
        if let result = diagnosticYieldResult {
            switch result {
            case .enqueued, .dropped: NavigationPipelineRecorder.shared.observe(.providerSnapshot, owner: diagnosticOwner)
            case .terminated: NavigationSnapshotTrace.record("pipeline_stream_terminated")
            @unknown default: break
            }
        } else { NavigationSnapshotTrace.record("pipeline_stream_missing") }
        #else
        continuation?.yield(snapshot)
        #endif
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager,
                                  showLaneBackInfo laneBackInfo: String,
                                  laneSelectInfo: String) {
        let value = AMapLaneMapper.map(background: laneBackInfo, selected: laneSelectInfo)
        Task { @MainActor in
            guard navigationStatus == .navigating else { return }
            #if DEBUG
            NavigationSnapshotTrace.record("lane_raw", details: ["background": laneBackInfo, "selected": laneSelectInfo])
            NavigationSnapshotTrace.record("lane_mapped", details: ["laneCount": value?.lanes.count ?? 0,
                "recommendedLanes": value?.recommendedLanes ?? []])
            NavigationDebugLog.event("LANE", "mapped", detail: String(describing: value))
            #endif
            lanes = value
            publishCurrentFrame()
        }
    }

    nonisolated func driveManagerHideLaneInfo(_ driveManager: AMapNaviDriveManager) {
        Task { @MainActor in
            guard navigationStatus == .navigating else { return }
            lanes = nil
            #if DEBUG
            NavigationSnapshotTrace.record("lane_hidden")
            #endif
            publishCurrentFrame()
        }
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager,
                                  updateTrafficStatus trafficStatus: [AMapNaviTrafficStatus]?) {
        let codes = trafficStatus?.map { $0.status.rawValue } ?? []
        let mapped = AMapTrafficMapper.route(statusCodes: codes)
        Task { @MainActor in
            guard destination != nil, navigationStatus != .stopped else { return }
            #if DEBUG
            NavigationSnapshotTrace.record("traffic_raw", details: ["statusCodes": codes])
            NavigationSnapshotTrace.record("traffic_mapped", details: ["status": mapped?.status.rawValue ?? "nil"])
            NavigationDebugLog.event("TRAFFIC", "mapped", detail: String(describing: mapped))
            #endif
            routeTraffic = mapped
            publishCurrentFrame()
        }
    }

    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager,
                                  update congestionInfo: AMapNaviCongestionInfo?) {
        let code = congestionInfo?.status.rawValue
        let length = congestionInfo.map { Double($0.remainDistance) }
        let inArea = congestionInfo?.inCongestionArea ?? false
        let mapped = code.flatMap { code in length.map {
            AMapTrafficMapper.congestion(statusCode: code, remainingLength: $0, inArea: inArea)
        }}
        Task { @MainActor in
            guard destination != nil, navigationStatus != .stopped else { return }
            #if DEBUG
            NavigationSnapshotTrace.record("congestion_raw", details: ["statusCode": code ?? -1,
                "remainingLength": length ?? -1, "inArea": inArea])
            NavigationSnapshotTrace.record("congestion_mapped", details: ["status": mapped?.status.rawValue ?? "nil"])
            NavigationDebugLog.event("TRAFFIC", "congestion_mapped", detail: String(describing: mapped))
            #endif
            congestionTraffic = mapped // nil callback clears an obsolete congestion area.
            publishCurrentFrame()
        }
    }


    nonisolated func driveManager(_ manager: AMapNaviDriveManager?, onUpdateNaviSpeedLimitSection speed: Int) {
        let mapped = AMapSpeedLimitMapper.map(speed)
        Task { @MainActor in
            guard navigationStatus == .navigating else { return }
            #if DEBUG
            NavigationSnapshotTrace.record("speed_limit_raw", details: ["limitKph": speed])
            NavigationSnapshotTrace.record("speed_limit_mapped", details: ["limitKph": mapped as Any? ?? NSNull()])
            #endif
            speedLimitInfo = mapped.map { SpeedLimitInfo(id: "speed:\(self.manager.naviRouteID):\($0)", speedLimit: $0, timestamp: Date()) }
            publishCurrentFrame()
        }
    }
    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager, update infos: [AMapNaviCameraInfo]?) {
        let routeID = driveManager.naviRouteID
        let inputs = (infos ?? []).map { info in
            AMapCameraInput(type: info.cameraType.rawValue, distance: info.distance, speed: info.cameraSpeed,
                identity: AMapEventIdentity.camera(type: info.cameraType.rawValue,
                    latitude: Double(info.coordinate.latitude), longitude: Double(info.coordinate.longitude),
                    routeID: routeID, segment: -1, link: -1))
        }
        let date = Date()
        let mapped = AMapCameraMapper.nearest(inputs, at: date)
        Task { @MainActor in
            guard navigationStatus == .navigating else { return }
            #if DEBUG
            NavigationSnapshotTrace.record("camera_raw", details: ["items": inputs.map { ["type": $0.type, "distance": $0.distance, "limitKph": $0.speed] }])
            NavigationSnapshotTrace.record("camera_mapped", details: ["type": mapped?.type.rawValue ?? "none", "distance": mapped?.distance as Any? ?? NSNull()])
            #endif
            cameraEvent = mapped // Empty/nil callbacks remove passed cameras; identity survives distance changes.
            publishCurrentFrame()
        }
    }
    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager, updateIntervalCameraWith state: AMapNaviIntervalCameraPositionState,
                                   start startInfo: AMapNaviCameraInfo?, end endInfo: AMapNaviCameraInfo?) {
        let rawState = state.rawValue
        let mapped = AMapCameraMapper.zone(state: rawState, remaining: endInfo?.intervalCameraDynamicInfo?.remainDistance,
            average: endInfo?.intervalCameraDynamicInfo?.averageSpeed, limit: endInfo?.cameraSpeed, at: Date())
        Task { @MainActor in
            guard navigationStatus == .navigating else { return }
            #if DEBUG
            NavigationSnapshotTrace.record("average_speed_zone_raw", details: ["state": rawState])
            NavigationSnapshotTrace.record("average_speed_zone_mapped", details: ["present": mapped != nil])
            #endif
            averageSpeedZone = mapped
            publishCurrentFrame()
        }
    }
    nonisolated func driveManager(_ driveManager: AMapNaviDriveManager, updateTrafficEvents events: [AMapNaviRouteTrafficEventInfo]?) {
        let routeID = driveManager.naviRouteID
        let inputs = (events ?? []).filter { Int(exactly: $0.routeID) == routeID }.flatMap { $0.infoList ?? [] }.map {
            AMapRoadEventInput(code: $0.type.rawValue, startSegment: $0.startSegmentIndex, startLink: $0.startLinkIndex,
                endSegment: $0.endSegmentIndex, endLink: $0.endLinkIndex)
        }
        let date = Date()
        Task { @MainActor in
            guard navigationStatus == .navigating, manager.naviRouteID == routeID else { return }
            roadInputs = inputs; roadEventsAt = date
            #if DEBUG
            NavigationSnapshotTrace.record("road_event_raw", details: ["routeID": routeID, "codes": inputs.map(\.code)])
            let mapped = AMapRoadEventMapper.currentOrAhead(inputs, segment: currentSegment, link: currentLink, at: date)
            NavigationSnapshotTrace.record("road_event_mapped", details: ["type": mapped?.type.rawValue ?? "none"])
            #endif
            publishCurrentFrame()
        }
    }

    private static func parseCoordinate(_ value: String) -> (Double, Double)? {
        let parts = value.split(separator: ",")
        guard parts.count == 2, let latitude = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let longitude = Double(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return (latitude, longitude)
    }
}

#else

@MainActor final class AMapNavigationProvider: NavigationProvider {
    #if DEBUG
    func refreshPipelineSDKContext() {}
    #endif
    var onNavigationError: ((String) -> Void)?
    var onFatalError: ((String) -> Void)?
    static let sdkAvailable = false
    let capabilities = NavigationCapabilities()
    let navigationStatus: NavigationStatus = .idle
    init(apiKey: String, privacyAccepted: Bool) throws { throw NavigationError.providerUnavailable }
    func search(_ query: String) async throws -> [NavigationPlace] { throw NavigationError.providerUnavailable }
    func calculateRoute(to destination: NavigationPlace) async throws -> [NavigationRoute] { throw NavigationError.providerUnavailable }
    func startNavigation(route: NavigationRoute) async throws { throw NavigationError.providerUnavailable }
    func stopNavigation() async {}
    func pauseNavigation() async throws { throw NavigationError.providerUnavailable }
    func resumeNavigation() async throws { throw NavigationError.providerUnavailable }
    func reroute() async throws { throw NavigationError.providerUnavailable }
    func navigationUpdates() -> AsyncStream<NavigationSnapshot> { AsyncStream { $0.finish() } }
}

#endif
