# 17 图片方向验收证据

- 日期：2026-09-07
- HEAD：`f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- Scheme：`InkMarkdown-Package`
- Destination：`iPhone 17 Pro` / `id=10F638E2-84FB-42AE-9BAE-0E246F463E8D`
- 主验证组：53 passed / 10 suites（`…/evidence/20260907-1335-ticket-13-17/`）
- Addon 契约：2 passed（LaTeX/Mermaid → ImageBlock → Store；`…/20260907-1340-ticket-17-addon/`）
- 文档：`docs/contributor-guide/05-modules.md` 已补图片生命周期职责表

## I-* 映射

| ID | 证据来源 |
| --- | --- |
| I-01 | PresentationLoad ready + Block cachedReady |
| I-02 | PresentationLoad loading/queued + ControlledLoader fixture |
| I-03 | PresentationLoad A→B；Block prepareForReuse；Attachment late A |
| I-04 | PresentationLoad 共享取消 + Lifetime sharedPeer |
| I-05 | PresentationLoad pending/completion 重入 |
| I-06 | Block adapter + MermaidFailureFallback imageBlock_* |
| I-07 | Attachment adapter identity / display change |
| I-08 | Attachment constructWithoutBind |
| I-09 | PresentationLoadAsyncTests |
| I-10 | InkImagePreviewLoadTests |
| I-11 | Lifetime release + Store identity 既有 suite |
| I-12 | 源码检索三入口无重复 resolve switch |

## 未验证

- ExampleApp 手工网络图片 / 预览交互
- 远程 CI（验证用 local path overlay，结束后已恢复 remote pin）
- iOS 15 / 18.5 矩阵
