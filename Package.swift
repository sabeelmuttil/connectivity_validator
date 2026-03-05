// swift-tools-version: 5.9
//
// Minimal root manifest so `swift package describe` (and other Swift tooling) works
// when run from the project root. The real iOS plugin is in ios/connectivity_validator/.
//
// For a full-featured root Package.swift (dependencies, version vars, real targets),
// see e.g. Flutter Fire's remote_firebase_core-style manifest with .package(url:...),
// .target(..., path: "Sources/..."), and cSettings.
//
import PackageDescription

let package = Package(
    name: "connectivity_validator_workspace",
    platforms: [.iOS("13.0")],
    products: [],
    dependencies: [],
    targets: []
)
