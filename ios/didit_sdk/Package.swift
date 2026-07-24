// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "didit_sdk",
    platforms: [
        // The SPM integration always uses the full native SDK (the "DiditSDK"
        // product below), which requires iOS 15 just like the CocoaPods
        // DiditSDK/All and DiditSDK/NFC subspecs. Apps needing the iOS 13
        // Core/AutoDetection variants must stay on the CocoaPods integration.
        .iOS("15.0")
    ],
    products: [
        .library(name: "didit-sdk", targets: ["didit_sdk"])
    ],
    dependencies: [
        .package(url: "https://github.com/didit-protocol/sdk-ios.git", exact: "4.3.0")
    ],
    targets: [
        .target(
            name: "didit_sdk",
            dependencies: [
                .product(name: "DiditSDK", package: "sdk-ios")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
