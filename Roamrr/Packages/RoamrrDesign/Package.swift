// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RoamrrDesign",
    platforms: [.iOS(.v17)],
    products: [.library(name: "RoamrrDesign", targets: ["RoamrrDesign"])],
    dependencies: [
        .package(url: "https://github.com/johnrichard23/mobile-design-system.git", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "RoamrrDesign",
            dependencies: [.product(name: "DesignSystem", package: "mobile-design-system")]
        ),
        .testTarget(name: "RoamrrDesignTests", dependencies: ["RoamrrDesign"]),
    ]
)
