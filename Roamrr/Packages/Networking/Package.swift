// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Networking", targets: ["Networking"])],
    dependencies: [
        .package(path: "../Core"),
        .package(name: "mobile-data-layer", path: "../../../../../Work/mobile-data-layer"),
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "DataLayer", package: "mobile-data-layer"),
            ]
        ),
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
    ]
)
