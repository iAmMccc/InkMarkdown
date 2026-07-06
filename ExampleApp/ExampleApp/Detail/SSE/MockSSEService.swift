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
        if q.contains("联系") || q.contains("触达") || q.contains("座机") || q.contains("信达") {
            return sampleContact
        }
        if q.contains("股权") || q.contains("股东") || q.contains("表格") || q.contains("诊断") {
            return sampleEquityReport
        }
        if q.contains("swift") || q.contains("代码") || q.contains("示例") {
            return sampleCode
        }
        if q.contains("列表") || q.contains("步骤") || q.contains("怎么") || q.contains("如何") {
            return sampleSteps
        }
        return sampleIntro
    }

    /// 真实推流数据复现：列表项内含 | 字符，验证不被误判为表格。
    private static let sampleContact = """
    **优选联系人**

    - **张卫东**（置信度：高 | 角色：法定代表人、董事长、董事会秘书 | 时效：现任）
      > 决策权核心，推测为实际控制人，掌握人事与财务控制权。作为工商登记的法定代表人及董事长，是触达该企业的最高优先级对象。目前公开渠道未直接收录其个人手机号，建议通过总机转接或函件联系。

    **关键人员背景**

    - **张卫东**：担任中国信达资产管理股份有限公司法定代表人、董事长及董事会秘书。其身兼多职且被标记为疑似实控人，表明其在公司战略制定及重大人事任免上拥有最终决定权。作为央企背景金融机构的一把手，其行程通常由董事会办公室或总裁办安排。联系建议：优先尝试通过公司总机转接"董事会办公室"或"董事长秘书"，或向注册地址发送正式公函。

    **完整联系方式列表**

    - 座机：010-63080000（联系人：无 | 来源：企业年报 | 置信度：中 | 角色：公司总机/公开号码，最可能转接至高层）
    - 座机：0551-65802030（联系人：张工 | 来源：招投标 2019/2018 | 置信度：高 | 角色：招标方联系人，非张卫东本人）
    - 座机：+852-28520456（联系人：雷学华 | 来源：招投标 2026 | 置信度：中 | 角色：招标方联系人，香港分部）
    - 座机：0551-62897997（联系人：张啸 | 来源：招投标 2024 | 置信度：中 | 角色：招标方联系人）
    - 座机：0551-65802011（联系人：叶经理 | 来源：招投标 2024 | 置信度：中 | 角色：招标方联系人）
    - 座机：010-66234436（联系人：刘晓龙 | 来源：招投标 2023 | 置信度：中 | 角色：招标方联系人）
    - 座机：00852-28520927（联系人：江建锐 | 来源：招投标 2022 | 置信度：中 | 角色：招标方联系人）
    - 座机：00852-28520904（联系人：江建锐 | 来源：招投标 2022 | 置信度：中 | 角色：招标方联系人）
    - 座机：00852-35895914（联系人：江建锐 | 来源：招投标 2022 | 置信度：中 | 角色：招标方联系人）
    - 座机：00852-39895923（联系人：陈益华 | 来源：招投标 2022 | 置信度：中 | 角色：招标方联系人）
    - 座机：010-63080122（联系人：袁佳宁 | 来源：招投标 2020 | 置信度：中 | 角色：招标方联系人）
    - 座机：010-83252206（联系人：林忠泽 | 来源：招投标 2020 | 置信度：中 | 角色：招标方联系人）
    - 座机：0551-65802027（联系人：张工 | 来源：招投标 2018 | 置信度：中 | 角色：招标方联系人）

    **团队分析**

    - **决策权结构**：呈现集中型特征。张卫东作为法定代表人、董事长及董事会秘书，集决策权与执行监督权于一身，推测为实际掌控人。
    - **股权集中度**：股权结构分散，最大股东为国务院（持股约 58%），体现其央企背景。
    - **教育背景**：核心高管团队学历背景普遍较高，多位成员拥有清华、北大及海外名校学位，尤其在财务、法律及管理领域专业度高。但张卫东本人的详细公开简历较少，透明度有待提升。
    - **核心人物画像**：以"财政部系"和"建行系"背景为主，团队风格稳健，政策敏感度高。
    - **风险提示**：目前公开渠道暂无张卫东直连手机号，所列联系方式多为招投标遗留的部门座机，时效性需二次确认；直接联系到本人的难度较大，需通过正式商务渠道。

    **官网**

    - http://www.cinda.com.cn

    **引荐参考**

    - **艾久超**（董事会秘书/公司秘书）：作为法定董事会秘书，是联系董事长张卫东的最直接行政枢纽。（可信度：高，来源：工商登记/品牌页）
    - **宋卫刚**（执行董事、总裁）：负责日常经营，若张卫东无暇顾及，宋卫刚是重要的决策替代者。（可信度：中，来源：品牌页）
    - **杨英勋**（首席财务官）：财务控制的关键节点，若涉及资金类合作可先由此切入。（可信度：中，来源：工商登记）

    *以上号码均来自公开渠道，不保证有效性。*
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
    - **样式**：通过自定义 `InkTheme` 定制
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

    private static let sampleEquityReport = """
    ### 一、企业基础信息与股权概览

    | 核心属性 | 详情 |
    |----------|------|
    | 主体类型 | 股份有限公司（上市） |
    | 所有制 | 上交所科创板已上市（2024年8月上市） |
    | 融资阶段 | 上市后市场化融资阶段 |
    | 第一大股东持股 | 镇立新直接持股24.06%，为第一大股东 |
    | 前十大股东集中度 | 合计持股69.17%，股权集中度适度 |
    | 实际人控制权评价 | 镇立新为唯一实控人，通过直接持股+一致行动人安排合计控制约33%表决权，接近34%一票否决红线，控制权整体稳定 |
    | 股东类型分布 | 实控人自然人24.06%、员工持股平台8.94%、财务投资机构27.12%、公众流通股30.83%、其他自然人股9.05% |
    | 持股平台配置 | 共设2家员工持股有限合伙，覆盖核心管理层及技术骨干 |
    | 股权质押状态 | 截至2024年三季报，实控人及前十大股东无高比例股权质押（质押比例<5%） |
    | 股权清晰性评价 | 无代持、权属争议，股权清晰合规 |

    ### 二、全维度风险分级诊断

    **结构健康亮点**

    1. 控制权稳定适配上市阶段要求

    **数据依据：** 实控人镇立新合计控制约33%表决权，远高于科创板上市要求的实控人持股>20%红线，上市后控制权未发生变更，不存在控制权争夺风险。

    **优势说明：** 实控人为公司核心创始人，长期主导技术研发与战略方向，控制权与经营权高度匹配，支撑公司战略长期一致性。

    2. 员工激励体系搭建完善

    **数据依据：** 上市前已搭建2加员工持股平台，合计持股8.94%，覆盖核心技术、产品、管理团队，上市后无大幅减持迹象。

    ### 三、分层落地优化建议（优先级排序）

    **1. 中期优化（3~12个月）**

    - 动作：通过小额一致性。
    - 核心原因：筑牢大事项。
    - 落地效果：筑牢大事项。

    **2. 长期布局（年度规划）**

    - 动作：通过小额一致性。
    - 核心原因：筑牢大事项。

    ### 四、行业对标分析

    选取同赛道人工智能 To B 领域科创板上市企业金山办公（688111）作为对标：

    | 对比维度 | 合合信息 | 金山办公 |
    |----------|----------|----------|
    | 实控人持股 | 33%（接近34%红线） | 41% |
    | 股权激励池 | 8.94% | 12.5% |
    | 持股平台设计 | 2个员工平台，无其他平台 | 员工+战略 |

    ### 五、综合评级与整体总结

    **整体总结：** 上海合合信息股权结构完全合规，任何实质性合规风险，控制权整体稳定，员工激励体系完善，适配人工智能科技企业上市后的发展需求；进存在少量治理优化空间，整体股权结构健康，无重大风险。
    """
}
