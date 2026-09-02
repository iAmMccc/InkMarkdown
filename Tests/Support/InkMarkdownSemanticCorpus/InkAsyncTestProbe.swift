import Foundation

/// 统一抽干 main run loop 并等待可观察条件成立，供 core / SwiftUI 契约测试复用。
@MainActor
public enum InkAsyncTestProbe {

  /// 在超时前轮询条件；每轮先让 `.default` mode 消费已排队回调。
  @discardableResult
  public static func wait(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    stepNanoseconds: UInt64 = 10_000_000,
    until condition: @MainActor () -> Bool
  ) async -> Bool {
    guard stepNanoseconds > 0 else { return condition() }

    var elapsed: UInt64 = 0
    while !condition(), elapsed < timeoutNanoseconds {
      await drainMainRunLoop(for: stepNanoseconds)
      elapsed += stepNanoseconds
    }
    return condition()
  }

  private static func drainMainRunLoop(for nanoseconds: UInt64) async {
    let interval = TimeInterval(nanoseconds) / 1_000_000_000
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      DispatchQueue.main.async {
        // Swift 6 不允许从任意 async executor 直接调用 RunLoop.run；固定回到 main queue。
        RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: interval))
        continuation.resume()
      }
    }
  }
}
