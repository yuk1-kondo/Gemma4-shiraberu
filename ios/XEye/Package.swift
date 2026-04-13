// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "XEye",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "XEye", targets: ["XEye"])
    ],
    targets: [
        .target(
            name: "XEye",
            path: "Sources",
            exclude: [
                "App",
                "UI",
                "ViewModels"
            ]
        ),
        .testTarget(
            name: "XEyeTests",
            dependencies: ["XEye"],
            path: "Tests"
        )
    ]
)
