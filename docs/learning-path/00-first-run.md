# 第 0 章：先跑起来

**难度**：零基础
**预计时间**：20 分钟

## 本章目标

在学任何概念之前，先让项目在你自己的电脑上跑起来，并且亲手调用一次 InkMarkdown 的渲染入口。学完后，你可以：

- 用 Xcode 打开项目、选中 scheme、按 Cmd-R 看到 ExampleApp 运行。
- 写一小段 Swift 代码，把一个 Markdown 字符串变成 `NSAttributedString` 并打印出来看。
- 判断自己是不是已经具备进入第 1 章的环境条件。

这一章不讲原理，只讲“怎么把它跑起来”。原理从[第 1 章](01-markdown-foundations.md)开始。

## 前置条件

- 一台 Mac，装好 **Xcode**（建议 26.x；至少要能处理 Swift 6.2 工具链）。没装过 Xcode 的话，从 App Store 或 [developer.apple.com](https://developer.apple.com/xcode/) 安装，首次打开会自动装好命令行工具。
- 能访问网络：首次打开项目时，Xcode 需要联网解析 `swift-markdown` 依赖。
- 不需要提前会 Swift Package Manager、不需要提前懂 TextKit。

## 0.1 拿到代码

打开终端（Terminal），克隆仓库：

```bash
git clone <你的仓库地址>
cd InkMarkdown
```

如果你已经有本地副本，直接 `cd` 进项目根目录即可。

## 0.2 用 Xcode 打开并运行 ExampleApp

这是最省事的路径：不用自己配 Scheme，也不用命令行 build。

1. 双击打开 `ExampleApp/ExampleApp.xcodeproj`（或者在终端里执行 `open ExampleApp/ExampleApp.xcodeproj`）。
2. 第一次打开时，Xcode 会自动解析 Swift Package 依赖（`swift-markdown`），窗口顶部会出现进度条。**等它跑完**，不要在这个阶段点 Run，否则可能因为依赖未就绪而报错。
3. 在窗口左上角的 Scheme 选择器里确认已经选中 **ExampleApp**（这是唯一的 App scheme，通常已经是默认选中状态）。
4. 在 Scheme 选择器旁边选一个 iOS 模拟器作为运行目标，比如 "iPhone 17 Pro"。任意一台可用的模拟器都行。
5. 按 **Cmd-R**（或点左上角的三角形运行按钮）。
6. 等模拟器启动、App 装好，你会看到一个列表页，顶部有几个分类（例如"Markdown 标准样式"）。

到这一步，说明项目本体、依赖解析和 UIKit 渲染链路都是通的。

### 在 App 里确认渲染是正常的

1. 点开 "Markdown 标准样式"。
2. 找到并点开 "一级标题 H1"。
3. 页面上应该能看到一个渲染后的大号加粗标题；如果这个 Demo 提供了"查看源码"之类的切换，对照一下 `#` 开头的原始 Markdown 文本和你看到的显示效果。
4. 返回上一级，随便再点开一两个条目（比如包含粗体或表格的），确认加粗文字和表格网格都能正常显示。

看到标题、粗体、表格都能正确显示，说明 ExampleApp 运行环境完全没问题，可以放心往下学。

## 0.3 亲手调用一次渲染入口

光看 App 界面还不够——你要亲眼确认："我知道调用哪一行代码，能把 Markdown 字符串变成 `NSAttributedString`"。

InkMarkdown 的公开渲染入口是 `InkAttributedRenderer`，位于 `Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift`。它最常用的一个方法签名是：

```swift
public static func render(
  _ source: String,
  configuration: InkConfiguration = .standard
) -> NSAttributedString
```

也就是说，只要 `import InkMarkdown`，一行代码就能拿到渲染结果：

```swift
let attributed = InkAttributedRenderer.render("# Hello, InkMarkdown")
```

### 在 ExampleApp 里试一下

最快的验证方式：借用 ExampleApp 已经链接好 `InkMarkdown` 的环境，临时加两行代码打印结果。

1. 打开 `ExampleApp/ExampleApp/AppDelegate.swift`。
2. 找到 `application(_:didFinishLaunchingWithOptions:)` 方法，在 `return true` 之前插入：

   ```swift
   import InkMarkdown // 如果文件顶部还没有，先加上这一行

   let attributed = InkAttributedRenderer.render("# Hello, **InkMarkdown**")
   print("字符数：\(attributed.length)")
   print("完整内容：\(attributed.string)")
   attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
     print("range \(range) -> \(attrs.keys.map { $0.rawValue })")
   }
   ```

3. 按 Cmd-R 再跑一次 ExampleApp，打开 Xcode 底部的 Console（`Cmd-Shift-Y` 可以切换显示/隐藏）。

你应该在 Console 里看到类似这样的输出（属性 key 的具体命名可能略有出入）：

```text
字符数：18
完整内容：Hello, InkMarkdown
range {0, 18} -> ["NSFont", "NSColor", "NSParagraphStyle"]
```

`# Hello, **InkMarkdown**` 整行是一个一级标题，而标题本身就是加粗样式，所以 `Hello, ` 和 `InkMarkdown` 用的是同一套属性——`enumerateAttributes` 只会枚举出**一段** `{0, 18}`。看到"只有一段"是对的，别以为自己弄错了。

重点不是数字本身，而是确认三件事：

- 返回值是一个 `NSAttributedString`，`.string` 属性就是纯文字，标记符号（`#`、`**`）已经被去掉了——所以是 18 个字符，而不是原始那串带符号文本的长度。
- `enumerateAttributes` 能枚举出样式区间——这就是"结构"变成"样式"的落地方式，第 3 章会详细解释这是怎么回事。
- 想亲眼看到"加粗和普通文字属性不同"，把输入换成普通段落里嵌加粗，例如 `普通**粗体**段落`，就会看到字体在不同区间发生变化（第 4 章的端到端走查正是用这个例子）。

验证完记得把这几行临时代码删掉，或者保留着当自己的实验沙盒——不影响后续章节。

## 0.4（可选）给 AI 编程客户端用的路径：XcodeBuildMCP

如果你是通过 AI 编程助手（比如配了 XcodeBuildMCP 的 Claude Code / Cursor 等）在操作，而不是自己手动点 Xcode，可以让它：

1. 查看当前 session 的 project / scheme / simulator 默认值。
2. 缺失时用 XcodeBuildMCP 的项目发现和 simulator 列表能力去补齐。
3. 选中 `ExampleApp` scheme 和一台可用模拟器（不要写死设备 UUID），构建并运行。

这条路径是给自动化工具用的效率优化，**不是必须的**。普通人类读者按上面 0.2 节手动点几下 Xcode 就完全够用。如果你的工具没装 XcodeBuildMCP，也不必特意去装——回退到 0.2 的手动流程即可。更完整的工具链说明见[开发指南](../contributor-guide/04-development.md)。

## 你已经成功了，如果……

- [ ] `ExampleApp` 能在模拟器里跑起来，能看到分类列表。
- [ ] 你在"Markdown 标准样式"里看到过至少一个标题、一段粗体和一个表格正确显示。
- [ ] 你在 Console 里亲眼看到过 `InkAttributedRenderer.render(_:)` 的返回值——一个 `.string` 去掉了 Markdown 符号、`enumerateAttributes` 能枚举出样式区间的 `NSAttributedString`。

三项都做到，说明你的环境、依赖和渲染链路都已经跑通，可以带着"我知道最终产物长什么样"的直觉进入下一章。

## 遇到问题怎么办

- Xcode 卡在解析依赖：检查网络能不能访问 GitHub；网络受限时可参考[开发指南的离线依赖方案](../contributor-guide/04-development.md#准备-swift-markdown-依赖)。
- 编译或运行报错、模拟器起不来：按[开发指南的排查问题流程](../contributor-guide/04-development.md#排查常见渲染问题)逐条对照。
- 只是想先确认"库到底支持到什么程度"而不想跑代码：直接看[当前状态](../current-status.md)。

## 下一步

环境和第一次调用都验证过了，进入[第 1 章：Markdown 从哪里开始](01-markdown-foundations.md)，开始学 Markdown 本身的概念模型。
