// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyXMLSequence",
    platforms: [
        .iOS(.v18), .macOS(.v15), .watchOS(.v11), .tvOS(.v18)
    ],
    products: [
        .library(
            name: "SwiftyXMLSequence",
            targets: ["SwiftyXMLSequence"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "SwiftyXMLSequence",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms")
            ]
        ),
        .testTarget(
            name: "SwiftyXMLSequenceTests",
            dependencies: [
                "SwiftyXMLSequence",
                .product(name: "Algorithms", package: "swift-algorithms")
            ],
            resources: [
                .copy("trivia.xml"),
                .copy("sample1.html"),
                .copy("sample2.html"),
                .copy("whitespace-collapse.html")
            ]
        ),
    ]
)
