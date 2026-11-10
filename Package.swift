// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorkFee",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "WorkFee", targets: ["WorkFee"])],
    targets: [
        .target(name: "WorkFeeCore"),
        .executableTarget(name: "WorkFee", dependencies: ["WorkFeeCore"]),
        .testTarget(name: "WorkFeeCoreTests", dependencies: ["WorkFeeCore"])
    ]
)
