import ActivityKit
import SwiftUI
import WidgetKit

@main struct NavigationWidgets: WidgetBundle {
    var body: some Widget { NavigationLiveActivity() }
}

struct NavigationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NavigationActivityAttributes.self) { context in
            NavigationActivityView(state: context.state, stale: context.isStale)
                .activityBackgroundTint(Color(red: 0.10, green: 0.10, blue: 0.11))
                .activitySystemActionForegroundColor(.blue)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: ActivityPresentation.symbol(context.state, stale: context.isStale))
                        .font(.title).foregroundStyle(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(ActivityPresentation.distance(context.state, stale: context.isStale)).font(.title2).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(context.isStale ? "导航信息已过期" : (context.state.nextRoad ?? "正在导航"))
                            .font(.headline).lineLimit(1)
                        ActivitySummary(state: context.state, stale: context.isStale)
                    }
                }
            } compactLeading: {
                Image(systemName: ActivityPresentation.symbol(context.state, stale: context.isStale)).foregroundStyle(.blue)
            } compactTrailing: {
                Text(ActivityPresentation.distance(context.state, stale: context.isStale)).monospacedDigit()
            } minimal: {
                Image(systemName: ActivityPresentation.symbol(context.state, stale: context.isStale))
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

struct NavigationActivityView: View {
    @Environment(\.activityFamily) private var family
    let state: NavigationActivityAttributes.ContentState
    let stale: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: ActivityPresentation.symbol(state, stale: stale))
                    .font(family == .small ? .title2 : .largeTitle).foregroundStyle(.blue)
                    .accessibilityLabel("转向")
                VStack(alignment: .leading, spacing: 2) {
                    Text(ActivityPresentation.distance(state, stale: stale))
                        .font(family == .small ? .headline : .title).monospacedDigit()
                    Text(stale ? "导航信息已过期" : (state.nextRoad ?? "正在导航"))
                        .font(.subheadline).lineLimit(family == .small ? 1 : 2)
                }
            }
            ActivitySummary(state: state, stale: stale)
        }
        .padding(family == .small ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background(Color(red: 0.10, green: 0.10, blue: 0.11))
    }
}
struct ActivitySummary: View {
    let state: NavigationActivityAttributes.ContentState
    let stale: Bool
    var body: some View {
        if stale {
            Text("等待导航更新").font(.caption).foregroundStyle(Color.white.opacity(0.82))
        } else {
            HStack {
                if let distance = state.remainingDistance { Text(ActivityPresentation.distance(distance)) }
                if let duration = state.remainingDuration { Text("· \(Int(ceil(duration / 60))) 分钟") }
                if let eta = state.eta { Text(eta, style: .time) }
            }
            .font(.caption).foregroundStyle(Color.white.opacity(0.82)).monospacedDigit().lineLimit(1)
        }
    }
}
enum ActivityPresentation {
    static func symbol(_ state: NavigationActivityAttributes.ContentState, stale: Bool) -> String {
        guard !stale else { return "clock.badge.exclamationmark" }
        switch state.maneuver {
        case "left", "slightLeft": return "arrow.turn.up.left"
        case "right", "slightRight": return "arrow.turn.up.right"
        case "uTurn": return "arrow.uturn.down"
        case "arrive": return "flag.checkered"
        case "straight": return "arrow.up"
        default: return "location"
        }
    }
    static func distance(_ state: NavigationActivityAttributes.ContentState, stale: Bool) -> String {
        guard !stale, let value = state.distanceToManeuver else { return "—" }
        return distance(value)
    }
    static func distance(_ value: Double) -> String {
        value >= 1_000 ? String(format: "%.1f km", value / 1_000) : "\(Int(value.rounded())) m"
    }
}
