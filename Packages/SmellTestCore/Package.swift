// swift-tools-version: 6.0
// SmellTestCore: verdict schema, validation, fixed recovery steps and the Privacy Shield's
// fixed-pattern redactor. Pure Swift with no Firebase or network code, so it can be reused
// by apps that must never send anything off the device.
import PackageDescription

let package = Package(
    name: "SmellTestCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SmellTestCore", targets: ["SmellTestCore"]),
    ],
    targets: [
        .target(name: "SmellTestCore"),
        .testTarget(name: "SmellTestCoreTests", dependencies: ["SmellTestCore"]),
    ]
)
