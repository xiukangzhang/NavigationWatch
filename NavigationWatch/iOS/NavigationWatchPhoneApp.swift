import SwiftUI
import CoreLocation
#if canImport(AMapNaviKit)
import AMapNaviKit
#endif

#if DEBUG
/// Short, local evidence for foreground/background navigation. Contains no coordinates or road names.
@MainActor enum NavigationSnapshotTrace {
    private static let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("navigation-snapshots.jsonl")
    private static var file: FileHandle?
    static var timeline = LocationPipelineTimeline()
    private static var pipelineSignature = ""
    private static var lastPipelineRecordAt = Date.distantPast
    static func pipeline(_ event: String, force: Bool = false) {
        let now = Date()
        let (freshness, reason) = timeline.diagnosis(at: now)
        let signature = "\(freshness.rawValue):\(reason.rawValue):\(timeline.boundary(at: now).rawValue):\(timeline.appLifecycleState):\(timeline.locationAuthorization)"
        guard force || signature != pipelineSignature || now.timeIntervalSince(lastPipelineRecordAt) >= 10 else { return }
        pipelineSignature = signature; lastPipelineRecordAt = now
        guard let data = try? JSONEncoder().encode(timeline),
              var details = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        details["freshness"] = freshness.rawValue; details["reason"] = reason.rawValue
        details["boundary"] = timeline.boundary(at: now).rawValue
        details["upstreamObservation"] = "independent one-shot CLLocation comparison; not SDK internal input"
        details["currentLocationAge"] = timeline.sourceLocationAt.map { now.timeIntervalSince($0) }
        details["rawLocationSource"] = ProcessInfo.processInfo.arguments.contains("-phase105-soak") ? "Debug fixture" : "AMapNaviLocation callback; underlying CoreLocation unobserved"
        details["dateEncoding"] = "seconds since 2001-01-01 UTC"
        record(event, details: details)
    }

    static func reset() {
        file?.closeFile()
        file = nil
        try? FileManager.default.removeItem(at: url)
        timeline = LocationPipelineTimeline()
        timeline.appLifecycleState = String(describing: UIApplication.shared.applicationState)
        pipelineSignature = ""; lastPipelineRecordAt = .distantPast
        record("start_requested")
    }

    static func record(_ event: String, snapshot: NavigationSnapshot? = nil, details: [String: Any] = [:]) {
        var value: [String: Any] = [
            "event": event,
            "recordedAt": ISO8601DateFormatter().string(from: Date()),
            "appState": String(describing: UIApplication.shared.applicationState)
        ]
        if let snapshot {
            value["sessionID"] = snapshot.sessionID.uuidString
            value["sequence"] = snapshot.sequence
            value["snapshotTimestamp"] = ISO8601DateFormatter().string(from: snapshot.timestamp)
            value["status"] = snapshot.status.rawValue
            value["remainingDistance"] = snapshot.remainingDistance
            value["remainingDuration"] = snapshot.remainingDuration
            value["instructionPresent"] = !snapshot.instruction.isEmpty
            value["speedLimitKph"] = snapshot.speedLimit
            value["cameraType"] = snapshot.cameraEvent?.type.rawValue
            value["cameraDistance"] = snapshot.cameraEvent?.distance
            value["roadEventType"] = snapshot.roadEventInfo?.type.rawValue
            value["locationQuality"] = snapshot.locationQuality?.state.rawValue
            value["trafficLightCount"] = snapshot.trafficLightInfo?.remainingCount
            value["cameraID"] = snapshot.cameraEvent?.id
            value["eventCount"] = snapshot.navigationEvents?.count
        }
        for (key, detail) in details { value[key] = detail }
        guard let line = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else { return }
        if file == nil {
            if !FileManager.default.fileExists(atPath: url.path) {
                _ = FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            file = try? FileHandle(forWritingTo: url)
        }
        guard let file else { return }
        _ = try? file.seekToEnd()
        try? file.write(contentsOf: line + Data([0x0A]))
        try? file.synchronize()
    }
}
#endif

@MainActor private final class NavigationLocationPermission: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requirePreciseLocation() async throws {
        if manager.authorizationStatus == .notDetermined {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        try validateAuthorization()
        resolveAuthorizationChange()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.resolveAuthorizationChange()
        }
    }

    #if DEBUG
    private var diagnosticBudget = LocationDiagnosticProbeBudget()
    private var diagnosticPending = false
    private var diagnosticTimeout: Task<Void, Never>?
    private var pipelineObserverTimeout: Task<Void, Never>?
    private var pipelineObserverActive = false
    func startDiagnosticWindow() {
        if ProcessInfo.processInfo.arguments.contains("-phase107-pipeline") {
            pipelineObserverActive = true
            NavigationPipelineRecorder.shared.update { $0.observerActive = true }
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.startUpdatingLocation()
            NavigationSnapshotTrace.record("pipeline_observer_started", details: ["limitSeconds": 180,
                "condition": "independent continuous observer may affect system location scheduling; no snapshot input"])
            pipelineObserverTimeout = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(180))
                guard !Task.isCancelled else { return }
                self?.stopDiagnosticWindow()
            }
        } else { diagnosticBudget.start(at: Date()) }
    }
    func sampleUpstreamIfNeeded(stale: Bool) {
        guard !pipelineObserverActive else { return }
        let now = Date()
        guard diagnosticBudget.take(at: now, stale: stale, pending: diagnosticPending) else { return }
        diagnosticPending = true
        NavigationSnapshotTrace.timeline.upstreamProbeRequestedAt = now
        NavigationSnapshotTrace.timeline.upstreamProbeErrorCode = nil
        NavigationSnapshotTrace.pipeline("upstream_probe_requested", force: true)
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestLocation()
        diagnosticTimeout = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, diagnosticPending else { return }
            manager.stopUpdatingLocation()
            finishDiagnosticProbe(source: nil, accuracy: nil, responseAt: Date(), errorCode: -106)
        }
    }
    func stopDiagnosticWindow() {
        if pipelineObserverActive {
            manager.stopUpdatingLocation(); pipelineObserverActive = false
            NavigationPipelineRecorder.shared.update { $0.observerActive = false }
            NavigationSnapshotTrace.record("pipeline_observer_stopped")
        }
        pipelineObserverTimeout?.cancel(); pipelineObserverTimeout = nil
        diagnosticBudget.stop(); diagnosticTimeout?.cancel(); diagnosticTimeout = nil
        if diagnosticPending { manager.stopUpdatingLocation() }
        diagnosticPending = false
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        NavigationPipelineRecorder.shared.observe(.coreLocation, source: locations.last?.timestamp,
            accuracy: locations.last?.horizontalAccuracy)
        let source = locations.last?.timestamp
        let accuracy = locations.last?.horizontalAccuracy
        let receivedAt = Date()
        Task { @MainActor [weak self] in
            self?.finishDiagnosticProbe(source: source, accuracy: accuracy, responseAt: receivedAt, errorCode: nil)
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code = (error as NSError).code
        let receivedAt = Date()
        Task { @MainActor [weak self] in
            self?.finishDiagnosticProbe(source: nil, accuracy: nil, responseAt: receivedAt, errorCode: code)
        }
    }
    private func finishDiagnosticProbe(source: Date?, accuracy: Double?, responseAt: Date, errorCode: Int?) {
        guard diagnosticPending else { return }
        diagnosticPending = false; diagnosticTimeout?.cancel(); diagnosticTimeout = nil
        NavigationSnapshotTrace.timeline.upstreamProbeCompletedAt = Date()
        NavigationSnapshotTrace.timeline.upstreamResponseAt = responseAt
        NavigationSnapshotTrace.timeline.upstreamSourceAt = source
        NavigationSnapshotTrace.timeline.upstreamAccuracy = accuracy
        NavigationSnapshotTrace.timeline.upstreamProbeErrorCode = errorCode
        NavigationSnapshotTrace.pipeline("upstream_probe_completed", force: true)
    }
    #endif

    private func resolveAuthorizationChange() {
        #if DEBUG
        switch manager.authorizationStatus {
        case .authorizedAlways: NavigationSnapshotTrace.timeline.locationAuthorization = "always"
        case .authorizedWhenInUse: NavigationSnapshotTrace.timeline.locationAuthorization = "whenInUse"
        case .restricted: NavigationSnapshotTrace.timeline.locationAuthorization = "restricted"
        case .denied: NavigationSnapshotTrace.timeline.locationAuthorization = "denied"
        default: NavigationSnapshotTrace.timeline.locationAuthorization = "notDetermined"
        }
        NavigationSnapshotTrace.pipeline("authorization_changed", force: true)
        #endif
        guard manager.authorizationStatus != .notDetermined,
              let continuation else { return }
        self.continuation = nil
        do {
            try validateAuthorization()
            continuation.resume()
        } catch {
            continuation.resume(throwing: error)
        }
    }

    private func validateAuthorization() throws {
        guard manager.authorizationStatus == .authorizedWhenInUse ||
              manager.authorizationStatus == .authorizedAlways else {
            throw AMapStartError.locationPermission
        }
        guard manager.accuracyAuthorization == .fullAccuracy else {
            throw AMapStartError.preciseLocation
        }
    }
}

private enum AMapStartError: LocalizedError {
    case locationPermission, preciseLocation
    var errorDescription: String? {
        switch self {
        case .locationPermission: "请在系统设置中允许 NavigationWatch 使用位置。"
        case .preciseLocation: "请在系统设置中为 NavigationWatch 开启精确位置。"
        }
    }
}

@MainActor final class PhoneModel: ObservableObject {
    @Published var snapshot: NavigationSnapshot?
    @Published var errorText: String?
    @Published var isStarting = false
    @Published var isNavigating = false
    #if DEBUG
    private let provider = MockNavigationProvider(totalTicks: ProcessInfo.processInfo.arguments.contains("-phase105-soak") ? 1200 : 360)
    private lazy var core = NavigationCore(provider: provider)
    #endif
    private let liveActivity = LiveActivityCoordinator(driver: ActivityKitNavigationDriver(),
        log: { LiveActivityDiagnostics.record($0, session: $1, activityID: $2) })
    let connectivity = WatchSyncCoordinator()
    @Published var searchResults: [NavigationPlace] = []
    @Published var routes: [NavigationRoute] = []
    @Published var isSearching = false
    @Published var privacyAccepted = false
    private let historyStore = DestinationHistoryStore()
    @Published private(set) var recentDestinations = DestinationHistoryStore().load()
    func deleteRecentDestination(_ id: String) { recentDestinations = historyStore.remove(id: id) }
    func clearRecentDestinations() { historyStore.clear(); recentDestinations = [] }
    private var destinationSearch: AMapDestinationSearch?
    private var searchTask: Task<Void, Never>?
    @Published var incomingShareText: String?
    @Published private(set) var importNotice: String?

    func receiveShareURL(_ url: URL) { incomingShareText = url.absoluteString }
    func importShare(_ text: String) async {
        guard !isNavigating, !isStarting, !isEnding, !isSearching else {
            errorText = "请先停止当前导航，或等待当前操作结束后再导入。"
            return
        }
        isSearching = true; errorText = nil; importNotice = nil
        do {
            let key = try configuredKey()
            let target = try await AMapShareResolver().resolve(text)
            let place: NavigationPlace
            switch target {
            case .destination(let value): place = value
            case .poiID(let id):
                if destinationSearch == nil { destinationSearch = try AMapDestinationSearch(apiKey: key, privacyAccepted: true) }
                guard let value = try await destinationSearch?.searchID(id).first else { throw AMapShareError.cannotResolve }
                place = value
            case .shortLink: throw AMapShareError.cannotResolve
            }
            try Task.checkCancellation()
            isSearching = false
            importNotice = "已导入：\(place.name)。从当前位置重新规划驾车路线，请确认后开始。"
            await plan(to: place)
        } catch {
            isSearching = false
            errorText = "无法导入高德链接：\(error.localizedDescription)"
        }
    }
    private var activeGeneration: UUID?
    @Published var isEnding = false
    private var activeCore: NavigationCore?
    private var amapProvider: AMapNavigationProvider?
    #if canImport(AMapNaviKit)
    func overviewRoute(for route: NavigationRoute) -> AMapNaviRoute? {
        guard privacyAccepted else { return nil }
        return amapProvider?.overviewRoute(for: route)
    }
    #endif
    private let locationPermission = NavigationLocationPermission()
    #if DEBUG
    @Published var pipelineDiagnostic: NavigationPipelineDiagnosticSnapshot?
    private var pipelineMonitor: Task<Void, Never>?
    private var lastPipelineDiagnosticTick: Double = -10
    private func monitorLocationPipeline() {
        pipelineMonitor?.cancel()
        pipelineMonitor = Task { @MainActor in
            while !Task.isCancelled {
                NavigationSnapshotTrace.timeline.lastCoreConsumedAt = activeCore?.diagnosticConsumedAt
                NavigationSnapshotTrace.timeline.coreConsumedSequence = activeCore?.diagnosticConsumedSequence
                NavigationSnapshotTrace.timeline.coreConsumedSessionID = activeCore?.diagnosticConsumedSessionID
                let freshness = NavigationSnapshotTrace.timeline.diagnosis(at: Date()).0
                if amapProvider?.navigationStatus == .navigating {
                    locationPermission.sampleUpstreamIfNeeded(stale: freshness == .stale || freshness == .unavailable)
                }
                NavigationSnapshotTrace.pipeline("location_pipeline")
                if amapProvider?.navigationStatus == .navigating {
                    amapProvider?.refreshPipelineSDKContext()
                    let data = connectivity.diagnostics
                    // Compare the freshness actually displayed from the current snapshot source.
                    let displayed = NavigationFreshnessPolicy.standard.classify(source: snapshot?.locationQuality?.locationTimestamp,
                        available: snapshot?.locationQuality?.providerAvailable == true, at: Date())
                    let result = NavigationPipelineRecorder.shared.diagnostic(freshness: displayed,
                        lifecycle: NavigationSnapshotTrace.timeline.appLifecycleState,
                        authorization: NavigationSnapshotTrace.timeline.locationAuthorization,
                        watchConnectivity: "\(data.activationState)/reachable=\(data.isReachable)",
                        gps: NavigationSnapshotTrace.timeline.gpsSignal?.rawValue ?? "unknown")
                    pipelineDiagnostic = result.1
                    let tick = NavigationPipelineRecorder.shared.tick()
                    if result.0 != nil || tick - lastPipelineDiagnosticTick >= 10 {
                        lastPipelineDiagnosticTick = tick
                        if let encoded = try? JSONEncoder().encode(result.1),
                           var fields = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] {
                            fields.removeValue(forKey: "recordedAt")
                            fields["dateEncoding"] = "seconds since 2001-01-01 UTC"
                            NavigationSnapshotTrace.record(result.0 ?? "pipeline_diagnostic", details: fields)
                        }
                    }
                } else { locationPermission.stopDiagnosticWindow() }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    #endif
    init() {
        connectivity.activate()
        connectivity.onStopRequest = { [weak self] in Task { await self?.stop() } }
        #if DEBUG
        core.onSnapshot = { [weak self] snapshot in
            NavigationDebugLog.event("GENERATE", "snapshot", session: snapshot.sessionID, sequence: snapshot.sequence)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-phase105-soak") {
                let now = Date(); let phase = snapshot.sequence % 120
                NavigationSnapshotTrace.timeline.navigationProviderState = "navigating"
                NavigationSnapshotTrace.timeline.locationAuthorization = "fixture"
                if !(20..<40).contains(phase) { NavigationSnapshotTrace.timeline.lastRawLocationAt = now }
                if !(60..<80).contains(phase) { NavigationSnapshotTrace.timeline.lastAMapNavigationCallbackAt = now }
                NavigationSnapshotTrace.timeline.sourceLocationAt = snapshot.locationQuality?.locationTimestamp
                NavigationSnapshotTrace.timeline.currentHorizontalAccuracy = snapshot.locationQuality?.accuracy
                NavigationSnapshotTrace.timeline.sampleAvailable = true
                NavigationSnapshotTrace.timeline.sessionID = snapshot.sessionID
                NavigationSnapshotTrace.timeline.sequence = snapshot.sequence
                NavigationSnapshotTrace.timeline.lastSnapshotGeneratedAt = now
                NavigationSnapshotTrace.timeline.lastSnapshotAppliedAt = now
                NavigationSnapshotTrace.record("fixture_snapshot", snapshot: snapshot)
                NavigationSnapshotTrace.pipeline("fixture_pipeline")
            }
            #endif
            self?.snapshot = snapshot
            self?.connectivity.publish(snapshot)
            self?.liveActivity.submit(snapshot)
        }
        #endif
    }
    #if DEBUG
    func start() async {
        guard !isStarting, !isNavigating else { return }
        isStarting = true
        defer { isStarting = false }
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-phase105-soak") {
                NavigationSnapshotTrace.reset(); monitorLocationPipeline()
            }
            #endif
            activeCore = core
            let destination = NavigationPlace(id: "demo", name: "模拟终点", latitude: 0, longitude: 0)
            guard let route = try await provider.calculateRoute(to: destination).first else { throw NavigationError.routeCalculationFailed }
            try await core.start(route: route)
            isNavigating = true
            liveActivity.enable()
            if let latest = activeCore?.latest { liveActivity.submit(latest) }
            errorText = nil
        } catch {
            activeCore = nil
            await liveActivity.end(reason: "provider_failure")
            errorText = "无法开始模拟导航：\(error.localizedDescription)"
        }
    }
    #endif
    private func configuredKey() throws -> String {
        guard privacyAccepted else { throw NavigationError.providerAuthorizationFailed }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "AMapAPIKey") as? String,
              !key.isEmpty, !key.contains("$(") else { throw NavigationError.providerAuthorizationFailed }
        return key
    }
    func searchDestination(_ query: String) {
        guard !isNavigating, !isStarting, !isEnding, !isSearching else { return }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true
        searchTask?.cancel()
        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            isSearching = true; errorText = nil; searchResults = []
            defer { isSearching = false }
            do {
                let key = try configuredKey()
                if destinationSearch == nil { destinationSearch = try AMapDestinationSearch(apiKey: key, privacyAccepted: true) }
                searchResults = try await destinationSearch!.search(query)
                if searchResults.isEmpty { errorText = "没有找到地点，请补充城市或更换关键词。" }
            } catch is CancellationError { }
            catch { errorText = "无法搜索目的地：\(error.localizedDescription)" }
        }
    }
    func plan(to destination: NavigationPlace) async {
        guard !isStarting, !isNavigating, !isEnding else { return }
        isStarting = true; errorText = nil; routes = []
        defer { isStarting = false }
        do {
            let key = try configuredKey()
            try await locationPermission.requirePreciseLocation()
            await amapProvider?.stopNavigation()
            let provider = try AMapNavigationProvider(apiKey: key, privacyAccepted: true)
            amapProvider = provider
            provider.onNavigationError = { [weak self] text in self?.errorText = text }
            provider.onFatalError = { [weak self] text in
                Task { @MainActor [weak self] in
                    await self?.finish(reason: "fatal_error")
                    self?.errorText = text
                }
            }
            routes = try await provider.calculateRoute(to: destination)
            guard !routes.isEmpty else { throw NavigationError.routeCalculationFailed }
            recentDestinations = historyStore.record(destination)
        } catch {
            await amapProvider?.stopNavigation(); amapProvider = nil
            errorText = "无法规划路线：\(error.localizedDescription)"
        }
    }
    func begin(route: NavigationRoute) async {
        guard !isStarting, !isNavigating, !isEnding, let provider = amapProvider, routes.contains(route) else { return }
        isStarting = true
        defer { isStarting = false }
        #if DEBUG
        NavigationSnapshotTrace.reset()
        #endif
        let generation = UUID()
        activeGeneration = generation
        let core = NavigationCore(provider: provider)
        core.onSnapshot = { [weak self] snapshot in
            guard let self, activeGeneration == generation, !isEnding else { return }
            self.snapshot = snapshot
            connectivity.publish(snapshot)
            liveActivity.submit(snapshot)
            #if DEBUG
            NavigationSnapshotTrace.timeline.lastSnapshotAppliedAt = Date()
            NavigationSnapshotTrace.record("snapshot", snapshot: snapshot)
            NavigationSnapshotTrace.pipeline("snapshot_applied")
            #endif
            if snapshot.status == .arrived || snapshot.status == .stopped || snapshot.status == .idle {
                Task { @MainActor [weak self] in await self?.finish(reason: snapshot.status.rawValue) }
            }
        }
        activeCore = core
        do {
            try await core.start(route: route)
            isNavigating = true; routes = []; searchResults = []
            liveActivity.enable()
            if let latest = core.latest { liveActivity.submit(latest) }
            #if DEBUG
            locationPermission.startDiagnosticWindow(); monitorLocationPipeline()
            NavigationSnapshotTrace.record("navigation_active")
            #endif
            errorText = nil
        } catch {
            await finish(reason: "start_failed")
            errorText = "无法开始导航：\(error.localizedDescription)"
        }
    }
    func clearRoutes() async {
        guard !isNavigating, !isStarting else { return }
        await amapProvider?.stopNavigation(); amapProvider = nil; routes = []
    }
    func stop() async { await finish(reason: "stop") }
    private func finish(reason: String) async {
        guard !isEnding else { return }
        isEnding = true
        defer { isEnding = false }
        activeGeneration = nil // Reject queued snapshots before publishing a terminal state.
        searchTask?.cancel(); searchTask = nil
        destinationSearch?.cancel()
        #if DEBUG
        pipelineMonitor?.cancel(); pipelineMonitor = nil
        locationPermission.stopDiagnosticWindow()
        NavigationSnapshotTrace.timeline.navigationProviderState = "stopped"
        NavigationSnapshotTrace.record("stop_requested")
        #endif
        if let snapshot { connectivity.publish(snapshot.stopped()) }
        await liveActivity.end(reason: reason)
        if let activeCore { await activeCore.stop() }
        else { await amapProvider?.stopNavigation() }
        activeCore = nil; amapProvider = nil
        snapshot = nil; routes = []; isNavigating = false; importNotice = nil
        #if DEBUG
        NavigationSnapshotTrace.record("stop_completed")
        #endif
    }
    #if DEBUG
    func runOrderingProbe() async {
        await stop()
        let id = UUID()
        for sequence in [UInt64(100), 102, 101, 103] {
            guard connectivity.sendDiagnostic(debugSnapshot(id: id, sequence: sequence)) else {
                errorText = "Watch 不可达，请在两端打开 App 后重试"
                return
            }
            try? await Task.sleep(for: .milliseconds(750))
        }
    }
    func runSessionProbe() async {
        await stop()
        let old = UUID(), new = UUID()
        let values: [(UUID, UInt64)] = [(old, 100), (new, 1), (old, 101)]
        for (id, sequence) in values {
            guard connectivity.sendDiagnostic(debugSnapshot(id: id, sequence: sequence)) else {
                errorText = "Watch 不可达，请在两端打开 App 后重试"
                return
            }
            try? await Task.sleep(for: .milliseconds(750))
        }
    }
    private func debugSnapshot(id: UUID, sequence: UInt64) -> NavigationSnapshot {
        NavigationSnapshot(sessionID: id, sequence: sequence, timestamp: Date(), status: .navigating,
            maneuver: .right, instruction: "通信测试", currentRoad: nil, nextRoad: "测试道路",
            distanceToManeuver: 100, remainingDistance: 1_000, remainingDuration: 120,
            eta: Date().addingTimeInterval(120), routeProgress: nil, currentSpeed: nil, speedLimit: nil,
            traffic: nil, trafficLight: nil, laneGuidance: nil, camera: nil, roadEvent: nil,
            gpsAccuracy: nil, heading: nil, locationTimestamp: nil, watchConnectionState: .unknown,
            capabilities: NavigationCapabilities())
    }
    #endif
}

@main struct NavigationWatchPhoneApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = PhoneModel()
    @State private var selectedTab = 0
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                NavigationStack { PhoneHomeView(model: model) }
                    .tabItem { Label("首页", systemImage: "house.fill") }.tag(0)
                NavigationStack { NavigationSettingsView() }
                    .tabItem { Label("设置", systemImage: "gearshape.fill") }.tag(1)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tint(.blue)
                .onOpenURL { selectedTab = 0; model.receiveShareURL($0) }
                .onChange(of: scenePhase) { _, phase in
                    #if DEBUG
                    NavigationSnapshotTrace.timeline.appLifecycleState = String(describing: phase)
                    NavigationSnapshotTrace.timeline.lifecycleChangedAt = Date()
                    if model.isNavigating { NavigationSnapshotTrace.record("scene_\(phase)") }
                    #endif
                }
        }
    }
}

private enum HomeSheet: String, Identifiable { case importLink, consent; var id: String { rawValue } }
private struct PhoneHomeView: View {
    @ObservedObject var model: PhoneModel
    @State private var query = ""
    @State private var sheet: HomeSheet?
    @State private var shareText = ""
    @FocusState private var searchFocused: Bool
    @State private var historyExpanded = false
    @State private var overviewRoute: NavigationRoute?
    @State private var pendingHistoryPlace: NavigationPlace?
    var body: some View {
        List {
            if let snapshot = model.snapshot {
                Section {
                    PhoneNavigationView(snapshot: snapshot)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.white)
                        .listRowSeparator(.hidden)
                }
            } else if model.isNavigating {
                Section { Label("正在等待导航定位", systemImage: "location.north.line").frame(maxWidth: .infinity) }
            } else if !model.routes.isEmpty {
                Section("选择驾车路线") {
                    ForEach(model.routes) { route in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(route.destination.name).font(.headline)
                            HStack {
                                Text(NavigationUnits.distance(route.distance))
                                Text(NavigationUnits.duration(route.duration))
                            }.font(.title3.monospacedDigit())
                            RoutePlanningDetails(route: route)
                            Button { overviewRoute = route } label: {
                                Label("查看全程路线图", systemImage: "map")
                            }.accessibilityIdentifier("route-overview")
                            Button("开始导航") { Task { await model.begin(route: route) } }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("start-navigation")
                                .disabled(model.isStarting || model.isEnding)
                        }.padding(.vertical, 8)
                    }
                    Button("重新搜索") { Task { await model.clearRoutes() } }
                }
            } else {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.title3).foregroundStyle(.primary)
                            .accessibilityHidden(true)
                        TextField("搜索地点或地址", text: $query)
                            .font(.body).textFieldStyle(.plain)
                            .submitLabel(.search)
                            .accessibilityLabel("搜索目的地")
                            .accessibilityIdentifier("destination-query")
                            .focused($searchFocused)
                            .onSubmit { searchFocused = false; search() }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .listRowInsets(EdgeInsets(top: 68, leading: 20, bottom: 16, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    if searchFocused {
                    DisclosureGroup(isExpanded: $historyExpanded) {
                        if model.recentDestinations.isEmpty {
                            Text("暂无最近目的地").font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            ForEach(model.recentDestinations) { place in
                                HStack(alignment: .center, spacing: 12) {
                                    Button { selectRecent(place) } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(place.name).foregroundStyle(.primary)
                                            if let address = place.address, !address.isEmpty {
                                                Text(address).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }.buttonStyle(.plain).disabled(model.isStarting || model.isSearching)
                                    Button(role: .destructive) { model.deleteRecentDestination(place.id) } label: {
                                        Image(systemName: "trash").frame(minWidth: 44, minHeight: 44)
                                    }.buttonStyle(.borderless).accessibilityLabel("删除 \(place.name)")
                                }
                            }
                            Button("清空历史", role: .destructive) { model.clearRecentDestinations() }
                                .buttonStyle(.borderless)
                        }
                        Text("仅保存在本机，可删除；不保存行驶轨迹。")
                            .font(.caption).foregroundStyle(.secondary)
                    } label: {
                        Label("最近目的地（\(model.recentDestinations.count)）", systemImage: "clock")
                    }
                }
                    VStack(spacing: 24) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 44)).foregroundStyle(.blue)
                            .accessibilityHidden(true)
                        Button { pendingHistoryPlace = nil; sheet = .importLink } label: {
                            Text("导入高德链接").font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                        .disabled(model.isSearching || model.isStarting)
                    }
                    .padding(24).padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 12, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                if !model.searchResults.isEmpty {
                    Section("搜索结果") {
                        ForEach(model.searchResults) { place in
                            Button { Task { await model.plan(to: place) } } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.name).foregroundStyle(.primary)
                                    if let address = place.address, !address.isEmpty {
                                        Text(address).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }.padding(.vertical, 4)
                            }.disabled(model.isStarting)
                        }
                    }
                }
            }
            if let notice = model.importNotice { Section { Text(notice).font(.footnote).foregroundStyle(.secondary) } }
            if model.isSearching || model.isStarting { Section { ProgressView(model.isSearching ? "正在搜索" : "正在规划或启动路线") } }
            if let text = model.errorText { Section { Text(text).foregroundStyle(.red).accessibilityIdentifier("navigation-error") } }
            if model.isNavigating {
                Section {
                    Button("停止导航", role: .destructive) { Task { await model.stop() } }
                        .disabled(model.isEnding).accessibilityIdentifier("stop-navigation").frame(maxWidth: .infinity)
                }
            }
            #if DEBUG
            Section("开发工具") {
                Button("开始模拟导航") { Task { await model.start() } }.disabled(model.isNavigating || model.isStarting)
                NavigationLink("通信诊断") { PhoneDiagnosticsView(model: model, connectivity: model.connectivity) }
            }
            #endif
        }
        .navigationTitle(model.isNavigating ? "导航" : (model.routes.isEmpty ? "NavigationWatch" : "路线规划"))
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(BlankAreaKeyboardDismiss { searchFocused = false })
        .onChange(of: searchFocused) { _, focused in historyExpanded = focused }
        .background((model.isNavigating ? Color.white : Color(.systemGroupedBackground)).ignoresSafeArea())
        .preferredColorScheme(model.isNavigating ? .light : nil)
        .onChange(of: model.incomingShareText) { _, text in
            guard let text else { return }
            pendingHistoryPlace = nil; shareText = text; sheet = .importLink
            model.incomingShareText = nil
        }
        .sheet(item: $overviewRoute) { route in
            NavigationStack {
                #if canImport(AMapNaviKit)
                if let sdkRoute = model.overviewRoute(for: route) {
                    RouteOverviewScreen(route: route, sdkRoute: sdkRoute)
                } else {
                    ContentUnavailableView("路线图暂不可用", systemImage: "map", description: Text("请关闭后重新规划路线。"))
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { overviewRoute = nil } } }
                }
                #else
                ContentUnavailableView("地图组件不可用", systemImage: "map")
                #endif
            }
        }
        .sheet(item: $sheet) { selected in
            if selected == .importLink {
            NavigationStack {
                Form {
                    Section {
                        TextField("粘贴分享链接或分享文本", text: $shareText, axis: .vertical)
                            .lineLimit(3...6).textInputAutocapitalization(.never).autocorrectionDisabled()
                        PasteButton(payloadType: String.self) { values in shareText = values.joined(separator: "\n") }
                        Button("导入并规划路线") {
                            if model.privacyAccepted {
                                sheet = nil
                                Task { await model.importShare(shareText) }
                            } else { sheet = .consent }
                        }.buttonStyle(.borderedProminent)
                            .disabled(shareText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } header: { Text("高德地点或路线链接") } footer: {
                        Text("在高德中复制地点或驾车路线的分享链接。导入终点后从当前位置重新算路；不会自动开始或替换正在进行的导航。")
                    }
                }.navigationTitle("导入高德链接")
                    .toolbar { Button("取消") { sheet = nil; shareText = "" } }
            }
        }
            else {
            NavigationStack {
                List {
                    Section {
                        Text("搜索、路线规划、全程地图与导航使用高德SDK。搜索关键词会发送给高德；规划和导航会处理设备位置及高德服务所需的信息。导航状态通过系统连接同步到你的Apple Watch，并用于本地Live Activity。")
                        Text("本应用不提供账号、广告、云端历史或自有服务器。最近目的地仅在本机保存，可逐条删除或清空；应用Release不保存行驶轨迹。高德SDK的信息处理规则请阅读其隐私政策。")
                        Link("高德隐私政策", destination: URL(string: "https://lbs.amap.com/pages/privacy/")!)
                        Button("同意并继续") {
                            model.privacyAccepted = true; sheet = nil
                            if let place = pendingHistoryPlace {
                                pendingHistoryPlace = nil
                                Task { await model.plan(to: place) }
                            } else if !shareText.isEmpty { Task { await model.importShare(shareText) } }
                            else { model.searchDestination(query) }
                        }
                            .buttonStyle(.borderedProminent)
                    }
                }.navigationTitle("隐私说明")
                    .toolbar { Button("取消") { sheet = nil } }
            }
            }
        }
    }
    private func selectRecent(_ place: NavigationPlace) {
        searchFocused = false
        if model.privacyAccepted { Task { await model.plan(to: place) } }
        else { pendingHistoryPlace = place; shareText = ""; sheet = .consent }
    }
    private func search() {
        pendingHistoryPlace = nil
        shareText = ""
        if model.privacyAccepted { model.searchDestination(query) }
        else { sheet = .consent }
    }
}

/// Observe taps outside text editors without swallowing existing controls.
private struct BlankAreaKeyboardDismiss: UIViewRepresentable {
    let dismiss: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }
    func makeUIView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }
    func updateUIView(_ uiView: AttachmentView, context: Context) { context.coordinator.dismiss = dismiss }
    static func dismantleUIView(_ uiView: AttachmentView, coordinator: Coordinator) { coordinator.detach() }
    final class AttachmentView: UIView {
        weak var coordinator: Coordinator?
        override func didMoveToWindow() { super.didMoveToWindow(); coordinator?.attach(to: self) }
    }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var dismiss: () -> Void
        weak var attachment: UIView?
        weak var window: UIWindow?
        lazy var tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
        func attach(to view: UIView) {
            detach(); attachment = view; window = view.window
            tap.cancelsTouchesInView = false; tap.delegate = self
            window?.addGestureRecognizer(tap)
        }
        func detach() { window?.removeGestureRecognizer(tap); window = nil }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let attachment, attachment.window != nil,
                  attachment.bounds.contains(touch.location(in: attachment)) else { return false }
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView || current is UIControl || current.accessibilityTraits.contains(.button) { return false }
                view = current.superview
            }
            return true
        }
        @objc private func tapped() { DispatchQueue.main.async { [weak self] in self?.dismiss() } }
    }
}

private struct RoutePlanningDetails: View {
    let route: NavigationRoute
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let info = route.planningInfo {
                Text(info.trafficLightCount.map { "红绿灯 \($0) 个" } ?? "红绿灯数量未知")
                Text(info.usesHighway.map { $0 ? "经过高速" : "不经过高速" } ?? "是否经过高速未知")
                if info.usesHighway == true || (info.estimatedTollYuan ?? 0) > 0 {
                    Text(info.estimatedTollYuan.map { "预计通行费 ¥\($0)（以实际收费为准）" } ?? "预计通行费未知")
                }
                if let slow = info.slowDistance, let congested = info.congestedDistance, let severe = info.severeDistance {
                    if slow + congested + severe == 0 {
                        Text((info.unknownTrafficDistance ?? 0) > 0 ? "已知路段无拥堵，部分路况未知" : "路况畅通")
                    } else {
                        if slow > 0 { Text("缓行 \(NavigationUnits.distance(slow))") }
                        if congested > 0 { Text("拥堵 \(NavigationUnits.distance(congested))") }
                        if severe > 0 { Text("严重拥堵 \(NavigationUnits.distance(severe))") }
                        if (info.unknownTrafficDistance ?? 0) > 0 { Text("部分路段路况未知") }
                    }
                } else { Text("路况信息暂不可用") }
            } else {
                if let traffic = route.traffic?.displayText { Text(traffic) }
                Text("红绿灯、高速和预计费用信息暂不可用")
            }
        }.font(.subheadline).foregroundStyle(.secondary)
    }
}

private struct PhoneNavigationView: View {
    let snapshot: NavigationSnapshot
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let now = max(context.date, Date())
            if snapshot.reliableGuidance(at: now) {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemName: snapshot.maneuver.symbol).font(.largeTitle).foregroundStyle(.blue)
                        .accessibilityLabel(snapshot.instruction)
                    Text(NavigationUnits.distance(snapshot.distanceToManeuver))
                        .font(.largeTitle.bold().monospacedDigit())
                    Text(snapshot.instruction).font(.headline)
                    if let guidance = snapshot.visibleLaneGuidance {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(guidance.lanes, id: \.index) { lane in
                                    VStack { Text(lane.directions.map(\.displaySymbol).joined()); Text(lane.recommended ? "●" : "·") }
                                        .foregroundStyle(lane.recommended ? .blue : .secondary)
                                        .accessibilityLabel("车道 \(lane.index + 1)，\(lane.recommended ? "推荐" : "未推荐")")
                                }
                            }
                        }.defaultScrollAnchor(.center)
                    }
                    if let road = snapshot.nextRoad, !road.isEmpty { Text(road).font(.title3) }
                    if let event = snapshot.cameraDisplayText(at: now) ?? snapshot.roadEventDisplayText(at: now) { Text(event).font(.subheadline) }
                    if let traffic = snapshot.traffic?.displayText { Text(traffic).font(.subheadline).foregroundStyle(.secondary) }
                    VStack(spacing: 6) {
                        Text("剩余 \(NavigationUnits.distance(snapshot.remainingDistance))")
                        if let eta = snapshot.eta { Text("预计 \(eta.formatted(date: .omitted, time: .shortened)) 到达") }
                        else { Text(NavigationUnits.duration(snapshot.remainingDuration)) }
                    }.font(.subheadline.monospacedDigit())
                    if let road = snapshot.currentRoad, !road.isEmpty { Text("当前：\(road)").font(.footnote).foregroundStyle(.secondary) }
                    if let text = snapshot.speedLimitDisplayText { Text(text).font(.footnote).foregroundStyle(.secondary) }
                    if let text = snapshot.trafficLightDisplayText(at: now) { Text(text).font(.footnote).foregroundStyle(.secondary) }
                    if let warning = snapshot.locationWarning(at: now) { Text(warning).font(.footnote).foregroundStyle(.secondary) }
                    #if DEBUG
                    Text("序号 \(snapshot.sequence)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    #endif
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ContentUnavailableView(snapshot.locationWarning(at: now) ?? "导航信息暂未更新", systemImage: "location.slash",
                    description: Text("等待新的定位信息，旧转向和距离已隐藏"))
            }
        }
    }
}

private struct NavigationSettingsView: View {
    var body: some View {
        List {
            Section("关于") {
                LabeledContent("地图与导航数据", value: "高德地图")
                LabeledContent("版本", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                Text("仅用于辅助导航，请遵守交通规则并以实际道路标志为准。")
            }
            Section("隐私") {
                Text("位置用于路线规划、实时引导及锁屏后台导航；导航状态通过Apple系统连接同步到你的Watch。停止或到达后结束本次导航定位和Live Activity。")
                Text("本应用没有账号、广告、云端历史或自有服务器。最近目的地仅本机保存，可逐条删除或清空；Release不保存行驶轨迹。高德服务仍会处理完成服务所需的数据。")
                Link("高德隐私政策", destination: URL(string: "https://lbs.amap.com/pages/privacy/")!)
                Link("高德服务条款", destination: URL(string: "https://lbs.amap.com/pages/terms/")!)
            }
        }.navigationTitle("设置")
    }
}

#if DEBUG
private struct PhoneDiagnosticsView: View {
    @ObservedObject var model: PhoneModel
    @ObservedObject var connectivity: WatchSyncCoordinator
    var body: some View {
        List {
            let data = connectivity.diagnostics
            Section("Connection") {
                LabeledContent("Activation", value: data.activationState)
                LabeledContent("Reachable", value: data.isReachable ? "Yes" : "No")
                LabeledContent("Paired", value: data.isPaired == true ? "Yes" : "No")
                LabeledContent("Watch app installed", value: data.isWatchAppInstalled == true ? "Yes" : "No")
            }
            Section("Snapshot") {
                LabeledContent("Session", value: data.currentSessionID?.uuidString ?? "—")
                LabeledContent("Last sent sequence", value: data.lastSentSequence.map(String.init) ?? "—")
                LabeledContent("Sent count", value: String(data.sentCount))
                LabeledContent("Context", value: data.applicationContextAt?.formatted(date: .omitted, time: .standard) ?? "—")
                LabeledContent("Last pull", value: data.lastPullAt?.formatted(date: .omitted, time: .standard) ?? "—")
                LabeledContent("Last reconnect", value: data.lastReconnectAt?.formatted(date: .omitted, time: .standard) ?? "—")
            }
            if let pipeline = model.pipelineDiagnostic {
                Section("Pipeline · DEBUG") {
                    ForEach(["coreLocation", "amapLocation", "amapNavigation", "providerLocation", "providerNavigation", "providerSnapshot", "snapshot"], id: \.self) { layer in
                        LabeledContent(layer, value: "\(pipeline.ages[layer].map { String(format: "%.1fs", $0) } ?? "unknown") / #\(pipeline.checkpoints[layer]?.count ?? 0)")
                    }
                    LabeledContent("Classification", value: pipeline.classification.rawValue)
                    LabeledContent("Sequence", value: pipeline.sequence.map(String.init) ?? "unknown")
                    LabeledContent("Core observer", value: pipeline.observerActive ? "Active · 180s limit" : "Inactive")
                }
            }
            Section("Diagnostic probes") {
                Button("发送乱序 100 / 102 / 101 / 103") { Task { await model.runOrderingProbe() } }
                Button("发送旧会话 A / B / A") { Task { await model.runSessionProbe() } }
                Text("先停止模拟导航，并保持 Watch App 打开。观察 Watch 诊断页中的拒绝计数。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("通信诊断")
    }
}
#endif

extension Maneuver {
    var symbol: String {
        switch self {
        case .left, .slightLeft: "arrow.turn.up.left"
        case .right, .slightRight: "arrow.turn.up.right"
        case .uTurn: "arrow.uturn.up"
        case .arrive: "mappin.circle.fill"
        default: "arrow.up"
        }
    }
}

#if canImport(AMapNaviKit)
private struct RouteOverviewScreen: View {
    let route: NavigationRoute
    let sdkRoute: AMapNaviRoute
    @Environment(\.dismiss) private var dismiss
    @State private var resetCount = 0
    var body: some View {
        VStack(spacing: 0) {
            AMapRouteOverviewMap(route: sdkRoute, resetCount: resetCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("所选驾车路线的全程高德地图")
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(route.destination.name).font(.headline)
                    Text("全程 \(NavigationUnits.distance(route.distance)) · \(NavigationUnits.duration(route.duration))")
                        .font(.subheadline.monospacedDigit())
                    RoutePlanningDetails(route: route)
                    Text("蓝线为所选路线；底图路况由高德显示。可双指缩放、拖动查看。")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }.frame(maxHeight: 210)
        }
        .navigationTitle("全程路线图").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("全览") { resetCount += 1 } }
            ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
        }
    }
}

private struct AMapRouteOverviewMap: UIViewRepresentable {
    let route: AMapNaviRoute
    let resetCount: Int
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> OverviewMapView {
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
        let map = OverviewMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = false
        map.isShowTraffic = true
        let coordinates = route.routeCoordinates.map {
            CLLocationCoordinate2D(latitude: Double($0.latitude), longitude: Double($0.longitude))
        }
        guard coordinates.count >= 2, coordinates.allSatisfy(CLLocationCoordinate2DIsValid) else { return map }
        var points = coordinates
        let line = MAPolyline(coordinates: &points, count: UInt(points.count))!
        map.add(line)
        map.routeBounds = line.boundingMapRect
        let start = MAPointAnnotation(); start.coordinate = coordinates[0]; start.title = "起点"
        let end = MAPointAnnotation(); end.coordinate = coordinates[coordinates.count - 1]; end.title = "终点"
        map.addAnnotations([start, end])
        return map
    }
    func updateUIView(_ map: OverviewMapView, context: Context) {
        if context.coordinator.resetCount != resetCount {
            context.coordinator.resetCount = resetCount
            map.needsOverview = true; map.setNeedsLayout()
        }
    }
    static func dismantleUIView(_ map: OverviewMapView, coordinator: Coordinator) {
        map.showsUserLocation = false; map.delegate = nil
    }
    final class OverviewMapView: MAMapView {
        var routeBounds: MAMapRect?
        var needsOverview = true
        private var lastSize = CGSize.zero
        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.width > 0, bounds.height > 0, let routeBounds,
                  needsOverview || lastSize != bounds.size else { return }
            lastSize = bounds.size; needsOverview = false
            setVisibleMapRect(routeBounds, edgePadding: UIEdgeInsets(top: 50, left: 36, bottom: 50, right: 36), animated: false)
        }
    }
    @MainActor final class Coordinator: NSObject, @preconcurrency MAMapViewDelegate {
        var resetCount = 0
        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            guard let line = overlay as? MAPolyline else { return nil }
            let renderer = MAPolylineRenderer(polyline: line)!
            renderer.strokeColor = .systemBlue; renderer.lineWidth = 6
            return renderer
        }
        func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
            guard annotation is MAPointAnnotation else { return nil }
            let view = MAPinAnnotationView(annotation: annotation, reuseIdentifier: "route-endpoint")!
            view.canShowCallout = true
            view.pinColor = annotation.title == "起点" ? .green : .red
            return view
        }
    }
}
#endif
