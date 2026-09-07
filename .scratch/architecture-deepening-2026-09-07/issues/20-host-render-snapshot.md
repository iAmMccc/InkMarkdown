# 20：建立流式宿主的完整 snapshot 呈现入口

Status: done
Blocked by: 19
Implementation authorization: 已由用户授权执行（18–26 批次）。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [session-spec.md](../session-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [19](./19-session-binding-grant.md)
- Acceptance IDs: S-01, S-06, S-09
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

新 host 内部 module 可从真实 Session 生成并应用流式/终态 snapshot，不要求调用者拼 Thought/remainder。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift](../../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift)
- [Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift](../../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift)
- [Sources/InkMarkdownSwiftUI/Continuity/InkBlockPresentationContinuity.swift](../../../Sources/InkMarkdownSwiftUI/Continuity/InkBlockPresentationContinuity.swift)

## 计划文件

- `Sources/InkMarkdownSwiftUI/Bridge/InkStreamingPresentationHost.swift`（计划新建/前置票创建；先查是否已存在，避免重复）
- `Tests/InkMarkdownSwiftUITests/InkStreamingPresentationHostTests.swift`（计划新建/前置票创建；先查是否已存在，避免重复）

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 建立 host，弱持有 Session/container，拥有流式 textView 和重入 guard；公开的内部入口按 session-spec。
2. 搬入现有 streaming candidates 构造：Thought slot、remainder stableIdentity/contentRevision、首个 promoted Thought evidence 原样保留。
3. 用真实 continuity.reconcile/container.apply，不 mock 它们来跳过权限；apply 成功后通过 19 建立绑定。
4. 使默认 link handler 解析在静态和新 host 间共享稳定语义身份，不每次 render 生成新 identity。
5. 通过新 host interface 驱动 append、finish、空终态、width/Dynamic Type 变化；生产 Coordinator 仍走旧路径直到 23。

## Acceptance

- [x] 新 host 能展示完整 Thought/remainder 和 promotion 后 blocks。
- [x] 没有复制 lineage/live state/measurement maps。
- [x] 生产路径尚未切换的事实在证据中明确，不宣称完成接管深化。
- [x] 同一 session 更新不会重新创建无必要 textView 或改变链接语义。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 InkStreamingPresentationHostTests 的单 host/promotion/尺寸场景与 Session suite。
- 构建 InkMarkdownSwiftUI 受影响 target，确保 expand 代码实际编译。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/20-host-render-snapshot.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不让 Coordinator 把 candidates 或内部 state journal 传入新 host；那会保留原浅 interface。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：实现并验证完成；证据见 `../evidence/20-host-render-snapshot.md`。
