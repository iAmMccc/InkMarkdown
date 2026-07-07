import Foundation

/// 模拟服务端 SSE（Server-Sent Events）流式接口。
///
/// 真实业务里，`onChunk` 对应 SSE 的每一帧 `data:` 回调，`onComplete`
/// 对应 `[DONE]` 事件。这里用 `Timer` 把预设的 Markdown 回答按字符切块逐帧吐出，
/// 还原「边收边吐」的网络流式手感——demo 不依赖任何真实网络。
final class MockSSEService {

    static let shared = MockSSEService()
    private init() {}

    /// 每帧推送的字符数（模拟网络分块，不一定按字一帧）。
    private let charsPerChunk = 2
    /// 帧间隔（秒），越小吐字越快。
    private let chunkInterval: TimeInterval = 0.03

    private var timer: Timer?

    /// 发起一次流式问答。
    /// - Parameters:
    ///   - question: 用户问题，用于挑选预设回答。
    ///   - onChunk: 每收到一帧文本片段时回调（已在主线程）。
    ///   - onComplete: 全部推送完毕时回调（已在主线程）。
    func askStream(
        question: String,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        // 上一次未结束的流先取消，避免串台。
        cancel()

        let answer = Self.answer(for: question)
        let scalars = Array(answer)
        var cursor = 0

        // 先模拟「服务端首字延迟」，让思考中动画露个脸。
        let firstByteDelay: TimeInterval = 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + firstByteDelay) { [weak self] in
            guard let self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.chunkInterval, repeats: true) { [weak self] t in
                guard let self else { return }
                guard cursor < scalars.count else {
                    t.invalidate()
                    self.timer = nil
                    onComplete()
                    return
                }
                let end = min(cursor + self.charsPerChunk, scalars.count)
                let chunk = String(scalars[cursor..<end])
                cursor = end
                onChunk(chunk)
            }
        }
    }

    /// 中断当前流（页面退出或重新发送时调用）。
    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 预设回答

    /// 根据问题关键字挑选一条预设 Markdown 回答；命中不到走通用兜底。
    private static func answer(for question: String) -> String {
        let q = question.lowercased()
        if q.contains("值类型") || q.contains("struct") || q.contains("引用") || q.contains("类型") {
            return sampleValueTypes
        }
        if q.contains("表格") || q.contains("对比") || q.contains("集合") || q.contains("性能") {
            return sampleComparison
        }
        if q.contains("swift") || q.contains("代码") || q.contains("示例") {
            return sampleCode
        }
        if q.contains("列表") || q.contains("步骤") || q.contains("怎么") || q.contains("如何") {
            return sampleSteps
        }
        return sampleIntro
    }

    /// 结构测试点：列表项内含 | 字符，验证不被误判为表格。
    private static let sampleValueTypes = """
    **值类型 vs 引用类型**

    - **struct（值类型）**（拷贝语义：值拷贝 | 存储：栈优先 | 可变性：需 mutating）
      > Swift 的 `struct`、`enum`、元组都是值类型。赋值或传参时整体拷贝一份，互不影响。标准库里 `Array`、`String`、`Dictionary` 全是值类型，配合写时复制（Copy-on-Write）在语义上是值、性能上避免无谓拷贝。

    **要点背景**

    - **class（引用类型）**：赋值传递的是引用，多个变量指向同一实例。适合需要共享状态、身份标识（`===`）或继承的场景，如视图控制器、单例。引用类型带来 ARC 引用计数开销与循环引用风险，需用 `weak` / `unowned` 打破。

    **常见值/引用类型对照**

    - Int / Double / Bool（类别：值类型 | 归属：标准库 | 备注：基础数值，栈分配）
    - String（类别：值类型 | 归属：标准库 | 备注：COW，底层缓冲区按需拷贝）
    - Array / Dictionary / Set（类别：值类型 | 归属：标准库 | 备注：COW 集合）
    - Optional（类别：值类型 | 归属：标准库 | 备注：本质是 enum）
    - UIView / UIViewController（类别：引用类型 | 归属：UIKit | 备注：需注意循环引用）
    - NSObject 子类（类别：引用类型 | 归属：Foundation | 备注：兼容 Objective-C 运行时）

    **选择建议**

    - **默认选值类型**：Swift 官方指引优先用 `struct`，语义清晰、天然线程安全、无引用计数负担。
    - **需要身份或共享时用 class**：当"两处引用同一个对象"是需求本身（如缓存、代理）而非巧合时，才用引用类型。
    - **写时复制**：值类型集合看似"每次拷贝很贵"，实际标准库用 COW 延迟到真正写入才拷贝，读多写少几乎零成本。
    - **mutating 关键字**：值类型的方法要修改自身属性必须标 `mutating`，这是编译器在提醒你"这里会产生一次语义上的整体变更"。

    **延伸阅读**

    - https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/

    *以上为 Swift 语言知识点，用于演示流式渲染。*
    """

    private static let sampleIntro = """
    **InkMarkdown** 是一个基于 Apple [swift-markdown](https://github.com/apple/swift-markdown) 的 UIKit 渲染库。

    它把 Markdown 解析后的 Markup 树渲染成 `NSAttributedString`，可以直接喂给 `UITextView` 或 `UILabel`。

    > 这段文字就是流式返回的，正在逐字吐出，渲染走的是 `InkAttributedRenderer.render(_:)`。
    """

    private static let sampleSteps = """
    接入 InkMarkdown 只需三步：

    1. 拿到 Markdown 字符串（本地文件或服务端 `content` 字段）
    2. 调用 `InkAttributedRenderer.render(_:)` 得到 `NSAttributedString`
    3. 赋值给 `textView.attributedText` 直接显示

    几个要点：

    - **解析**：100% 复用 swift-markdown
    - **渲染**：UIKit 通道，无 SwiftUI 依赖
    - **样式**：通过自定义 `InkAppearance` 定制
    """

    private static let sampleCode = """
    下面是一段最小可用的接入代码：

    ```swift
    import InkMarkdown

    let markdown = "# 标题\\n\\n正文 **加粗** 内容"
    let attributed = InkAttributedRenderer.render(markdown)
    textView.attributedText = attributed
    ```

    渲染结果支持 *斜体*、`行内代码`、链接等行内元素，块级支持标题、列表、引用与代码块。
    """

    private static let sampleComparison = """
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
