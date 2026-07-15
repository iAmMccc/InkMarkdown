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
        // Apple 官方 Markdown 解析器：固定 revision，保证可重复构建（ADR-001）
        // 升级时：改 revision → 更新 Package.resolved → iOS Simulator 全量测试
        .package(
            url: "https://github.com/swiftlang/swift-markdown.git",
            revision: "07ebc9c071b22a5d021031b798c3a84b76281213"
        ),
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
