# InkMarkdown interaction / 图片验收与候选验证（2026-09-02）

> **当前候选验证 SSOT。** 不是远端 CI，也不是已发布 `0.0.2` 证明。代码功能批次已本地提交；本证据文件随 docs 收口提交。身份由基线 commit、本轮本地提交链和日期共同确定。工作树继续变化后，必须重跑相应门禁，历史 PASS 不自动继承。

## 候选身份

| 项 | 值 |
| --- | --- |
| 分支 | `feat/swiftUI` |
| 基线 commit | `8fb1640`（tickets 01–05） |
| 本轮本地提交 | `75d5c88`（text obliqueness）→ `15a5d0d`（tickets 06–07 图片）→ `16a3579`（corpus harness）→ `a6878da`（ticket 08 ExampleApp wiring）；本文件随 docs 收口一并提交 |
| 日期 | 2026-09-02 |

状态只使用 `PASS`、`BLOCKED`、`未执行`：`PASS` 必须来自上表候选身份对应的当前证据；历史候选结果只能标为历史，不得填充当前门禁。

## Ticket 09 — 自动化验证

| 项 | 结果 |
| --- | --- |
| `git diff --check` | PASS（无 whitespace error） |
| Scheme | `InkMarkdown-Package` |
| Destination | iPhone 17 Pro / iOS 26.5 Simulator（`OS=latest`） |
| 执行器 | XcodeBuildMCP；首次受失效代理阻塞后复用已有 `SourcePackages` 的 DerivedData 完成验证 |
| 结果 | **TEST SUCCEEDED** |
| 全量测试 | **333 通过**；**0 失败**；**1 跳过**（`iOS 14 ICS 回传高度`：本机无 iOS 14 runtime） |
| 最终收口聚焦 | canonical corpus、link、promotion、continuity、session 与 source-limit 受影响 suites 合计 **35 通过、0 失败、0 跳过** |

### ExampleApp / 外部消费者构建

| 项 | 结果 |
| --- | --- |
| ExampleApp Debug | **BLOCKED** — `~/.gitconfig` 将 github.com 代理到失效的 `127.0.0.1:6152`，SnapKit / JXPagingView / JXSegmentedView / SmartCodable 无法解析 |
| ExampleApp Release | **未执行** — 与 Debug 共用同一依赖解析前置条件，Debug 已在编译前阻塞 |
| 四 product 外部消费者冒烟 | **未重跑**（本轮优先 Package 全量；不把历史结果写成当前工作树证据） |

### 独立审查

Standards / Spec 分别由不继承主上下文的独立代理执行，结论保持分轴：

- **Standards**：发现图片 host / empty-host 策略重复（P2）及 corpus 测试 helper 重复（P3）。已分别收敛到 `ImageSecurityPolicy` 与 `InkMarkdownSemanticCorpus` 共享 seam。
- **Spec**：发现 loader fallback identity 未进入 cache key（P1）、取消状态竞态（P1）、responsive 测试绑定 UIView identity（P2）、canonical corpus 缺少 table / promotion 语义覆盖（P2）、readiness task 误报人工验收完成（P2）。已在 loader identity、锁保护 TaskBox、store generation、共享 corpus / projection 与状态 SSOT 修复。
- 最终复审：Standards 与 Spec 均无剩余 finding；该结论只关闭审查问题，不替代下方 ExampleApp / 人工门禁。
- 图片策略、取消、loader identity / generation 等首轮 remediation 聚焦回归曾为 56 通过；最终共享测试 seam 与表格 promotion 收口后，当前工作树又完成 35 项受影响 suite 聚焦回归及 333 项全量通过。ExampleApp 构建、真网与人工矩阵仍独立记为 BLOCKED，不以 agent 结论替代。

## Ticket 08 — ExampleApp 人工验收矩阵

主导航入口（跟进入口审计后已补齐 fixture wiring）：

| 场景 | 入口 | 本轮 wiring |
| --- | --- | --- |
| 列表 / 链接矩阵 | `1. 基础 Markdown 静态渲染` | 松散列表、混合嵌套、列表内引用、引用/自动/相对链接 |
| 复杂表格 / 单元格链接 / 复制 | `2. 自定义组件与富媒体` | rich cell、escaped pipe、不齐行；`enableLongPressCopy = true` |
| placehold.co / picsum + 失败 fallback | 同上（图片开关 ON） | placehold 行内 + picsum 块图 + `id/999999` 失败样例 |
| 流式链接 / 表格链接 / promotion | `4. 流式 Markdown 渲染` | 正文/引用链接；表格单元格含链接 |
| Chat 图文 + 失败 | `5. AI SSE 对话问答` | 既有 Mock「图片」关键词路径 |

| 验收项 | 设备 | 结果 | 备注 |
| --- | --- | --- | --- |
| 主导航可访问上述入口 | — | PASS（源码核对 + fixture wiring） | 未宣称视觉通过 |
| iPhone 竖/横屏走查 | iPhone 17 Pro / iOS 26.5 | **BLOCKED** | ExampleApp 本轮未能完成构建安装 |
| iPad 全屏 / 1/2 / 1/3 / Split View | iPad Pro 11-inch (M5) 等 | **BLOCKED** | 同上；MCP 无可靠 Split View 控制 |
| 旋转后无裁切 / 零高 / 状态丢失 | — | **BLOCKED** | 依赖上一项 |
| `placehold.co` 真网成功 | — | **BLOCKED** | 依赖 ExampleApp 运行 + 外网 |
| `picsum.photos` 重定向链路 | — | **BLOCKED** | 同上 |
| 第三方服务故障记为环境失败 | — | N/A | 未执行到网络步骤 |
| 不扩展 VoiceOver UI 测试 | — | PASS | 本轮未新增 UI automation / snapshot |
| 不宣称 iOS 14 / 真机性能 | — | PASS | 明确未验证 |

> `ImageDemoViewController` / `ImageIntegrationViewController` / `ComponentPager` 仍为孤儿 VC；Ticket 08 以 6 场景主导航为准，不恢复旧顶层 Pager。

## Ticket 10 — 文档同步（本轮已改）

- README 中英文图片行：opt-in、默认开放 host、资源边界
- FAQ §6、SwiftUI ExampleApp 指南、走查 SSOT、`docs/spec/common-syntax.md`：去掉过时 fail-closed 默认描述
- `DemoStyle.demoImageEnabled` 注释与 ADR-006 对齐
- `current-status.md` / `CHANGELOG` Unreleased：本地候选测试数与图片策略
- 本证据文件可从 `docs/qa/` 与 `docs/current-status.md` 发现

## 仍为 release blocker（不因本轮关闭）

- iOS/iPadOS 14–15 runtime
- ExampleApp 真网图片、旋转、Split View 人工矩阵
- 真机性能基线
- 完整 VoiceOver 体系（本轮明确不扩张）
- 远端 CI / push / PR（维护者未授权）
