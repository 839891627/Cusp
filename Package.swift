// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CuspShared",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CuspShared",
            targets: ["CuspShared"]
        )
    ],
    targets: [
        .target(
            name: "CuspShared",
            path: "Sources/CuspShared"
        ),
        .testTarget(
            name: "CuspSharedTests",
            dependencies: ["CuspShared"],
            path: "Tests/CuspSharedTests"
        )
    ]
)
