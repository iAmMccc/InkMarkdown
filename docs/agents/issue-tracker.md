# Issue tracker: Local Markdown

Issues 与 specs 以仓库内 Markdown 文件托管，路径为 `.scratch/`。

## Conventions

- 一个 feature 一个目录：`.scratch/<feature-slug>/`
- Spec 文件：`.scratch/<feature-slug>/spec.md`
- 实现 ticket：`.scratch/<feature-slug>/issues/<NN>-<slug>.md`，从 `01` 起编号；**不要**合并成单个 tickets 文件
- Triage 状态写在 issue 文件顶部的 `Status:` 行（角色字符串见 [triage-labels.md](./triage-labels.md)）
- 评论与对话历史追加在文件末尾的 `## Comments` 标题下

## Issue 文件最小模板

```markdown
# [标题]

Status: needs-triage

## Summary

[一句话说明要做什么]

## Context

[链接到 spec、ADR、相关源码路径]

## Acceptance

- [ ] …

## Comments

```

## When a skill says "publish to the issue tracker"

在 `.scratch/<feature-slug>/` 下创建新文件（目录不存在则创建）。

## When a skill says "fetch the relevant ticket"

读取用户给出的路径，或按 feature 目录 + issue 编号定位文件。

## Wayfinding operations

供 `/wayfinder` 使用。**map** 是一个文件，**child** 是多个 ticket 文件。

- **Map**：`.scratch/<effort>/map.md`（Notes / Decisions-so-far / Fog 正文）
- **Child ticket**：`.scratch/<effort>/issues/NN-<slug>.md`，从 `01` 编号；正文写问题；`Type:` 记录类型（`research` / `prototype` / `grilling` / `task`）；`Status:` 记录 `claimed` / `resolved`
- **Blocking**：文件顶部 `Blocked by: NN, NN`；所列 ticket 均为 `resolved` 时视为 unblocked
- **Frontier**：扫描 `.scratch/<effort>/issues/`，取 open、unblocked、unclaimed 的第一个（按编号）
- **Claim**：设 `Status: claimed` 并保存后再开工
- **Resolve**：在 `## Answer` 下写结论，设 `Status: resolved`，并在 `map.md` 的 Decisions-so-far 追加上下文指针
