// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacOptimizer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacOptimizer", targets: ["MacOptimizer"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacOptimizer",
            dependencies: [],
            path: "Sources/MacOptimizer"
        ),
        .testTarget(
            name: "MacOptimizerTests",
            dependencies: ["MacOptimizer"],
            path: "Tests/MacOptimizerTests"
        ),
    ]
)
