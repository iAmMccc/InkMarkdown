# ADR-001: swift-markdown 依赖固定 revision，本地缓存仅作可选离线路径

## Status

Accepted

## Date

2026-07-15

## Context

- 当前 `Package.swift` 使用 `swift-markdown` 远程 **`branch: main`**，`Package.resolved` 记录了某次 revision，但分支依赖易随上游更新变动。
- 项目目标开发策略包含 `Packages/Caches/` + `path:`，以绕过 Xcode 网络限制；脚本与缓存目录已存在。
- 库作为 **SPM 依赖** 被宿主引入，若默认 `path:` 指向本地缓存，外部项目无法解析。

需要同时满足：**可重复构建**、**外部依赖兼容**、**本地离线可开发**。

## Decision

1. **对外默认（`Package.swift`）**：依赖 swift-markdown 的**固定 git revision**（或将来语义化 tag），**不再以浮动 `branch: main` 作为发布/协作默认**。
2. **本机离线**：继续维护 `Packages/scripts/fetch-packages.sh` 与 `Packages/Caches/`；开发者可在本地临时改 path 或使用 Xcode 本地包覆盖，**不把 path 写进默认发布 manifest**。
3. **SmartCodable**：维持「未使用则不引入」；无明确用途前不写进依赖表。

## Alternatives Considered

### 继续跟踪 `branch: main`

- Pros: 能获取上游最新解析修复  
- Cons: 渲染与测试不可重复；环境易漂移  
- Rejected: 库渲染依赖解析稳定性

### 默认 `path: Packages/Caches/swift-markdown`

- Pros: 本机无网可构建  
- Cons: 远程 SPM 消费者无法使用；缓存不进 git  
- Rejected: 作为**默认**策略；保留为本地可选

### 仅靠 Package.resolved 不改 Package.swift

- Pros: 改动小  
- Cons: 声明仍是 branch；全新拉取仍可能使用最新提交  
- Rejected: 无法确保持续稳定

## Consequences

- 升级 swift-markdown 需显式改 revision 并跑 iOS Simulator 测试。
- 文档中「本地缓存」表述调整为：**可选离线路径**，不属于默认 manifest。
- `docs/current-status.md` 与 `STACK.md` 的现状记录在锁定版本后保持一致。

## Implementation note

**已落地（2026-07-15）**

- `Package.swift`：`.package(url:…swift-markdown.git, revision: "07ebc9c071b22a5d021031b798c3a84b76281213")`
- `Package.resolved`：`swift-markdown` 仅含 `revision` 字段（无 `branch`）
- 传递依赖 `swift-cmark` 仍由上游 manifest 声明 `gfm`，并由 resolved 锁定 revision `0101bf2c…`
- CI：`.github/workflows/ci.yml` 在 iOS Simulator 上验证该 pin
