# ADR-002: v1.0 对外平台范围仅 iOS 14+

## Status

Accepted

## Date

2026-07-15

## Context

- 产品决策文档曾列出 iOS / macOS / tvOS / watchOS 矩阵。
- 仓库事实：`Package.swift` 仅 `.iOS(.v14)`，源码直接 `import UIKit`，测试在 iOS Simulator。
- 过早在 manifest 声明多平台会制造「已支持」假象。

## Decision

1. **v1.0 对外宣称与验证范围：仅 iOS 14+。**
2. 多平台（macOS 11+、tvOS 14+、watchOS 7+）保留为**路线图目标**，不写入「当前支持」。
3. 在完成条件编译、逐平台构建与测试之前，**不**扩展 `Package.swift` 的 `platforms`。

## Alternatives Considered

### v1 前强制做完全平台

- Pros: 与早期愿景一致  
- Cons: 阻塞 v1 发布；watchOS 等 UIKit 能力差异大  
- Rejected: 不作为 v1 退出标准

### 先声明多平台再补实现

- Pros: 文档好看  
- Cons: 违反 current-status 真实性原则  
- Rejected

## Consequences

- README / AGENTS 中「支持平台」若写全矩阵，应标明 **目标 / 决策** 与 **当前交付** 的区别（current-status 已有表）。
- 后续若有 macOS Catalyst 或 AppKit 需求，单独立项与 ADR。
