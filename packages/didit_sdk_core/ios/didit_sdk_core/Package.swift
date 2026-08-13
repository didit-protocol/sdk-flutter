// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "didit_sdk_core",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "didit-sdk-core", targets: ["didit_sdk_core"])
    ],
    dependencies: [
        .package(url: "https://github.com/didit-protocol/sdk-ios.git", exact: "4.6.0")
    ],
    targets: [
        .target(
            name: "didit_sdk_core",
            dependencies: [
                .product(name: "DiditSDKCore", package: "sdk-ios")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
