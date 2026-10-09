import SwiftUI
import WidgetKit

@main struct NavigationWatchApp: App {
    @StateObject private var connection = WatchConnectivityClient()
    @State private var navigationPath = NavigationPath()
    #if DEBUG
    @State private var fixtureStage = 0
    @State private var fixtureSessionID = UUID()
    #endif
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                ScrollView {
                    Group {
                    #if DEBUG
                    if let fixture = phase7Fixture {
                        WatchNavigationContent(state: fixture)
                    } else {
                        liveContent
                    }
                    #else
                    liveContent
                    #endif
                    }
                }
                #if DEBUG
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { WatchDiagnosticsView(connection: connection) } label: {
                            Image(systemName: "waveform.path.ecg")
                        }.accessibilityLabel("通信诊断")
                    }
                }
                #endif
                #if DEBUG
                .task {
                    guard ProcessInfo.processInfo.arguments.contains("-phase10-lifecycle") else { return }
                    for stage in 1...3 {
                        try? await Task.sleep(for: .seconds(8))
                        guard !Task.isCancelled else { return }
                        fixtureStage = stage
                        NavigationDebugLog.event("FIXTURE", "enrichment_stage", detail: "stage=\(stage) fixture_only")
                    }
                }
                #endif
                .onContinueUserActivity(NSUserActivityTypeLiveActivity) { _ in
                    navigationPath = NavigationPath()
                    NavigationDebugLog.event("LAUNCH", "live_activity_open", session: connection.snapshot?.sessionID,
                        sequence: connection.snapshot?.sequence, detail: "target=watch_navigation_root current_snapshot_only")
                    connection.resume()
                }
                .onAppear {
                    connection.sceneDidChange(String(describing: scenePhase))
                    connection.resume()
                }
                .onChange(of: scenePhase) { _, phase in
                    connection.sceneDidChange(String(describing: phase))
                    if phase == .active { connection.resume() }
                }
                .onChange(of: connection.snapshot) { _, value in
                    guard let value else { return }
                    Task { @MainActor in
                        await Task.yield()
                        connection.markUIApplied(value)
                    }
                }
            }
        }
    }

    private var liveContent: some View {
        VStack(spacing: 12) {
            if connection.isStale {
                ContentUnavailableView("导航信息暂未更新", systemImage: "arrow.triangle.2.circlepath",
                    description: Text(connection.diagnostics.isReachable
                        ? "等待 iPhone 的新引导，旧转向已隐藏。"
                        : "实时通道暂不可用，旧转向已隐藏；恢复后会拉取最新状态。"))
            } else if let state = connection.snapshot, state.status != .stopped {
                WatchNavigationContent(state: state)
            } else { Text("等待 iPhone 导航").font(.body).multilineTextAlignment(.center) }
            if let state = connection.snapshot, state.status != .stopped, state.status != .arrived, state.status != .idle {
                Button(role: .destructive) { connection.stopNavigation() } label: {
                    Label(connection.isStopping ? "正在停止…" : "停止导航", systemImage: "stop.circle")
                }
                .disabled(connection.isStopping)
                .accessibilityIdentifier("stop-navigation")
                if let error = connection.stopError { Text(error).font(.caption).multilineTextAlignment(.center) }
            }
        }
    }

    #if DEBUG
    private var phase7Fixture: NavigationSnapshot? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-phase10-lifecycle") { return enrichmentFixture(stage: fixtureStage, args: args) }
        if args.contains(where: { $0.hasPrefix("-phase10-") }) { return enrichmentFixture(stage: args.contains("-phase10-road") ? 2 : (args.contains("-phase10-empty") ? 3 : 0), args: args) }
        guard args.contains("-phase7-lanes") || args.contains("-phase7-no-lanes") || args.contains("-phase8-events") || args.contains("-phase8-empty") || args.contains("-phase8-road") else { return nil }
        let guidance = args.contains("-phase7-lanes")
            ? LaneGuidance(lanes: [
                Lane(index: 0, directions: [.straight], recommended: false, restricted: true, busOnly: false, variable: false),
                Lane(index: 1, directions: [.straight], recommended: false, restricted: true, busOnly: false, variable: false),
                Lane(index: 2, directions: [.straightRight], recommended: true, restricted: false, busOnly: false, variable: false),
                Lane(index: 3, directions: [.right], recommended: true, restricted: false, busOnly: false, variable: false)]) : nil
        var value = NavigationSnapshot(sessionID: UUID(), sequence: 1, timestamp: Date(), status: .navigating,
            maneuver: .right, instruction: "右转进入示例道路", currentRoad: nil, nextRoad: "示例道路",
            distanceToManeuver: 150, remainingDistance: 2400, remainingDuration: 360, eta: nil,
            routeProgress: nil, currentSpeed: nil, speedLimit: (args.contains("-phase8-events") || args.contains("-phase8-road")) ? 60 : nil,
            traffic: args.contains("-phase7-lanes") ? TrafficState(status: .congested,
                congestionDistance: nil, congestionLength: 1200, estimatedDelay: nil) : nil,
            trafficLight: nil, laneGuidance: guidance, camera: nil, roadEvent: nil, gpsAccuracy: nil,
            heading: nil, locationTimestamp: nil, watchConnectionState: .unknown, capabilities: NavigationCapabilities())
        if args.contains("-phase8-events") {
            value.cameraEvent = CameraEvent(type: .speed, distance: 450, speedLimit: 60, timestamp: Date())
            value.roadEventInfo = RoadEvent(type: .construction, timestamp: Date())
        }
        if args.contains("-phase8-road") {
            value.roadEventInfo = RoadEvent(type: .construction, timestamp: Date())
        }
        return value
    }
    private func enrichmentFixture(stage: Int, args: [String]) -> NavigationSnapshot {
        let now = Date()
        var snapshot = NavigationSnapshot(sessionID: fixtureSessionID, sequence: UInt64(stage+1), timestamp: now,
            status: .navigating, maneuver: .right, instruction: "右转进入示例道路", currentRoad: nil,
            nextRoad: "示例道路", distanceToManeuver: 150, remainingDistance: 2400, remainingDuration: 360,
            eta: nil, routeProgress: nil, currentSpeed: nil, speedLimit: nil, traffic: nil, trafficLight: nil,
            laneGuidance: LaneGuidance(lanes: [Lane(index: 0, directions: [.straight], recommended: false,
                restricted: false, busOnly: false, variable: false), Lane(index: 1, directions: [.right],
                recommended: true, restricted: false, busOnly: false, variable: false)]), camera: nil,
            roadEvent: nil, gpsAccuracy: nil, heading: nil, locationTimestamp: nil,
            watchConnectionState: .unknown, capabilities: NavigationCapabilities())
        snapshot.locationQuality = LocationQualityMapper.map(accuracy: 10,
            timestamp: args.contains("-phase10-stale") ? now.addingTimeInterval(-20) : now,
            gpsSignal: args.contains("-phase10-weak") ? .weak : .strong, providerAvailable: true,
            isNetworkPosition: false, isMatchedToRoute: true, at: now)
        if stage < 2 { snapshot.cameraEvent = CameraEvent(type: .speed, distance: stage == 0 ? 450 : 300,
            speedLimit: 60, timestamp: now, id: "fixture-camera") }
        if stage == 2 { snapshot.roadEventInfo = RoadEvent(type: .construction, timestamp: now, id: "fixture-road") }
        snapshot.trafficLightInfo = TrafficLightInfo(remainingCount: 3, timestamp: now)
        return snapshot
    }
    #endif
}

private struct WatchNavigationContent: View {
    let state: NavigationSnapshot
    @State private var displayClock = Date()
    var body: some View {
        let now = max(displayClock, Date())
        Group {
            if state.reliableGuidance(at: now) {
                content(at: now)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "location.slash").font(.title2).foregroundStyle(.secondary)
                    Text(state.locationWarning(at: now) ?? "定位暂不可用").font(.headline)
                    Text("等待新的定位信息").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: state.locationQuality?.effectiveState(at: now), initial: true) { _, quality in
            #if DEBUG
            let sourceAge = state.locationQuality?.locationTimestamp.map { now.timeIntervalSince($0) }
            NavigationDebugLog.event("LOCATION", "quality_display", session: state.sessionID,
                sequence: state.sequence, detail: "effective=\(quality?.rawValue ?? "unknown") source=\(state.locationQuality?.state.rawValue ?? "unknown") sourceAge=\(sourceAge.map { String(format: "%.2f", $0) } ?? "unknown") snapshotAge=\(String(format: "%.2f", now.timeIntervalSince(state.timestamp)))")
            #endif
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                displayClock = Date()
            }
        }
    }
    private func content(at now: Date) -> some View {
        VStack(spacing: 8) {
            Image(systemName: state.maneuver.symbol).font(.largeTitle).foregroundStyle(.blue)
            Text(NavigationUnits.distance(state.distanceToManeuver))
                .font(.title2.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.8)
            WatchRouteStrip(state: state)
            Text(state.nextRoad ?? state.instruction)
                .font(.body).lineLimit(2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let text = state.cameraDisplayText(at: now) ?? state.roadEventDisplayText(at: now) {
                Text(text).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("navigation-event-text")
            } else if let text = state.trafficLightDisplayText(at: now) {
                Text(text).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            if let limit = state.speedLimitDisplayText {
                Text(limit).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let traffic = state.traffic?.displayText {
                Text(traffic).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .overlay(alignment: .topTrailing) {
            WatchSignalBadge(quality: state.locationQuality, now: now)
                .padding(.top, 2).padding(.trailing, 2)
        }
    }
}

/// Symmetric side columns keep lane guidance centered, with units beneath each value.
private struct WatchRouteStrip: View {
    let state: NavigationSnapshot
    @ScaledMetric(relativeTo: .caption2) private var stripHeight: CGFloat = 40
    var body: some View {
        GeometryReader { geometry in
        let centerWidth = geometry.size.width * 0.5
        let sideWidth = max(0, (geometry.size.width - centerWidth - 8) / 2)
        HStack(spacing: 4) {
            WatchStackedMetric(text: NavigationUnits.distance(state.remainingDistance))
                .frame(width: sideWidth)
                .accessibilityLabel("剩余距离 \(NavigationUnits.distance(state.remainingDistance))")
            Group {
                if let guidance = state.visibleLaneGuidance {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(guidance.lanes, id: \.index) { lane in
                                VStack(spacing: 1) {
                                    Text(lane.directions.map(\.displaySymbol).joined()).font(.caption.bold())
                                    Text(lane.recommended ? "●" : "·").font(.caption2)
                                }
                                .foregroundStyle(lane.recommended ? .blue : .secondary)
                                .accessibilityLabel("车道 \(lane.index + 1)，\(lane.recommended ? "推荐" : "未推荐")")
                            }
                        }.frame(minWidth: centerWidth, alignment: .center)
                    }
                } else {
                    Color.clear.frame(height: 1).accessibilityHidden(true)
                }
            }
            .frame(width: centerWidth)
            WatchStackedMetric(text: NavigationUnits.duration(state.remainingDuration))
                .frame(width: sideWidth)
                .accessibilityLabel("剩余时间 \(NavigationUnits.duration(state.remainingDuration))")
        }
        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(height: stripHeight)
    }
}

/// Keep the existing distance/time formatting while laying its unit on a second line.
private struct WatchStackedMetric: View {
    let text: String
    var body: some View {
        let parts = text.split(separator: " ", maxSplits: 1)
        VStack(spacing: 1) {
            Text(parts.first.map(String.init) ?? "—")
                .font(.caption.bold().monospacedDigit())
            if parts.count > 1 {
                Text(String(parts[1])).font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

private struct WatchSignalBadge: View {
    let quality: LocationQuality?
    let now: Date
    private var presentation: (bars: Int, color: Color, label: String, statusSymbol: String?) {
        guard let quality else { return (0, .gray, "GPS信号未知", "questionmark") }
        switch quality.effectiveState(at: now) {
        case .stale: return (0, .gray, "定位信息暂未更新，信号强度无法确认", "clock")
        case .unavailable: return (0, .gray, "定位暂不可用", "location.slash")
        case .good, .weak: break
        }
        switch quality.gpsSignal {
        case .weak: return (1, .red, "GPS信号弱", nil)
        case .smartPositioning: return (2, .orange, "智能定位，定位质量中等", nil)
        case .strong:
            return quality.state == .good
                ? (3, .green, "GPS信号强", nil)
                : (2, .orange, "GPS有信号，定位质量中等", nil)
        case .unknown: return (0, .gray, "GPS信号未知", "questionmark")
        }
    }
    var body: some View {
        let value = presentation
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < value.bars ? value.color : Color.gray.opacity(0.35))
                    .frame(width: 3, height: CGFloat(4 + index * 4))
            }
            if let symbol = value.statusSymbol {
                Image(systemName: symbol).font(.system(size: 8))
                    .foregroundStyle(value.color)
            }
        }
        .frame(minWidth: 16, minHeight: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.label)
    }

}

#if DEBUG
private struct WatchDiagnosticsView: View {
    @ObservedObject var connection: WatchConnectivityClient
    var body: some View {
        let data = connection.diagnostics
        List {
            Section("Connection") {
                row("Reachable", data.isReachable ? "Yes" : "No")
                row("Activation", data.activationState)
                row("Paired", data.isPaired.map { $0 ? "Yes" : "No" } ?? "N/A")
                row("Watch installed", data.isWatchAppInstalled.map { $0 ? "Yes" : "No" } ?? "N/A")
            }
            Section("State") {
                row("Session", String(data.currentSessionID?.uuidString.prefix(8) ?? "—"))
                row("Sent", data.lastSentSequence.map(String.init) ?? "—")
                row("Received", data.lastReceivedSequence.map(String.init) ?? "—")
                row("Applied", data.lastAppliedSequence.map(String.init) ?? "—")
                row("Last update", age(data.lastMessageAt))
                row("Snapshot age", data.snapshotAge.map { String(format: "%.1f s", $0) } ?? "—")
            }
            Section("Events") {
                row("Received / Applied", "\(data.receivedCount) / \(data.appliedCount)")
                row("Duplicate", String(data.duplicateCount))
                row("Out of order", String(data.outOfOrderCount))
                row("Old session", String(data.oldSessionCount))
                row("Sequence gaps", String(data.sequenceGaps))
                row("Stale", String(data.staleCount))
                row("Context", age(data.applicationContextAt))
                row("Pull", age(data.lastPullAt))
                row("Reconnect", age(data.lastReconnectAt))
                row("Recovery", data.lastRecoveryDuration.map { String(format: "%.1f s", $0) } ?? "—")
            }
            Section("UI apply latency") {
                let metrics = data.applyLatency.summary
                row("Count", String(metrics.count))
                row("Median", duration(metrics.median))
                row("P95", duration(metrics.p95))
                row("P99", duration(metrics.p99))
                row("Max", duration(metrics.max))
            }
            Section("Receive latency") {
                let metrics = data.receiveLatency.summary
                row("Median", duration(metrics.median))
                row("P95", duration(metrics.p95))
                row("P99", duration(metrics.p99))
            }
        }
        .navigationTitle("通信诊断")
    }
    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit())
        }
    }
    private func age(_ date: Date?) -> String {
        date.map { String(format: "%.1f s", max(0, Date().timeIntervalSince($0))) } ?? "—"
    }
    private func duration(_ value: TimeInterval?) -> String {
        value.map { String(format: "%.0f ms", $0 * 1_000) } ?? "—"
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
