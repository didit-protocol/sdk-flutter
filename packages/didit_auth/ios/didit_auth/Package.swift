// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "didit_auth",
    platforms: [
        // DiditAuth needs iOS 15; its hosted pages need 17.4 at run time and
        // fail with browser_unavailable below that.
        .iOS("15.0")
    ],
    products: [
        .library(name: "didit-auth", targets: ["didit_auth"])
    ],
    dependencies: [
        // The native release this plugin pins; ios/didit_auth.podspec and
        // android/build.gradle.kts pin the same one.
        .package(url: "https://github.com/didit-protocol/sdk-ios.git", exact: "4.14.7")
    ],
    targets: [
        .target(
            name: "didit_auth",
            dependencies: [
                .product(name: "DiditAuth", package: "sdk-ios")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
