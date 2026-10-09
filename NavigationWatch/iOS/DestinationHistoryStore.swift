import Foundation
#if SWIFT_PACKAGE
import NavigationWatchCore
#endif

/// Local destinations only: no sessions, timestamps, origin or traveled track.
final class DestinationHistoryStore {
    private let defaults: UserDefaults
    private let key = "navigationwatch.recentDestinations.v1"
    private let limit = 20

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> [NavigationPlace] {
        guard let data = defaults.data(forKey: key),
              let places = try? JSONDecoder().decode([NavigationPlace].self, from: data) else { return [] }
        return Array(places.filter(Self.isValid).prefix(limit))
    }

    func record(_ place: NavigationPlace) -> [NavigationPlace] {
        guard Self.isValid(place) else { return load() }
        var places = load().filter {
            !($0.id == place.id || ($0.name == place.name &&
                abs($0.latitude - place.latitude) < 0.00001 &&
                abs($0.longitude - place.longitude) < 0.00001))
        }
        places.insert(place, at: 0)
        places = Array(places.prefix(limit))
        save(places)
        return places
    }

    func remove(id: String) -> [NavigationPlace] {
        let places = load().filter { $0.id != id }
        save(places)
        return places
    }

    func clear() { defaults.removeObject(forKey: key) }

    private func save(_ places: [NavigationPlace]) {
        guard let data = try? JSONEncoder().encode(places) else { return }
        defaults.set(data, forKey: key)
    }

    private static func isValid(_ place: NavigationPlace) -> Bool {
        !place.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        place.latitude.isFinite && place.longitude.isFinite &&
        (-90...90).contains(place.latitude) && (-180...180).contains(place.longitude)
    }
}
