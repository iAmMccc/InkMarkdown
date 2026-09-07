# 25：删除旧流式宿主接线与重复 owner 字段

Status: ready-for-agent
Blocked by: 24
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [session-spec.md](../session-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [24](./24-swiftui-remount-regression.md)
- Acceptance IDs: S-14, G-02, G-05, G-09
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

结束 host 迁移，Coordinator 和 Session 无两套并行 owner/observer/text-binding implementation。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift](../../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift)
- [Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift](../../../Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift)
- [Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownRepresentable.swift](../../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownRepresentable.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 查询旧 streamTextView、ownedAttachmentToken、currentSessionCycleID、pendingRenderEnvironment 和相关私有函数全部引用；区分静态仍需要的字段。
2. 删除 19 的迁移期旧内部函数转发，修改合法内部测试到新的成组 binding/host seam。
3. 删除 Coordinator 的旧 streaming reconcile、env dispatch 和 callback 接线，只保留 mode orchestration 与 static 所有权。
4. 确认 Session source/phase/hopper 和 continuity live state 没有被错删或复制进 host。
5. 对照基线 public/SPI 声明、isolation 与 View 可用性，更新内部职责文档草稿。

## Acceptance

- [ ] 生产代码只有新 host 实现流式接管协调。
- [ ] Session private observer 与 renderer text binding 为一组资源记录。
- [ ] 所有旧符号已删除或有明确静态用途；不凭 grep 同名就删除。
- [ ] 源兼容、ADR 所有权和默认 link identity 保持。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 session 组一次；引用检查、受影响 target 编译与 git diff --check。
- 生成 evidence/25-host-contract.md，列出删除字段和仍保留字段的所有者。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/25-host-contract-old-plumbing.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不删除 continuity 的 token/generation/journal，也不把 public state 改成 host state。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
