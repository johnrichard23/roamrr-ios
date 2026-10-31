// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RoamrrDesign",
    platforms: [.iOS(.v17)],
    products: [.library(name: "RoamrrDesign", targets: ["RoamrrDesign"])],
    dependencies: [
        .package(name: "mobile-design-system", path: "../../../../../Work/mobile-design-system"),
    ],
    targets: [
        .target(
            name: "RoamrrDesign",
            dependencies: [.product(name: "DesignSystem", package: "mobile-design-system")]
        ),
        .testTarget(name: "RoamrrDesignTests", dependencies: ["RoamrrDesign"]),
    ]
)
