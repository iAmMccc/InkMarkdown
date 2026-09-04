// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "InkMarkdownConsumerSmoke",
  platforms: [
    .iOS(.v15),
  ],
  products: [
    .library(name: "InkMarkdownCoreConsumer", targets: ["InkMarkdownCoreConsumer"]),
    .library(name: "InkMarkdownSwiftUIConsumer", targets: ["InkMarkdownSwiftUIConsumer"]),
    .library(name: "InkMarkdownLaTeXConsumer", targets: ["InkMarkdownLaTeXConsumer"]),
    .library(name: "InkMarkdownMermaidConsumer", targets: ["InkMarkdownMermaidConsumer"]),
  ],
  dependencies: [
    .package(path: "../../.."),
  ],
  targets: [
    .target(
      name: "InkMarkdownCoreConsumer",
      dependencies: [
        .product(name: "InkMarkdown", package: "InkMarkdown"),
      ]
    ),
    .target(
      name: "InkMarkdownSwiftUIConsumer",
      dependencies: [
        .product(name: "InkMarkdownSwiftUI", package: "InkMarkdown"),
      ]
    ),
    .target(
      name: "InkMarkdownLaTeXConsumer",
      dependencies: [
        .product(name: "InkMarkdownLaTeX", package: "InkMarkdown"),
      ]
    ),
    .target(
      name: "InkMarkdownMermaidConsumer",
      dependencies: [
        .product(name: "InkMarkdownMermaid", package: "InkMarkdown"),
      ]
    ),
  ]
)
