# InkMarkdown v0.0.2 审查修复记录（2026-08-27）

本文记录 2026-08-27 审查结论的修复方案与验证边界。它不是发布验收报告；当前任务执行入口是 [2026-08-28 当前任务摘要](InkMarkdown-current-task-summary-2026-08-28.md)，iOS/iPadOS 14 runtime、真机性能和完整人工语义走查仍以 `docs/current-status.md` 的 blocker 为准。

## 已解决

1. ExampleApp 的 internal SPI witness 已移除；额外修复 `SwiftUIConfigurationDemoView` 缺失的 `import InkMarkdown`。
2. `InkRenderableBlock` 恢复为普通消费者可实现的最小公开 interface；adapter diff 元数据不再写入 block。可安全复用的内置块通过可选 `InkReusableBlock` 提供完整语义比较与显式更新结果。
3. 恢复 `InkCodeBlock(code:language:config:)`，转发到含完整 render configuration 的 initializer。
4. 删除有损富文本 fingerprint 路径；全文、属性 runs、链接和附件由 `NSAttributedString.isEqual(to:)` 比较，内容变化后更新已有 text view。
5. 图片、LaTeX 与 Mermaid block 的 source/rendering 变化时重建不可变图片 view，旧订阅随旧 view 生命周期取消，不再对旧实例只调用 `setNeedsLayout()`。
6. thought dirty state 纳入 `isComplete` 与折叠态；close-only chunk 会刷新标题及可访问性状态。
7. `InkStreamRenderer.bindTextView` 始终覆盖当前显示快照，空 session 也会清空旧 session 的 `textStorage`。
8. 表格比较包含 alignment、行边界与 layout mode；配置 handler 通过 `InkConfigurationSemanticsProviding` 比较内部状态，未知扩展保守视为不等价。
9. 表格 cell 渲染、列宽测量、增量扩列判断、line height 与 baseline 使用同一 Dynamic Type trait 快照。
10. addon registry 的共享可变状态收敛进单一加锁容器；`InkImageAttachment.attachmentBounds` 改为无副作用纯测量回调。
11. 旧 QA 文档已标记为历史快照，不再作为当前工作区入口。
12. 中英文 README 与 addon 类型注释已明确 product、import、启动注册、开启渲染的顺序。
13. 表格 view 重配时统一拆除旧 content root 与复制手势，再按新 layout mode 安装单一根容器；不再累积旧 stack / scroll view 与 gesture recognizer。
14. 图片缓存测试改为等待 `InkImageStore` 的完成回调，不再用 loader 完成计数推断 MainActor 缓存已经写入。
15. 新增统一 `InkSemanticIdentity` seam；`sourceFilter`、链接/表格/图片回调、自定义 loader、Store 和安全策略均参与完整语义比较，不再只比较 nil 性。
16. Mermaid 生成图与 LaTeX 一样必须经 runtime provider 注册 seam；新增只依赖 core 的独立测试 target，避免其他测试预先注册污染未注册结论。
17. 补齐第三方 `InkReusableBlock` 真实更新、图片旧订阅取消/新结果展示、不同 Store 不复用、addon 注册前后完整链路回归。

## 自动验证

- ExampleApp：iPhone 17 / iOS 26.5 Simulator 编译通过，deployment target 仍为 iOS 14.0。
- 本轮新增/复核聚焦回归：配置语义与 Coordinator 15 项、局部 Block 复用 10 项、core-only 未注册边界 3 项、addon 已注册链路 2 项，均通过。
- 全量回归：iPhone 17 / iOS 26.5 上共 313 项：312 项通过、0 失败、1 项跳过（iOS 14 ICS；本机无对应 runtime）；此前未签收的 Mermaid wide-journey 用例本次通过。
- 临时把本包五个本地 target 切到 Swift 6 language mode，并只对本地 target 启用 `-warnings-as-errors` 后，`InkMarkdown-Package` 编译通过；验证后已恢复仓库要求的 Swift 5 language mode。`Package.swift` 本轮仅持久新增 `InkMarkdownCoreContractTests` target，不改变生产 target 的语言模式。
- 当前复核使用 Serena 核验符号与共享 seam，并由 XcodeBuildMCP 重新完成全量 package 测试和 ExampleApp Simulator 编译；`apple-docs` 当前会话仍未加载，Apple API 仅通过官方文档网页降级核对。

## 尚未签收

- iOS/iPadOS 14–15 runtime、旋转、Split View 与无初始宽度协商。
- ExampleApp 中 LaTeX、Mermaid、图片 ReservedHeight、表格、链接、Thought 与 Dynamic Type 的完整人工可见走查。
- 真机 FPS、hitch、内存峰值、WebKit 冷启动与长会话性能。
