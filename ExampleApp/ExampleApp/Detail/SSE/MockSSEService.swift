import Foundation

/// 模拟服务端 SSE（Server-Sent Events）流式接口。
///
/// 真实业务里，`onChunk` 对应 SSE 的每一帧 `data:` 回调，`onComplete`
/// 对应 `[DONE]` 事件。这里用 `Timer` 把预设的 Markdown 回答按行/句切块逐帧吐出，
/// 还原「边收边吐」的网络流式手感——demo 不依赖任何真实网络。
@MainActor
final class MockSSEService {

  static let shared = MockSSEService()
  private let firstByteDelay: TimeInterval
  private let chunkInterval: TimeInterval
  private let answer: @MainActor (String) -> String
  private var pendingStart: DispatchWorkItem?
  private var timer: Timer?
  private var activeRequest: StreamRequestDelivery?

  init(
    firstByteDelay: TimeInterval = 0.6,
    chunkInterval: TimeInterval = 0.03,
    answer: @escaping @MainActor (String) -> String = { MockAnswerRouter.route(question: $0) }
  ) {
    self.firstByteDelay = firstByteDelay
    self.chunkInterval = chunkInterval
    self.answer = answer
  }

  /// 发起一次流式问答。
  /// - Parameters:
  ///   - question: 用户问题，用于挑选预设回答。
  ///   - onChunk: 每收到一帧文本片段时回调（已在主线程）。
  ///   - onComplete: 全部推送完毕时回调（已在主线程）。
  func askStream(
    question: String,
    onChunk: @escaping @MainActor (String) -> Void,
    onComplete: @escaping @MainActor () -> Void
  ) {
    cancel()

    let request = StreamRequestDelivery(onChunk: onChunk, onComplete: onComplete, onError: { _ in })
    activeRequest = request
    request.onTermination = { [weak self, weak request] in
      guard let self, self.activeRequest === request else { return }
      self.pendingStart?.cancel()
      self.pendingStart = nil
      self.timer?.invalidate()
      self.timer = nil
      self.activeRequest = nil
    }
    let chunks = Self.splitIntoStreamChunks(answer(question))
    var cursor = 0
    let start = DispatchWorkItem { [weak self, request] in
      MainActor.assumeIsolated {
        guard let self, request.isActive else { return }
        self.pendingStart = nil
        self.timer = Timer.scheduledTimer(withTimeInterval: self.chunkInterval, repeats: true) { [weak self] timer in
          MainActor.assumeIsolated {
            guard self != nil, request.isActive else {
              timer.invalidate()
              request.cancel()
              return
            }
            guard cursor < chunks.count else {
              request.finish()
              return
            }
            let chunk = chunks[cursor]
            cursor += 1
            request.receive(chunk)
          }
        }
      }
    }
    pendingStart = start
    DispatchQueue.main.asyncAfter(deadline: .now() + firstByteDelay, execute: start)
  }

  /// 中断当前流，包括尚未开始的首字延迟。
  func cancel() {
    activeRequest?.cancel()
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
