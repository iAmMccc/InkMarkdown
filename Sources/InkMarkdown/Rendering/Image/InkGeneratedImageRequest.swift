import CryptoKit
import Foundation

/// 由本地渲染器生成的图片输入。
///
/// 此类型只保存可重建的文本输入与稳定身份材料，不保存位图或任务；位图的缓存、
/// 并发合并与缓存由 ``InkImageBackend`` 负责，呈现订阅由协调器桥接。
public struct InkGeneratedImageRequest: Hashable, Sendable {
  /// 生成器的所有者，例如 `latex` 或 `mermaid`。
  public let owner: String
  /// 生成器实现版本。升级算法或本地资源时应同步变更该值。
  public let rendererVersion: String
  /// 原始生成器输入；不得用作 URL 或缓存键。
  public let source: String
  /// 影响输出的样式/主题身份。
  public let styleIdentity: String

  public init(owner: String, rendererVersion: String, source: String, styleIdentity: String) {
    self.owner = owner
    self.rendererVersion = rendererVersion
    self.source = source
    self.styleIdentity = styleIdentity
  }

  /// 不含原文的稳定身份。显示尺寸由 ``DisplayKey`` 追加，避免 data URL 型巨型 key。
  public var stableID: String {
    let identity = [owner, rendererVersion, source, styleIdentity].joined(separator: "\u{1F}")
    let digest = SHA256.hash(data: Data(identity.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
    return "ink-generated://sha256/\(digest)"
  }
}
