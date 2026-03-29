// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Slots",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .macCatalyst(.v17),
    ],
    products: [
        .library(name: "Slots", targets: ["Slots"]),
        .library(name: "SlotsExamples", targets: ["SlotsExamples"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0")
    ],
    targets: [
        .target(
            name: "Slots",
            dependencies: ["SlotMacros"]
        ),
        .macro(
            name: "SlotMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SlotsExamples",
            dependencies: ["Slots"]
        ),
        .testTarget(
            name: "SlotTests",
            dependencies: [
                "Slots",
                "SlotMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
