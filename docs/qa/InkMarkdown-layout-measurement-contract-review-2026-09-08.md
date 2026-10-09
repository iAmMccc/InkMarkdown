# 布局测量验收项

维护日期：2026-09-09。布局契约见 [指南](../contributor-guide/13-layout-measurement-contract.md)。旧审查的 F1–F3 修复已体现在源码和测试定义；本次未执行测试，不将测试文件存在等同于通过。

## 需要保留的验证场景

- 零 bounds、父视图 390pt、preferred 280pt：首轮高度应与显式 280pt proposal 一致；真实 bounds 就绪后接管。覆盖 preferred 修改、清除、init/environment 优先级与容差内重复写入。
- 流式 textContainer 与 bounds 双零宽时保存待测标记；无新字符时宽度恢复仍补通知一次；覆盖 bounds fallback 与大于 1pt 的高度门闩。
- 表格未知宽时接纳表头、参考行和后续行，不生成临时 wrap 列布局或发出误导高度；获得宽度后与同宽直接初始化结果一致。
- ICS 观测覆盖完整 layoutSubviews 调用栈，包括 continuity 环境回调；零计数不能只依赖回调之后才设置的观测标记。
- 实际 chat 首测、旋转、iPad Split View、iOS 15 intrinsic 路径与 iOS 16+ proposal 路径，以及流式性能仍需按候选验收。

## 源码与测试入口

- [容器](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift)：测量宽度与布局回调。
- [流式 renderer](../../Sources/InkMarkdown/Rendering/InkStreamRenderer.swift)：延期高度测量与通知。
- [表格 presentation](../../Sources/InkMarkdown/Rendering/Components/InkTablePresentation.swift)：未知宽接纳与布局。
- 测试按符号检索：`preferredMeasurementWidth_outranksParentEstimateWhenBoundsZero`、`notifyHeight_deferredUntilWidthReady_notifiesOnce`、`layout_zeroWidthAccept_recoversConsistentWithDirectInit`。

记录实际 scheme、destination、通过/失败结果与运行限制后，更新 [当前状态](../current-status.md)。
