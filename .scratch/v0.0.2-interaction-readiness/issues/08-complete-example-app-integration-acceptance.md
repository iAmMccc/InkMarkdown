# 08: 完成 ExampleApp 跨功能人工验收

**What to build:** 提供并执行一套可操作的 ExampleApp 验收路径，证明语义、表格、链接、响应式布局和网络图片在当前 iPhone/iPad 宿主中共同工作。验收结果必须可复核，并明确区分产品失败、环境失败和未验证项。

**Blocked by:** 02 / 修正 loose list 与混合嵌套语义；04 / 统一正文、表格与流式链接交互；05 / 完成零宽度到 Split View 的响应式布局；07 / 建立有界、可取消的网络图片加载。

**Status:** ready-for-agent

- [ ] ExampleApp 当前主导航可访问列表、复杂表格、表格复制、正文/表格/streaming 链接、inline/block 图片与失败 fallback 场景。
- [ ] iPhone 竖屏与横屏完成静态、表格、链接、图片和 streaming/promotion 走查。
- [ ] iPad 全屏、约 1/2、约 1/3 宽度及 Split View 连续拖动完成相同关键场景走查。
- [ ] 旋转和宽度变化后无裁切、零高度残留、布局循环或块呈现状态丢失。
- [ ] `placehold.co` 完成固定图片真实网络成功路径；`picsum.photos` 完成重定向与真实外部链路。
- [ ] 每项证据记录候选 commit SHA、入口、设备、系统、方向、窗口宽度、输入、步骤、预期、实际及 PASS/FAIL/BLOCKED。
- [ ] 第三方图片服务故障记录为环境失败，不通过放宽图片资源安全边界掩盖。
- [ ] 保留所有已有 VoiceOver 行为；不新增完整朗读、表格无障碍树、VoiceOver UI test 或系统焦点编排。
- [ ] UI、视觉和真实交互只做手工验收；禁止新增 UI automation、视觉 snapshot 或纯视觉单元测试。
- [ ] 不把当前 runtime 结果宣称为 iOS/iPadOS 14–15 最低版本或真机性能证据。

