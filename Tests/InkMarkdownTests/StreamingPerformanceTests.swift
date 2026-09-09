import Testing
import Foundation
import UIKit
@_spi(Performance) @testable import InkMarkdown

// MARK: - 流式增量渲染性能阈值（T1.4）
//
// 设上限 0.30（30%）作为当前的性能回归闸门：目的是捕获把 incremental 路径
// 意外改回接近全量重渲染的变更。它不是跨设备、跨版本或与竞品比较的性能承诺。
//
// 发布前应把校准 workload、设备/Simulator、构建配置和原始结果记录为可复现
// benchmark artifact。若阈值在 CI 上频繁红，按 roadmap R1 的策略按机器/版本
// 分桶 baseline，而不是在缺少证据时直接放宽。

@Suite @MainActor struct StreamingPerformanceTests {

  /// 正确性不变量：增量渲染的最终字符输出必须与全量渲染完全一致。
  /// 这是所有性能指标的前提——快但错了不能接受。
  @Test func incremental_renderOutputMatchesFullRender() {
    let result = InkStreamingPerformanceBenchmark.measure()
    #expect(result.outputMatches, "incremental 与全量渲染的字符输出不一致")
  }

  /// 性能闸门：增量渲染总耗时不得超过全量渲染的 30%。
  ///
  /// - 上限 0.30 是当前回归闸门，不代表通用性能结论。
  /// - 失败含义：增量路径退化（最常见于有人把 `InkIncrementalMarkdownRenderer`
  ///   的稳定边界逻辑绕过、退回每片全量重渲染）。
  @Test func incremental_renderIsFasterThanFullRender() {
    let result = InkStreamingPerformanceBenchmark.measure()
    #expect(result.fullRenderSeconds > 0, "全量渲染耗时为 0，基准数据异常")

    let ratio = result.incrementalRenderSeconds / result.fullRenderSeconds
    let upperBound = 0.30
    if ratio >= upperBound {
      let msg: Comment = """
      增量渲染退化：incremental/full = \(String(format: "%.3f", ratio))，超过上限 \(upperBound)
      （full=\(String(format: "%.1f", result.fullRenderSeconds * 1000))ms，\
      incr=\(String(format: "%.1f", result.incrementalRenderSeconds * 1000))ms）
      """
      Issue.record(msg)
    }
  }

  /// 性能闸门：长篇大文档（含思考过程、代码块、表格、列表）全量 Block 渲染耗时应低于 500ms
  @Test func largeDocument_blockRenderThroughput() {
    let document = """
    <think>
    系统性分析需求背景与工程架构：
    1. 第一阶段：词法与语法分析
    2. 第二阶段：渲染管线流水线化
    3. 第三阶段：双缓冲与帧率控制
    </think>

    # 核心技术全景报告

    | 模块 | 职责 | 依赖关系 |
    | :--- | :--- | :--- |
    | Parser | Markdown AST 转换 | swift-markdown |
    | Engine | UIKit 原生排版渲染 | TextKit / CoreText |
    | Adapter | SwiftUI 声明式桥接 | InkMarkdownSwiftUI |

    ```swift
    final class StreamPipeline {
        func append(_ chunk: String) {
            // Frame paced differential rendering
        }
    }
    ```

    > 提示：保持架构简洁与清晰的分层边界是长期可维护性的核心基石。

    - 优势 1：无 WebView 启动开销与内存占用
    - 优势 2：完全原生的触摸响应与选择高亮
    - 优势 3：UIKit 与 SwiftUI 严格对齐视觉排版
    """

    let start = CACurrentMediaTime()
    let blocks = InkBlockRenderer.render(document, configuration: .standard)
    let elapsed = CACurrentMediaTime() - start

    #expect(!blocks.isEmpty)
    #expect(blocks.contains(where: { $0 is InkThoughtBlock }))
    #expect(blocks.contains(where: { $0 is InkTableBlock }))
    #expect(blocks.contains(where: { $0 is InkCodeBlock }))
    #expect(elapsed < 0.5, "大文档 Block 渲染耗时 \(String(format: "%.2f", elapsed * 1000))ms 超过 500ms 上限")
  }
}
