import Testing
import Foundation
import UIKit
@_spi(Performance) @testable import InkMarkdown

// MARK: - 流式增量渲染性能阈值（T1.4）
//
// 阈值依据：在 iPhone 17 / iOS 26.5 模拟器（Debug）上实测：
//   - 默认数据集（109 片、5208 字）：incremental / full ≈ 0.15–0.19（多次运行稳定）
//   - 大规模（m=8，41664 字）：ratio ≈ 0.03–0.04
//   - 增量结果与全量结果字符级一致（outputMatches == true，正确性不变量）
//
// 设上限 0.30（30%）：留有 ~1.6x 余量，吸收不同模拟器/CI 机器的方差，
// 同时仍能捕获「增量退化到接近全量」这类真实回归。若阈值在 CI 上频繁红，
// 按 roadmap R1 缓解策略：改为按机器/版本分桶 baseline，而非直接放宽。
//
// 这些是【性能回归闸门】而非微基准：目的是防止有人把 incremental 路径改回全量
// 重渲染却不自知。阈值取「保守可过」，不是性能炫耀。

@Suite struct StreamingPerformanceTests {

  /// 正确性不变量：增量渲染的最终字符输出必须与全量渲染完全一致。
  /// 这是所有性能指标的前提——快但错了不能接受。
  @Test func incremental_renderOutputMatchesFullRender() {
    let result = InkStreamingPerformanceBenchmark.measure()
    #expect(result.outputMatches, "incremental 与全量渲染的字符输出不一致")
  }

  /// 性能闸门：增量渲染总耗时不得超过全量渲染的 30%。
  ///
  /// - 实测默认数据集 ratio ≈ 0.15–0.19；上限 0.30 留有 ~1.6x 余量吸收 CI 方差。
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
}
