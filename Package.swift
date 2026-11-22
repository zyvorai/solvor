// swift-tools-version: 5.10
// Copyright 2026 Zyvor AI Labs · https://zyvor.dev
// SPDX-License-Identifier: LicenseRef-Zyvor-Production-2.0

import PackageDescription

let package = Package(
    name: "KeepKit",
    platforms: [.macOS("26.0")],
    products: [.library(name: "KeepKit", targets: ["KeepKit"])],
    targets: [
        .target(name: "KeepKit", path: "Sources/KeepKit"),
        .testTarget(
            name: "KeepKitTests",
            dependencies: ["KeepKit"],
            path: "Tests/KeepKitTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
