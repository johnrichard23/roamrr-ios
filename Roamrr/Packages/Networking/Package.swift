// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Networking", targets: ["Networking"])],
    dependencies: [.package(path: "../Core")],
    targets: [
        .target(name: "Networking", dependencies: [.product(name: "Core", package: "Core")]),
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
    ]
)
