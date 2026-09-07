# InkMarkdown 三方向架构深化规格

Status: ready-for-agent

Implementation authorization: 未授权。本轮只创建规格和 tickets；`ready-for-agent` 表示信息完整，不表示开始实现。

## 1. 输入、事实与决定的区别

- 用户已选定三个方向：表格呈现、图片呈现订阅、渲染会话宿主接管；要求足够细致，供后续能力较弱的模型执行。
- 当前代码基线：2026-09-07，`feat/swiftUI`，`ee049f0`。实施时重新核对 HEAD 和工作树；不得把这一 SHA 当作永远有效的事实。
- 事实来源：当前源码、测试断言、[领域词汇](../../CONTEXT.md)、[ADR-008](../../docs/decisions/ADR-008-swiftui-adapter-architecture.md)、[ADR-009](../../docs/decisions/ADR-009-block-presentation-continuity.md)、[ADR-006](../../docs/decisions/ADR-006-opt-in-image-rendering.md)、[ADR-007](../../docs/decisions/ADR-007-local-generated-diagrams-and-formulas.md)、[ADR-011](../../docs/decisions/ADR-011-image-store-configuration-ownership.md)。此前 HTML 报告位于临时目录，本规格已独立收录所需内容，不依赖它存续。
- **本规格选定的内部设计**：下文命名、类型草图、迁移顺序由此次规格工作提出；不是用户逐一确认过的决定，也不是已经存在的代码。它们构成后续执行默认方案。
- **保守假设**：保持公共用法和既有产品语义；不新增图片重试、不改变表格复制内容、不扩展 SwiftUI presentation adapter 的职责。
- 没有尚待用户决定的产品级阻塞问题，因此不整体标记 `needs-info`。若当前源码与本文约束冲突，记录冲突及最小待决项，仅暂停受影响 ticket，不能自行放宽验收标准。

## 2. 问题与目标

| 方向 | 当前摩擦 | 深化后的结果 | 保留的深 module |
| --- | --- | --- | --- |
| 表格 | raw/prepared 数组、参考行、宽度缓存及测量规则在 helper 和两个视图间传播 | 单元格来源与列宽失效有集中所有者；调用方消费一致的表格呈现状态 | 富文本 renderer 与现有布局能力 |
| 图片 | block、attachment、preview 重复解释 Store resolve、订阅、取消与过期结果 | 一个内部订阅生命周期 module，三个呈现 adapter 保留视觉差异 | InkImageStore 缓存、预算与调度 |
| 宿主接管 | Coordinator 与 Session 分别管理 token、cycle、binding owner、observer owner、环境暂存 | adapter 内部的流式宿主 module 完整协调接管和释放 | Session 内容/阶段；continuity 块呈现状态 |

depth 的验收不是文件变短：调用方必须少知道一组顺序或一致性条件。只把原代码移进 helper、仍暴露同样的并行参数与 owner 操作，不算完成。

## 3. 文档与执行入口

- [表格详细规格](table-spec.md)：T-01 至 T-12。
- [图片详细规格](image-spec.md)：I-01 至 I-12。
- [宿主接管详细规格](session-spec.md)：S-01 至 S-14。
- [tickets 与依赖索引](tickets.md)：每票独立文件、覆盖映射、依赖图。
- [验证与执行指南](execution-guide.md)：测试发现、命令模板、证据格式、停止条件。
- [交给执行模型的完整 prompt](handoff.md)。

## 4. 全局硬约束

| ID | 约束 |
| --- | --- |
| G-01 | 保持 UIKit-first、Markup 直渲染、独立 InkMarkdownSwiftUI product。不得引入 InkIR、新 target、新包依赖、反向 SwiftUI import。 |
| G-02 | 保持所有现有 public / SPI interface 的源兼容性、actor isolation 和可用性；新设计默认 internal/private。不能删除已 deprecated 的 0.0.1 初始化器或别名。 |
| G-03 | 保持 iOS/iPadOS 15 deployment target；Swift tools 6.2、Swift 5 language mode、StrictConcurrency 设置以当前 manifest 为准。不得为让测试通过改语言模式。 |
| G-04 | 显式 Store 预算由所有者决定；默认 Store 由渲染宿主持有。不得重配全局 Store、增加磁盘缓存或将生成内容绕过 Store。 |
| G-05 | Session 持有 canonical source 与阶段；continuity 持有 live 块呈现状态。宿主 module 不复制 Thought 折叠真相、lineage 或 measurement journal。 |
| G-06 | 不修改 SSE transport、业务状态、滚动策略、source limit、字符步进、LaTeX/Mermaid 渲染算法及安全策略。 |
| G-07 | 保留工作树中的无关修改；不创建其他 checkout，不自行提交、push、建 PR、发布或改依赖 pin。实施授权如另有明确范围，以该范围为准。 |
| G-08 | 验证产物必须记录 SHA、diff 范围、真实命令、scheme、destination、通过/失败/跳过数；历史报告和子代理总结不等于本次通过。 |
| G-09 | 迁移完成后同一规则只有一个生产所有者；允许迁移期兼容转发，最终必须删除无人使用的旧路径。不得只增加一层转发。 |
| G-10 | 文档不声称性能提升、runtime 验收或发布完成，除非本次有相应证据。 |

## 5. 范围与顺序

采用 expand–migrate–contract。先用真实行为建立基线，再引入最小内部状态，逐入口迁移，删除重复协调，执行方向验收，最后整合验收。

三个方向没有产品依赖。编号按表格、图片、宿主排序仅便于逐票执行，不构造虚假的串行依赖。若后来并行执行，需遵守 tickets.md 的文件冲突约束；当前文档不自动授权创建子代理。

基线票 01 是三个方向共同前置，避免后续模型把既有失败误当成新回归或直接修改测试。最终票 27 依赖三个方向验收票 09、17、26。

## 6. 测试策略

- 测试跨生产 interface，断言文本、几何、加载/取消次数、状态、宿主内容等可观察结果；不为每个私有方法写对应测试。
- 纯 UIKit 测量与呈现必须在 iOS Simulator 上运行；不可用 macOS `swift test` 的 UIKit 缺失判定库失败。
- 新内部 module 可以通过 `@testable import` 测试其行为，但禁止断言私有缓存字典、owner 数值或 UUID 的具体值。
- 异步 fixture 采用显式事件和有界等待；不靠固定长 sleep、真网图片、随机顺序或截图像素比对验证生命周期。
- 现有端到端关键测试只有在新测试覆盖同一输入、触发与输出后才能删；不得以“减少重复”为由删除几何、交互或实际宿主测试。
- iOS 18 与 26 是建议的本轮运行样本，执行时动态发现可用 runtime。最低平台仍为 15；没有 iOS 15 runtime 时明确列为未验证，不谎称完整发布验收，也不强制安装历史 runtime。

## 7. 完成定义

- [ ] T、I、S 验收条目全部有对应实现和真实证据。
- [ ] 所有迁移入口走新的生产路径；旧重复协调已删除，既有深 module 未被掏空。
- [ ] 方向测试、跨方向集成、四 product consumer 编译和 ExampleApp 相关交互分别记录结果。
- [ ] 公共 interface 对照无意外变化；无新依赖、反向 import 或 manifest 污染。
- [ ] current-status 仅追加已观察事实；未执行/环境阻塞项明确保留。
- [ ] 本轮只交付文档时，上述复选框必须保持未勾选。

## 8. 待实施时核对的技术事实

这些属于有确定验证方法的环境事实，不是产品待决项：实际 scheme / Simulator；基线测试是否通过；目标文件是否已被其他任务改动；本地依赖覆盖是否存在；旧内部函数是否有本文未列出的调用者。

实现模型发现上述变化后先重新定位源码并更新 evidence，不得凭历史文件名强行编辑。特别是历史 InkStreamMarkdownViewTests.swift 已不在当前测试目录；当前宿主关键链路在 InkBlockPresentationContinuityTests.swift 等文件。
