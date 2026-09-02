# 01: 建立 canonical corpus，并打通 reference link tracer

**What to build:** 建立一套由 attributed、block、streaming finish 与 SwiftUI integration 共同消费的语义投影 fixture，并用 reference link 完成第一条跨通道 tracer。使用者应在各呈现通道获得一致的链接文本、目标和回调语义，同时保留标准自动链接、相对链接、危险 scheme fallback 与 GFM bare URL 的既有边界。

**Blocked by:** None (can start immediately).

**Status:** done (2026-09-02, 本地候选：corpus target `InkMarkdownSemanticCorpus`；聚焦套件 InkCorpusLinkTracerTests / InkCorpusSwiftUIIntegrationTests 全绿，iPhone 17 Pro / iOS 26.5 Simulator)

- [x] 单一 canonical corpus 能声明 Markdown 输入、预期语义投影、适用通道和明确的不支持边界。
- [x] 语义投影只包含用户可观察结果：文本、inline traits、链接 destination、段落样式、Block 类型与表格结构；不比较 private state、具体 UIView identity 或像素级 frame。
- [x] reference link 在 attributed、block、streaming finish 与 SwiftUI integration 中保持相同文本和 destination。
- [x] 标准 `<URL>`、相对链接、危险 scheme fallback 与 GFM bare URL 普通文本行为不回退。
- [x] 新 harness 复用现有最高层测试 seam，不复制四套 fixture，也不创建新的 public production abstraction。
- [x] 自动化只保留该 tracer 所需关键断言；禁止 UI 测试、视觉 snapshot、重复入口或非核心排列测试。
- [x] 相关聚焦测试在当前 iOS Simulator checkout 上通过，并记录实际 scheme、destination 与结果。
