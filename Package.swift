// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InkMarkdown",
    platforms: [
        .iOS(.v14),
        // 供 SwiftPM 在 macOS host 上解析 iosMath 的最低部署版本；库的 UIKit API 仍以 iOS 为主。
        .macOS(.v10_15),
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
        // iosMath 2.3.1：LaTeX 本地排版（MIT；字体许可见 docs/decisions/ADR-007）。
        .package(url: "https://github.com/kostub/iosMath.git", exact: "2.3.1"),
    ],
    targets: [
        .target(
            name: "InkMarkdown",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "iosMath", package: "iosMath"),
            ],
            path: "Sources/InkMarkdown",
            exclude: [
                "Rendering/Components/TABLE_INTEGRATION_GUIDE.md",
            ],
            resources: [
                .process("Rendering/Mermaid/Resources"),
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
