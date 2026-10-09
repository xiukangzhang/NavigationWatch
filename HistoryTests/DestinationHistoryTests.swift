import XCTest
import Foundation
import NavigationWatchCore
@testable import DestinationHistory

final class DestinationHistoryTests: XCTestCase {
    private func place(_ id: String, name: String? = nil) -> NavigationPlace {
        NavigationPlace(id: id, name: name ?? id, latitude: 31, longitude: 121, coordinateReference: .gcj02)
    }
    private func isolated(_ body: (UserDefaults) -> Void) {
        let suite = "NavigationWatchHistoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }
    func testDeletionAndClearSurviveReloadWithoutErasingOtherPreferences() {
        isolated { defaults in
            defaults.set(true, forKey: "unrelatedPreference")
            let store = DestinationHistoryStore(defaults: defaults)
            _ = store.record(place("a")); _ = store.record(place("b"))
            _ = store.remove(id: "a")
            XCTAssertEqual(DestinationHistoryStore(defaults: defaults).load().map(\.id), ["b"])
            store.clear()
            XCTAssertTrue(DestinationHistoryStore(defaults: defaults).load().isEmpty)
            XCTAssertTrue(defaults.bool(forKey: "unrelatedPreference"))
        }
    }
    func testBoundedHistoryDeduplicatesImportedDestinationWithNewID() {
        isolated { defaults in
            let store = DestinationHistoryStore(defaults: defaults)
            _ = store.record(place("old", name: "Library"))
            _ = store.record(place("import-new-id", name: "Library"))
            XCTAssertEqual(store.load().map(\.id), ["import-new-id"])
            for number in 0..<30 { _ = store.record(place("place\(number)")) }
            XCTAssertEqual(store.load().count, 20)
            XCTAssertEqual(store.load().first?.id, "place29")
        }
    }
    func testCorruptDataAndInvalidDestinationCannotBreakHome() {
        isolated { defaults in
            defaults.set(Data("broken".utf8), forKey: "navigationwatch.recentDestinations.v1")
            let store = DestinationHistoryStore(defaults: defaults)
            XCTAssertTrue(store.load().isEmpty)
            let invalid = NavigationPlace(id: "bad", name: "Bad", latitude: .nan, longitude: 121, coordinateReference: .gcj02)
            XCTAssertTrue(store.record(invalid).isEmpty)
            XCTAssertEqual(store.record(place("valid")).count, 1)
        }
    }
}
