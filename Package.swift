// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NavigationWatchCore",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [.library(name: "NavigationWatchCore", targets: ["NavigationWatchCore"])],
    targets: [
        .target(name: "NavigationWatchCore", path: "NavigationWatch/Shared"),
        .target(name: "AMapMappers", dependencies: ["NavigationWatchCore"], path: "NavigationWatch/Providers/AMap", sources: ["AMapEventMappers.swift", "AMapSnapshotMapper.swift", "AMapNavigationProvider.swift", "AMapDestinationSearch.swift", "AMapShareLink.swift"]),
        .target(name: "DestinationHistory", dependencies: ["NavigationWatchCore"], path: "NavigationWatch/iOS", exclude: ["NavigationWatchPhoneApp.swift", "WatchSyncCoordinator.swift", "Info.plist", "PrivacyInfo.xcprivacy"], sources: ["DestinationHistoryStore.swift"]),
        .testTarget(name: "DestinationHistoryTests", dependencies: ["NavigationWatchCore", "DestinationHistory"], path: "HistoryTests"),
        .target(name: "AppleProvider", dependencies: ["NavigationWatchCore"], path: "NavigationWatch/Providers/Apple"),
        .testTarget(name: "ShareLinkTests", dependencies: ["NavigationWatchCore", "AMapMappers"], path: "ShareTests"),
        .testTarget(name: "ReleaseCandidateTests", dependencies: ["NavigationWatchCore", "AMapMappers"], path: "RCTests"),
        .testTarget(name: "ProviderContractTests", dependencies: ["NavigationWatchCore", "AMapMappers", "AppleProvider", "NavigationLiveActivity"], path: "ProviderTests"),
        .target(name: "NavigationLiveActivity", dependencies: ["NavigationWatchCore"], path: "NavigationWatch/LiveActivity"),
        .testTarget(name: "NavigationLiveActivityTests", dependencies: ["NavigationWatchCore", "NavigationLiveActivity"], path: "ActivityTests"),
        .testTarget(name: "NavigationWatchCoreTests", dependencies: ["NavigationWatchCore", "AMapMappers"], path: "Tests")
    ]
)
