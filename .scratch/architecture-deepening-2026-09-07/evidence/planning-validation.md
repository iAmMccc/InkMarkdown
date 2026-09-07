# 规格与 tickets 静态检查记录

日期：2026-09-07
基线：feat/swiftUI / ee049f0。

## 本轮实际完成

- 创建 1 份总规格、3 份详细规格、27 份独立 ticket、执行指南、交接 prompt、依赖/覆盖索引和机器可读 manifest。
- 核对当前 table、image、Session/Coordinator/continuity 源码及相关测试断言；未把此前报告中的候选当成已复现缺陷。
- 核对仓库 tracker 的 Status/Blocked by 约定，所有票为 ready-for-agent；没有勾选实施完成项。
- 使用本机 xcodebuild -help 只读确认测试枚举、过滤和 destination 参数存在；没有执行构建或测试枚举。

## 自动检查结果

- 27 个 ticket ID 唯一、引用全部存在，依赖图无环。
- Markdown 的 Blocked by 与 ticket-manifest.json 一致。
- G-01–G-10、T-01–T-12、I-01–I-12、S-01–S-14 共 48 条验收要求全部被覆盖，无多余编号。
- 258 个本地 Markdown 链接解析成功；计划新建源码文件使用明确文字标记，不伪装成已有文件链接。
- 每票均有 Outcome、步骤、Acceptance、Verification、禁止范围与 Comments。
- 未发现新文档尾部空格，实施复选框全部未勾选。

## 内容复核

- 去掉流式列宽迁移对静态迁移的不必要依赖：07 依赖 06；旧协议删除 08 同时依赖 05/07。
- 区分公开 raw 输入的新接纳与 prepared 内容的重建，明确非幂等 filter 次数。
- 图片 ready 保持同步、异步结果延后安全交付；pending/completion 重入、预取消和 owner 释放均有责任票。
- 保留 Attachment identity、Preview high-res generation、Session source/phase 与 continuity live state；不把所有 generation 都当成重复代码删除。
- 新 host 必须经真实生产 Coordinator 接入，再验证 UIHostingController remount；仅直接测试新 module 不算完成迁移。

## 未执行与工作树

本轮没有修改 Sources、Tests、Package.swift、ExampleApp 或已有 ADR/领域模型，没有运行 App 构建、Simulator 测试、交互验收或远程 CI，也没有提交/push。

开始前已有 AGENTS.md、CLAUDE.md、docs/agents/domain.md 修改及两个 docs/agents 未跟踪文件；结束时这些既有改动仍保留，新增范围仅此规划目录。所有后续实施票尚未执行。
