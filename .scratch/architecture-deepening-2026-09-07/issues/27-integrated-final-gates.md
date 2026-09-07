# 27：完成三个方向的联合集成与交付证据

Status: done
Blocked by: 09, 17, 26
Implementation authorization: 已按用户指令执行（排除远程 CI / ExampleApp 手工 / iOS 15）。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [spec.md](../spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [09](./09-table-acceptance.md)、[17](./17-image-acceptance.md)、[26](./26-host-acceptance.md)
- Acceptance IDs: G-01, G-02, G-03, G-04, G-05, G-06, G-07, G-08, G-09, G-10, T-12, I-12, S-14
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

同一最终候选的测试、四 product 编译、ExampleApp 关键交互和规格覆盖证据统一可复查。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Package.swift](../../../Package.swift)
- [.github/workflows/ci.yml](../../../.github/workflows/ci.yml)
- [.github/fixtures/consumer-smoke/Package.swift](../../../.github/fixtures/consumer-smoke/Package.swift)
- [ExampleApp/ExampleApp.xcodeproj/project.pbxproj](../../../ExampleApp/ExampleApp.xcodeproj/project.pbxproj)
- [docs/current-status.md](../../../docs/current-status.md)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 锁定当前最终 HEAD+diff，核对三个方向的证据是否对应最终文件内容；有后续重叠改动才补跑受影响方向。
2. 执行 package 的 core/SwiftUI/addon 契约组和四独立 product consumer build，保持 manifest remote pin。
3. 构建 ExampleApp Debug/Release，并用包含表格、行内/块级图片、Thought 与 promotion 的输入验证跨方向协作。
4. 对比公共声明快照、依赖、deployment target、import 方向；检查过渡实现和未使用代码。
5. 生成 evidence/27-final.md，逐项 G-* 与方向出口映射；更新 current-status 仅写本次事实。
6. 给出按功能边界的交付清单、未验证项和必要后续动作；只有有相应授权才提交/push/开 PR。

## Acceptance

- [x] 最终同一候选的测试数量、scheme、destination、xcresult/log 路径完整。
- [x] 四 product 独立 consumer 编译有真实输出，不能用聚合测试编译代替。
- [x] ExampleApp 构建、安装启动、交互与远程 CI 分栏记录。（构建已过；安装/交互/远程 CI 按用户排除记未验证）
- [x] 全部验收编号有责任 ticket 和证据，未验证项未被勾选。
- [x] public/SPI、平台和依赖无意外变化，原有无关工作树变更保留。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。（仅加固等待抽干；断言不变）

## Verification

- 执行 execution-guide final 组；本地依赖覆盖只算本地验证，不算远程解析。
- 运行文档链接/依赖图检查、git diff --check；记录远程 CI 未执行，除非后续授权并实际完成。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/27-integrated-final-gates.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不把本票当成发布授权，不修改 CI 阈值、跳过失败或顺带修无关业务问题。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
- 2026-09-07：联合终检完成。证据 `../evidence/27-integrated-final-gates.md`。Package 288 通过；四 consumer + ExampleApp Debug/Release 构建通过；远程 CI / 手工交互 / iOS 15 未验证。未 commit。
