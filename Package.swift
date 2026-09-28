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
            exclude: [
                "Resources/common.xcstrings",
                "Resources/dashboard.xcstrings",
                "Resources/cleanup.xcstrings",
                "Resources/ai.xcstrings",
                "Resources/services.xcstrings",
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MacOptimizerTests",
            dependencies: ["MacOptimizer"],
            path: "Tests/MacOptimizerTests"
        ),
    ]
)
