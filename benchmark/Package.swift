// swift-tools-version: 6.0
// Runs the Smell Test benchmark on this Mac's Apple on-device model, using the same prompt,
// parser and escalation rules as the iPhone app (from SmellTestCore). No network code.
import PackageDescription

let package = Package(
    name: "smell-bench",
    platforms: [.macOS("26.0")],
    dependencies: [.package(path: "../Packages/SmellTestCore")],
    targets: [
        .executableTarget(name: "smell-bench", dependencies: ["SmellTestCore"]),
    ]
)
