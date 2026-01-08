// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LogViewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LogViewer", targets: ["LogViewer"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LogViewer",
            dependencies: [],
            path: "LogViewer",
            sources: [
                "App",
                "Core",
                "Data",
                "Domain",
                "Infrastructure",
                "Presentation"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("APPSTORE", .when(configuration: .release))
            ]
        )
    ]
)
