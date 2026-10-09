#if canImport(ActivityKit) && os(iOS)
// SDK Activity is not Sendable; coordinator serializes all SDK calls on MainActor.
@preconcurrency import ActivityKit
import Foundation

@MainActor final class ActivityKitNavigationDriver: NavigationActivityDriver {
    private var activities: [String: Activity<NavigationActivityAttributes>] = [:]
    func start(session: UUID, state: NavigationActivityAttributes.ContentState, staleDate: Date) async throws -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw DriverError.disabled }
        let activity = try Activity.request(attributes: NavigationActivityAttributes(navigationSessionID: session),
            content: ActivityContent(state: state, staleDate: staleDate), pushType: nil)
        activities[activity.id] = activity
        return activity.id
    }
    func update(id: String, state: NavigationActivityAttributes.ContentState, staleDate: Date) async {
        guard let activity = activities[id], activity.activityState != .dismissed, activity.activityState != .ended else {
            // A user-dismissed activity is not recreated during the same navigation session.
            return
        }
        await activity.update(ActivityContent(state: state, staleDate: staleDate))
    }
    func end(id: String, reason: String) async {
        guard let activity = activities.removeValue(forKey: id) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }
    func endOrphans() async {
        for activity in Activity<NavigationActivityAttributes>.activities where activities[activity.id] == nil {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    private enum DriverError: Error { case disabled }
}

@MainActor enum LiveActivityDiagnostics {
    static func record(_ event: String, session: UUID?, activityID: String?) {
        #if DEBUG
        // No destination, road text, coordinates, or route in diagnostics.
        let value: [String: String] = ["event": event, "sessionID": session?.uuidString ?? "none",
            "activityID": activityID ?? "none", "recordedAt": ISO8601DateFormatter().string(from: Date())]
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("live-activity-diagnostics.jsonl")
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys) else { return }
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        if let file = try? FileHandle(forWritingTo: url) {
            defer { try? file.close() }
            try? file.seekToEnd(); try? file.write(contentsOf: data + Data([10]))
        }
        #endif
    }
}
#endif
