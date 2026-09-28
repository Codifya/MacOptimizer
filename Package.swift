// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacOptimizer",
    defaultLocalization: "en",
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
            path: "Sources/MacOptimizer",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MacOptimizerTests",
            dependencies: ["MacOptimizer"],
            path: "Tests/MacOptimizerTests"
        ),
    ]
)
