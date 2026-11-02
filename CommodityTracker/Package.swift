// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CommodityTracker",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Repository", targets: ["Repository"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "PriceListFeature", targets: ["PriceListFeature"]),
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "Networking", dependencies: ["Core"]),
        .target(name: "Repository", dependencies: ["Core"]),
        .target(name: "Persistence", dependencies: ["Core"]),
        .target(name: "PriceListFeature", dependencies: ["Core", "Repository"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "RepositoryTests", dependencies: ["Repository"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "Repository"]),
        .testTarget(name: "PriceListFeatureTests", dependencies: ["PriceListFeature"]),
    ]
)
