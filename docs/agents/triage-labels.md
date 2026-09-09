# Triage Labels

Matt skills 使用五个 canonical triage 角色。本仓库在本地 Markdown issue 文件的 `Status:` 行中记录对应状态。

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | 待维护者评估                             |
| `needs-info`               | `needs-info`         | 等待补充信息                             |
| `ready-for-agent`          | `ready-for-agent`    | 规格完整，可由 agent 实现                |
| `ready-for-human`          | `ready-for-human`    | 需要人工处理                             |
| `wontfix`                  | `wontfix`            | 不处理                                   |

当 skill 提到某个 triage 角色（例如 "apply the AFK-ready triage label"），在 issue 文件顶部写 `Status: ready-for-agent`（或上表对应字符串）。

Wayfinder child ticket 另用 `Status: claimed` / `Status: resolved`，与上表五角色并存于不同 workflow。
