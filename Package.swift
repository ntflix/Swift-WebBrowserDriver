// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SafariDriver",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SafariDriver",
            targets: ["SafariDriver"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ntflix/swift-webdriver/", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SafariDriver",
            dependencies: [
                .product(name: "WebDriver", package: "swift-webdriver")
            ]
        ),
        .testTarget(
            name: "SafariDriverTests",
            dependencies: ["SafariDriver"]
        ),
    ]
)
