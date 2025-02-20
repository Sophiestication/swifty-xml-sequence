// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyXMLSequence",
    platforms: [
        .iOS(.v15), .macOS(.v12), .watchOS(.v8), .tvOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftyXMLSequence",
            targets: ["SwiftyXMLSequence"]),
    ],
    targets: [
        .target(
            name: "SwiftyXMLSequence"),
        .testTarget(
            name: "SwiftyXMLSequenceTests",
            dependencies: ["SwiftyXMLSequence"],
            resources: [ .copy("trivia.xml"), .copy("sample1.html") ]
        ),
    ]
)
