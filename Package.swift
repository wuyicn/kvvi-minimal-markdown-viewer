// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeweiMDReader",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "KeweiMDReader", targets: ["KeweiMDReader"])],
    targets: [
        .executableTarget(
            name: "KeweiMDReader",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KeweiMDReaderTests",
            dependencies: ["KeweiMDReader"]
        )
    ]
)
