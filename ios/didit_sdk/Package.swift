// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "didit_sdk",
    platforms: [
        // This package installs the full native SDK (the "DiditSDK" product
        // below), which requires iOS 15 just like the CocoaPods DiditSDK/All
        // subspec. Apps needing a smaller variant or an iOS 13 floor should use
        // the didit_sdk_core / didit_sdk_autodetection / didit_sdk_nfc packages.
        .iOS("15.0")
    ],
    products: [
        .library(name: "didit-sdk", targets: ["didit_sdk"])
    ],
    dependencies: [
        .package(url: "https://github.com/didit-protocol/sdk-ios.git", exact: "4.7.1")
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
