# 09 表格方向验收证据

- 日期：2026-09-07
- Branch / HEAD：`feat/swiftUI` / `f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 依赖：local overlay 验证后已恢复 remote pin（不代表远程 CI）
- Toolchain：Xcode 26.6；scheme `InkMarkdown-Package`；iPhone 17 Pro / iOS 26.5
- 最终方向测试（`20260907-1225-ticket-09`）：
  - SwiftUI：InkCorpusSwiftUIIntegrationTests + InkMarkdownMeasurementTests → **5 passed**
  - UIKit：Presentation×2 + audit + corpus table + AccessibilityAndDynamicType → **28 passed**
  - 合计 **33 passed / 0 failed**
- 文档：更新 `docs/contributor-guide/05-modules.md` 表格职责（Presentation / adapters / helper）

## T-* 映射

| ID | 结果 | 证据 |
| --- | --- | --- |
| T-01 | 通过 | InkTablePresentationTests / audit prepared 顶层 filter |
| T-02 | 通过 | raw static replace/resize；Presentation raw 接纳 |
| T-03 | 通过 | stream 6 cell 精确计数 |
| T-04 | 通过 | reference 首列宽 + layout suite |
| T-05 | 通过 | static vs stream 列宽等价 |
| T-06 | 通过 | wrap 恢复 / scroll 自然宽；audit 宽度契约 |
| T-07 | 通过 | short append vs long rebuild |
| T-08 | 通过 | corpus table + a11y + 链接场景 |
| T-09 | 通过 | reference 不可见 / rowCount / copy 只用可见行 |
| T-10 | 通过 | resize 不重复 filter；静态 apply 不重复手势路径 |
| T-11 | 通过 | 08 删除平行协议；检索无旧符号 |
| T-12 | 通过（契约） | SwiftUI corpus/measurement 通过；**ExampleApp 手工交互未执行** |

## 未验证

- ExampleApp 窄宽切换 / 复制 / 链接点击（需人工或 UI 自动化）
- iOS 15 / iOS 18.5 样本
- 远程 GitHub 依赖解析与 CI
- 安装启动

## 职责变化

- 来源接纳 + 列宽失效 → `InkTablePresentation`
- UIKit 建行/手势/容器 → `InkTableRenderHelper` + Block/Stream adapters
- 公开 String API / `from` 工厂不变

## 过渡代码

本方向无残留平行 prepared 协议。图片/宿主方向未实施（下一批 10–17 / 18–26）。
