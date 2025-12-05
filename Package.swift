// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pbxproj-mcp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.12.0"),
    ],
    targets: [
        // Core library with XcodeProj operations
        .target(
            name: "Core",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
            ]
        ),

        // MCP server executable
        .executableTarget(
            name: "pbxproj-mcp",
            dependencies: [
                "Core",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),

        // Unit tests for Core
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
