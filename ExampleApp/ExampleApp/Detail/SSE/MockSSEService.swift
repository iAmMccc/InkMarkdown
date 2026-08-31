import Foundation

/// 模拟服务端 SSE（Server-Sent Events）流式接口。
///
/// 真实业务里，`onChunk` 对应 SSE 的每一帧 `data:` 回调，`onComplete`
/// 对应 `[DONE]` 事件。这里用 `Timer` 把预设的 Markdown 回答按行/句切块逐帧吐出，
/// 还原「边收边吐」的网络流式手感——demo 不依赖任何真实网络。
final class MockSSEService {

  static let shared = MockSSEService()
  private init() {}

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
    cancel()

    let answer = MockAnswerRouter.route(question: question)
    let chunks = Self.splitIntoStreamChunks(answer)
    var cursor = 0

    let firstByteDelay: TimeInterval = 0.6
    DispatchQueue.main.asyncAfter(deadline: .now() + firstByteDelay) { [weak self] in
      guard let self else { return }
      self.timer = Timer.scheduledTimer(withTimeInterval: self.chunkInterval, repeats: true) { [weak self] t in
        guard let self else { return }
        guard cursor < chunks.count else {
          t.invalidate()
          self.timer = nil
          onComplete()
          return
        }
        let chunk = chunks[cursor]
        onChunk(chunk)
        cursor += 1
      }
    }
  }

  /// 中断当前流（页面退出或重新发送时调用）。
  func cancel() {
    timer?.invalidate()
    timer = nil
  }

  // MARK: - 分块策略

  /// 按换行优先、长行再按句末标点切分，模拟真实 SSE 分片粒度。
  static func splitIntoStreamChunks(_ text: String) -> [String] {
    var chunks: [String] = []
    var lineBuffer = ""

    func flushLine() {
      guard !lineBuffer.isEmpty else { return }
      chunks.append(contentsOf: splitLongLine(lineBuffer))
      lineBuffer = ""
    }

    for char in text {
      if char == "\n" {
        lineBuffer.append(char)
        flushLine()
      } else {
        lineBuffer.append(char)
      }
    }
    flushLine()
    return chunks.isEmpty ? [text] : chunks
  }

  /// 无换行的长行按句末标点二次切分，避免单帧过大。
  private static func splitLongLine(_ line: String) -> [String] {
    guard line.count > 80 else { return [line] }

    var result: [String] = []
    var buffer = ""
    let sentenceEnds: Set<Character> = ["。", "！", "？", ".", "!", "?"]

    for char in line {
      buffer.append(char)
      if sentenceEnds.contains(char), buffer.count >= 20 {
        result.append(buffer)
        buffer = ""
      }
    }
    if !buffer.isEmpty {
      result.append(buffer)
    }
    return result.isEmpty ? [line] : result
  }
}
