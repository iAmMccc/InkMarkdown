// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InkMarkdown",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        // 对外暴露的库产品
        .library(
            name: "InkMarkdown",
            targets: ["InkMarkdown"]
        ),
    ],
    dependencies: [
        // Apple 官方 Markdown 解析器（远程依赖，供其他端拉取使用）
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "InkMarkdown",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "Sources/InkMarkdown",
            exclude: [
                "Rendering/Components/TABLE_INTEGRATION_GUIDE.md",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "InkMarkdownTests",
            dependencies: ["InkMarkdown"],
            path: "Tests/InkMarkdownTests"
        ),
    ]
)
