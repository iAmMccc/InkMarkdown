// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "InkMarkdown",
  platforms: [
    .iOS(.v15)
  ],
  products: [
    .library(name: "InkMarkdownKingfisher", targets: ["InkMarkdownKingfisher"]),
    // 对外暴露的库产品
    .library(
      name: "InkMarkdown",
      targets: ["InkMarkdown"]
    ),
    .library(
      name: "InkMarkdownSwiftUI",
      targets: ["InkMarkdownSwiftUI"]
    ),
    .library(
      name: "InkMarkdownLaTeX",
      targets: ["InkMarkdownLaTeX"]
    ),
    .library(
      name: "InkMarkdownMermaid",
      targets: ["InkMarkdownMermaid"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/onevcat/Kingfisher.git", exact: "8.12.0"),
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
      name: "InkMarkdownKingfisher",
      dependencies: ["InkMarkdown", .product(name: "Kingfisher", package: "Kingfisher")],
      swiftSettings: [.swiftLanguageMode(.v5), .enableExperimentalFeature("StrictConcurrency")]
    ),
    .testTarget(name: "InkMarkdownKingfisherTests", dependencies: ["InkMarkdownKingfisher"]),
    .target(
      name: "InkMarkdown",
      dependencies: [
        .product(name: "Markdown", package: "swift-markdown")
      ],
      path: "Sources/InkMarkdown",
      exclude: [
        "Rendering/Components/TABLE_INTEGRATION_GUIDE.md"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableExperimentalFeature("StrictConcurrency"),
      ]
    ),
    .target(
      name: "InkMarkdownSwiftUI",
      dependencies: ["InkMarkdown"],
      path: "Sources/InkMarkdownSwiftUI",
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableExperimentalFeature("StrictConcurrency"),
      ]
    ),
    .testTarget(
      name: "InkMarkdownTests",
      dependencies: [
        "InkMarkdown",
        "InkMarkdownSemanticCorpus",
      ],
      path: "Tests/InkMarkdownTests"
    ),
    .testTarget(
      name: "InkMarkdownAddonContractTests",
      dependencies: ["InkMarkdown", "InkMarkdownLaTeX", "InkMarkdownMermaid", "InkMarkdownKingfisher"],
      path: "Tests/InkMarkdownAddonContractTests"
    ),
    .testTarget(
      name: "InkMarkdownLaTeXTests",
      dependencies: ["InkMarkdown", "InkMarkdownLaTeX"],
      path: "Tests/InkMarkdownLaTeXTests"
    ),
    .testTarget(
      name: "InkMarkdownMermaidTests",
      dependencies: ["InkMarkdown", "InkMarkdownMermaid"],
      path: "Tests/InkMarkdownMermaidTests"
    ),
    .testTarget(
      name: "InkMarkdownSwiftUITests",
      dependencies: [
        "InkMarkdownSwiftUI",
        "InkMarkdown",
        "InkMarkdownSemanticCorpus",
      ],
      path: "Tests/InkMarkdownSwiftUITests"
    ),
    // 测试支撑 target：v0.0.2 canonical semantic corpus 的唯一存放处。
    // 仅供 InkMarkdownTests / InkMarkdownSwiftUITests 依赖，不进入任何对外 product，
    // 因此不构成 production abstraction（spec：不在库内新增公共抽象）。
    .target(
      name: "InkMarkdownSemanticCorpus",
      dependencies: ["InkMarkdown"],
      path: "Tests/Support/InkMarkdownSemanticCorpus",
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableExperimentalFeature("StrictConcurrency"),
      ]
    ),
    .testTarget(
      name: "InkMarkdownCoreContractTests",
      dependencies: ["InkMarkdown"],
      path: "Tests/InkMarkdownCoreContractTests"
    ),
    .target(
      name: "ExampleAppChatPolicy",
      path: "ExampleApp/ExampleApp/Presentation/Chat",
      sources: ["ChatScrollPolicy.swift"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "ExampleAppPolicyTests",
      dependencies: ["ExampleAppChatPolicy"],
      path: "Tests/ExampleAppPolicyTests"
    ),
    .target(
      name: "InkMarkdownLaTeX",
      dependencies: [
        "InkMarkdown",
        .product(name: "iosMath", package: "iosMath"),
      ],
      path: "Sources/InkMarkdownLaTeX",
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableExperimentalFeature("StrictConcurrency"),
      ]
    ),
    .target(
      name: "InkMarkdownMermaid",
      dependencies: ["InkMarkdown"],
      path: "Sources/InkMarkdownMermaid",
      resources: [.process("Resources")],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableExperimentalFeature("StrictConcurrency"),
      ]
    ),
  ]
)
