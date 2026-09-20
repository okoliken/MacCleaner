// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CleanerKit", targets: ["CleanerKit"]),
        .executable(name: "cleaner", targets: ["cleaner"]),
        .executable(name: "MacCleanerApp", targets: ["MacCleanerApp"]),
    ],
    targets: [
        .target(name: "CleanerKit"),
        .executableTarget(name: "cleaner", dependencies: ["CleanerKit"]),
        .executableTarget(name: "MacCleanerApp", dependencies: ["CleanerKit"]),
        .testTarget(name: "CleanerKitTests", dependencies: ["CleanerKit"]),
    ]
)
