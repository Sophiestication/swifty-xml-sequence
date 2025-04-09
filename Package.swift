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
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftyXMLSequence",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]
        ),
        .testTarget(
            name: "SwiftyXMLSequenceTests",
            dependencies: [
                "SwiftyXMLSequence",
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms") 
            ],
            resources: [
                .copy("Samples/trivia.xml"),
                .copy("Samples/sample1.html"),
                .copy("Samples/sample2.html"),
                .copy("Samples/whitespace-collapse.html"),
                .copy("Samples/whitespace-collapse-cases.html")
            ]
        ),
    ]
)
