// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "didit_sdk_nfc",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "didit-sdk-nfc", targets: ["didit_sdk_nfc"])
    ],
    dependencies: [
        .package(url: "https://github.com/didit-protocol/sdk-ios.git", exact: "4.7.1")
    ],
    targets: [
        .target(
            name: "didit_sdk_nfc",
            dependencies: [
                .product(name: "DiditSDKNFC", package: "sdk-ios")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
