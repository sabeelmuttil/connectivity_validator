// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "connectivity_validator",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        // If the plugin name contains "_", replace with "-" for the library name.
        .library(
            name: "connectivity-validator",
            targets: ["connectivity_validator"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "connectivity_validator",
            dependencies: [],
            resources: [
                // Privacy manifest file
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
