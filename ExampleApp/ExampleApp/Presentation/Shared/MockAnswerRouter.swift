//
//  MockAnswerRouter.swift
//  ExampleApp
//

import Foundation

/// Mock SSE 预设回答路由（纯函数；更具体规则优先于泛化规则）。
enum MockAnswerRouter {

    /// 路由目标样本标识。
    enum Sample: String, CaseIterable {
        case closures
        case structClassComparison
        case images
        case diagrams
        case collectionsComparison
        case code
        case steps
        case intro
    }

    /// 有序匹配表：index 越小优先级越高。
    private static let matchTable: [(sample: Sample, keywords: [String])] = [
        (.closures, ["闭包", "closure"]),
        (.structClassComparison, [
            "结构体与类", "结构体与 class", "struct与class", "struct 与 class",
            "值类型", "引用类型", "struct vs class", "struct/class"
        ]),
        (.images, ["图片", "image", "图文"]),
        (.diagrams, ["公式", "latex", "mermaid", "图表", "流程图"]),
        (.collectionsComparison, ["集合", "性能对照", "复杂表格", "array", "dictionary", "set"]),
        (.code, ["swift", "代码", "示例"]),
        (.steps, ["列表", "步骤", "怎么", "如何"]),
    ]

    /// 根据用户问题挑选预设 Markdown 回答。
    static func route(question: String) -> String {
        let sample = matchSample(for: question)
        return content(for: sample)
    }

    /// 返回命中的样本类型（便于测试与调试）。
    static func matchSample(for question: String) -> Sample {
        let q = question.lowercased()
        for entry in matchTable {
            if entry.keywords.contains(where: { q.contains($0.lowercased()) }) {
                return entry.sample
            }
        }
        return .intro
    }

    /// 返回指定样本的 Markdown 正文。
    static func content(for sample: Sample) -> String {
        switch sample {
        case .closures: return sampleClosures
        case .structClassComparison: return sampleStructClassComparison
        case .images: return sampleImages
        case .diagrams: return sampleDiagrams
        case .collectionsComparison: return sampleComparison
        case .code: return sampleCode
        case .steps: return sampleSteps
        case .intro: return sampleIntro
        }
    }

    // MARK: - 预设 Markdown 样本

    static let sampleClosures = """
    **Swift 闭包（Closure）专题**

    闭包是自包含的功能代码块，可以在代码中传递和使用。Swift 的闭包表达式语法简洁，是函数式编程的核心工具之一。

    ## 基本语法

    ```swift
    let greet = { (name: String) -> String in
        return "Hello, \\(name)!"
    }
    print(greet("InkMarkdown"))
    ```

    ## 捕获与逃逸

    | 特性 | 说明 |
    |------|------|
    | 值捕获 | 闭包可以捕获并持有定义上下文中的变量 |
    | @escaping | 闭包在函数返回后才执行时必须标注 |
    | @autoclosure | 自动包装表达式为闭包，延迟求值 |

    ## 尾随闭包

    当闭包是函数最后一个参数时，可写在括号外：

    ```swift
    UIView.animate(withDuration: 0.3) {
        view.alpha = 0
    }
    ```

    ## 常见陷阱

    - **循环引用**：闭包捕获 `self` 时需用 `[weak self]` 或 `[unowned self]`
    - **逃逸闭包**：异步回调（网络、动画）几乎总是 `@escaping`

    *以上为闭包专题流式渲染 demo。*
    """

    static let sampleStructClassComparison = """
    **Swift 结构体与类的对比**

    Swift 同时提供值类型（`struct`/`enum`）与引用类型（`class`），理解二者差异是写出正确 Swift 代码的基础。

    ## 核心差异

    | 维度 | struct（值类型） | class（引用类型） |
    |------|-----------------|------------------|
    | 赋值语义 | 拷贝一份 | 共享同一实例 |
    | 内存 | 栈优先（含 COW 优化） | 堆 + ARC |
    | 继承 | 不支持 | 支持单继承 |
    | 身份标识 | 无 `===` | 有 `===` 运算符 |
    | 可变性 | 方法改自身需 `mutating` | 直接修改 |

    ## 代码示例

    ```swift
    struct Point {
        var x: Double, y: Double
        mutating func moveBy(dx: Double, dy: Double) {
            x += dx; y += dy
        }
    }

    class Counter {
        var count = 0
        func increment() { count += 1 }
    }

    var a = Point(x: 0, y: 0)
    var b = a          // 拷贝
    b.x = 10           // a.x 仍为 0

    let c1 = Counter()
    let c2 = c1        // 同一实例
    c2.increment()     // c1.count 也变为 1
    ```

    ## 选型建议

    1. **默认用 struct**：语义清晰、线程安全、无引用计数负担
    2. **需要共享状态或继承时用 class**：如 UIViewController、代理模式
    3. **标准库集合全是值类型**：Array / String / Dictionary 均配合 COW

    *以上为结构体与类对比流式渲染 demo。*
    """

    static let sampleImages = """
    **流式图文混排演示**

    下面通过 SSE 流式返回 Markdown，包含文本段落与块级图片。块级图片支持**点击放大**预览。

    ## 第一张块级图

    ![流式块图1](https://picsum.photos/seed/ink-stream-1/1200/800)

    过渡说明：块级图独占一行，加载完成后可点击查看大图。

    ## 第二张块级图

    ![流式块图2](https://picsum.photos/seed/ink-stream-2/1600/1000)

    ## 行内混排

    正文里可以嵌入 ![行内图标](https://placehold.co/24x24/2563eb/ffffff/png?text=i) 小图标，行内图仅展示、不要求点击。

    ## 高清块图

    ![高清块图](https://picsum.photos/seed/ink-block/1200/800)

    ## 加载失败（可选）

    下面这张 URL 不存在，用于观察占位 / 错误态：

    ![缺失图](https://example.com/inkmarkdown-missing-image-404.jpg)

    *以上为流式图片渲染 demo，块级图可点放大。*
    """

    static let sampleDiagrams = """
    **流式公式与图表演示**

    下面通过 SSE 流式返回 Markdown，包含 LaTeX 行内/块级公式与 Mermaid 图表。
    任意 SSE 回答均已全局开启公式与图表（关键词只用于挑选样例，不控制开关）。

    ## 行内公式

    勾股定理 \\(a^2 + b^2 = c^2\\) 与欧拉公式 \\(e^{i\\pi} + 1 = 0\\) 可混排在正文中。

    ## 块级公式

    $$
    \\int_{0}^{1} x^2 \\, dx = \\frac{1}{3}
    $$

    \\[
    \\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}
    \\]

    ## Mermaid 流程图

    ```mermaid
    flowchart TD
        A[SSE 分片到达] --> B[增量解析]
        B --> C{公式/图表?}
        C -->|LaTeX| D[iosMath 渲染]
        C -->|Mermaid| E[WebKit 本地渲染]
        D --> F[位图插入气泡]
        E --> F
    ```

    ## Mermaid 序列图

    ```mermaid
    sequenceDiagram
        participant U as 用户
        participant S as MockSSEService
        participant R as InkBlockRenderer
        U->>S: 发送「展示公式与图表」
        S-->>R: 流式 Markdown 分片
        R-->>U: 逐字吐出渲染结果
    ```

    ## 失败示例

    下面是一段非法 Mermaid，用于观察统一错误条：

    ```mermaid
    this is not valid mermaid syntax [[[
    ```

    *以上为公式与图表流式渲染 demo。*
    """

    static let sampleIntro = """
    **InkMarkdown** 是一个基于 Apple [swift-markdown](https://github.com/apple/swift-markdown) 的 UIKit 渲染库。

    它把 Markdown 解析后的 Markup 树渲染成 `NSAttributedString`，可以直接喂给 `UITextView` 或 `UILabel`。

    > 这段文字就是流式返回的，正在逐字吐出，渲染走的是 `InkAttributedRenderer.render(_:)`。
    """

    static let sampleSteps = """
    接入 InkMarkdown 只需三步：

    1. 拿到 Markdown 字符串（本地文件或服务端 `content` 字段）
    2. 调用 `InkAttributedRenderer.render(_:)` 得到 `NSAttributedString`
    3. 赋值给 `textView.attributedText` 直接显示

    几个要点：

    - **解析**：100% 复用 swift-markdown
    - **渲染**：UIKit 通道，无 SwiftUI 依赖
    - **样式**：通过自定义 `InkAppearance` 定制
    """

    static let sampleCode = """
    下面是一段最小可用的接入代码：

    ```swift
    import InkMarkdown

    let markdown = "# 标题\\n\\n正文 **加粗** 内容"
    let attributed = InkAttributedRenderer.render(markdown)
    textView.attributedText = attributed
    ```

    渲染结果支持 *斜体*、`行内代码`、链接等行内元素，块级支持标题、列表、引用与代码块。
    """

    static let sampleComparison = """
    ### 一、Swift 集合类型概览

    | 核心属性 | 说明 |
    |----------|------|
    | Array | 有序、可重复，按索引访问，追加均摊 O(1) |
    | Set | 无序、元素唯一，基于哈希，成员判断 O(1) |
    | Dictionary | 键值映射，键唯一且可哈希，查找 O(1) |
    | 共同点 | 均为值类型，采用写时复制（COW） |
    | 元素要求 | Set/Dictionary 键需遵循 Hashable |
    | 遍历顺序 | Array 稳定；Set/Dictionary 不保证顺序 |
    | 底层缓冲 | 连续内存缓冲区，容量不足时按倍数扩容 |
    | 线程安全 | 值语义下天然隔离，跨线程共享需自行同步 |

    ### 二、常用操作复杂度

    **高频操作**

    1. 随机访问

    **说明：** `Array` 按下标访问是 O(1)；`Set`/`Dictionary` 无下标，按元素/键访问是均摊 O(1)。

    **建议：** 需要顺序与索引用 `Array`；只关心"是否存在"用 `Set`，避免 `array.contains` 的 O(n) 扫描。

    2. 插入与删除

    **说明：** `Array` 尾部追加均摊 O(1)，中间插入/删除 O(n)；`Set`/`Dictionary` 插入删除均摊 O(1)。

    ### 三、选型建议（优先级排序）

    **1. 先明确访问模式**

    - 动作：区分"按顺序" / "按存在性" / "按键映射"三类需求。
    - 核心原因：访问模式决定复杂度。
    - 落地效果：避免用错容器导致 O(n) 退化。

    **2. 再考虑元素约束**

    - 动作：需要去重或快速查找时优先 `Set` / `Dictionary`。
    - 核心原因：唯一性与哈希查找是它们的强项。

    ### 四、性能对照

    选取"判断成员是否存在"这一高频场景对照：

    | 对比维度 | Array | Set |
    |----------|-------|-----|
    | 成员判断 | O(n) 线性扫描 | O(1) 哈希 |
    | 内存占用 | 紧凑 | 略高（哈希表） |
    | 保持顺序 | 是 | 否 |

    ### 五、小结

    **总结：** Swift 标准库三大集合都是值类型 + COW，语义清晰、使用安全。选型的关键不在"哪个更快"，而在"访问模式匹配哪个的强项"——顺序用 `Array`、去重与查找用 `Set`、键值映射用 `Dictionary`。
    """
}

#if DEBUG
extension MockAnswerRouter {
    /// 路由表冒烟验证（Example 无独立 test target 时的内联自检）。
    static func debugValidateRoutes() -> [(question: String, expected: Sample)] {
        [
            ("介绍 Swift 闭包", .closures),
            ("closure capture list", .closures),
            ("结构体与类的对比，包含代码块与表格", .structClassComparison),
            ("请用 Markdown 写一份 Swift 结构体与类的对比", .structClassComparison),
            ("展示公式与图表", .diagrams),
            ("展示图文混排", .images),
            ("复杂表格", .collectionsComparison),
            ("Swift 集合性能", .collectionsComparison),
            ("代码示例", .code),
            ("接入步骤", .steps),
            ("你好", .intro),
        ]
    }
}
#endif
