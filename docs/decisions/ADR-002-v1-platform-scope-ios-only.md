# ADR-002: v1.0 对外平台范围仅 iOS 14+

## Status

Superseded by ADR-008 (2026-08-17)

## Date

2026-07-15

## Context

- 产品决策文档曾列出 iOS / macOS / tvOS / watchOS 矩阵。
- 仓库事实：`Package.swift` 仅 `.iOS(.v14)`，源码直接 `import UIKit`，测试在 iOS Simulator。
- 过早在 manifest 中声明多平台容易误导为已完全支持。

## Decision

1. **v1.0 对外宣称与验证范围：仅 iOS 14+。**
2. 多平台（macOS 11+、tvOS 14+、watchOS 7+）保留为路线图目标，暂不列入当前支持平台。
3. 在完成条件编译、逐平台构建与测试之前，**不**扩展 `Package.swift` 的 `platforms`。

## Alternatives Considered

### v1 前强制做完全平台

- Pros: 与早期愿景一致  
- Cons: 阻塞 v1 发布；watchOS 等平台 UIKit 能力差异大  
- Rejected: 不作为 v1 发布条件

### 先声明多平台再补实现

- Pros: 表面完备  
- Cons: 违反 current-status 真实性原则  
- Rejected

## Consequences

- README / AGENTS 中「支持平台」若写全矩阵，应标明 **目标 / 决策** 与 **当前交付** 的区别（current-status 已有表）。
- 后续若有 macOS Catalyst 或 AppKit 需求，单独立项与 ADR。

## Supersession note

[ADR-008](ADR-008-swiftui-adapter-architecture.md) 将当前产品路线明确为 iOS 14+ / iPadOS 14+，且不再把 macOS、tvOS、watchOS 或其他平台列为路线图目标。它 supersede 本 ADR 的平台范围与旧平台扩展预期；“不得抢先声明未验证平台”的原则已被 ADR-008 吸收。
