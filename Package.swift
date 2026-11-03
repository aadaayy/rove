// swift-tools-version:5.9
// Rove's money math, estimates, receipt reading and sample data as a small
// package, so the logic tests run anywhere Swift runs (including a cheap
// Linux machine) without Xcode. The app itself is built from Rove.xcodeproj,
// which compiles these same files.
import PackageDescription

let package = Package(
    name: "RoveCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RoveCore", targets: ["RoveCore"]),
    ],
    targets: [
        .target(name: "RoveCore", path: "Rove/Core"),
        .testTarget(
            name: "RoveCoreTests",
            dependencies: ["RoveCore"],
            path: "Tests/RoveCoreTests"
        ),
    ]
)
