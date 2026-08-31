# Domain Docs

Engineering skills 探索本仓库时应如何消费领域文档。

## Before exploring, read these

- **`CONTEXT.md`**（仓库根目录）：跨模块复用的领域术语表；不含实现细节
- **`docs/decisions/`**：架构决策记录（ADR）。索引见 [docs/decisions/README.md](../decisions/README.md)；动手前读与当前区域相关的 ADR

若上述文件不存在，**静默继续**。不要预先建议创建；`/domain-modeling`（经 `/grill-with-docs`、`/improve-codebase-architecture`）在术语或决策落地时 lazy 创建/更新。

## File structure

Single-context 仓库：

```
/
├── CONTEXT.md
├── docs/decisions/
│   ├── README.md
│   ├── ADR-001-swift-markdown-dependency-pinning.md
│   └── …
└── Sources/
```

ADR 命名：`ADR-00X-<slug>.md`，编号递增且只增不删；变更时写新 ADR 或将旧 ADR 标为 Amended / Superseded。**不要**使用 `docs/adr/0001-*.md` 格式。

## Use the glossary's vocabulary

输出中命名领域概念时（issue 标题、重构提案、测试名），使用 `CONTEXT.md` 中的术语。不要漂移为 glossary 刻意避免的同义词。

所需概念不在 glossary 中时：要么你在发明项目未使用的语言（请 reconsider），要么是真实缺口（交给 `/domain-modeling` 补充）。

## Flag ADR conflicts

若输出与现有 ADR 矛盾，显式标注，不要静默覆盖：

> _Contradicts ADR-008 (SwiftUI adapter architecture), but worth reopening because…_
