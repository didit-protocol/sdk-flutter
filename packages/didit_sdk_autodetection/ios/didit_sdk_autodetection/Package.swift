// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "didit_sdk_autodetection",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "didit-sdk-autodetection", targets: ["didit_sdk_autodetection"])
    ],
    dependencies: [
        .package(url: "https://github.com/didit-protocol/sdk-ios.git", exact: "4.5.3")
    ],
    targets: [
        .target(
            name: "didit_sdk_autodetection",
            dependencies: [
                .product(name: "DiditSDKAutoDetection", package: "sdk-ios")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
