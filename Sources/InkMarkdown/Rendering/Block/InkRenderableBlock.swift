import UIKit

/// O(1) 可哈希的块级 identity，供 adapter 做视图 diff 复用。
///
/// SPI：不在 ADR-008 宿主公开清单内；SwiftUI adapter 通过 `@_spi(InkMarkdown)` 访问。
@_spi(InkMarkdown)
public struct InkBlockIdentity: Hashable, Sendable {
  public let documentEpoch: UInt64
  public let blockIndex: Int
  public let kind: Int

  public init(documentEpoch: UInt64, blockIndex: Int, kind: Int) {
    self.documentEpoch = documentEpoch
    self.blockIndex = blockIndex
    self.kind = kind
  }
}

/// 流式 remainder 文本槽位的固定 kind 判别值。
@_spi(InkMarkdown)
public enum InkStreamingSlotKind {
  public static let streamText: Int = 0x5354_4558 // "STEX"
}

/// Block 路由下的最小渲染单元——每一块自行决定如何变成 UIView。
public protocol InkRenderableBlock: Sendable {
  @_spi(InkMarkdown)
  var blockIdentity: InkBlockIdentity? { get }

  @MainActor func makeView() -> UIView

  /// 同 identity 的块更新时 in-place 刷新已有视图。
  @MainActor func updateExistingView(_ view: UIView)

  /// 内容指纹，供 adapter 判断 identity 命中后是否需刷新视图/重测槽位。
  @MainActor
  @_spi(InkMarkdown)
  func contentFingerprint(documentEpoch: UInt64, blockIndex: Int) -> UInt64
}

extension InkRenderableBlock {
  @_spi(InkMarkdown)
  public var blockIdentity: InkBlockIdentity? { nil }

  @MainActor
  public func updateExistingView(_ view: UIView) {
    preconditionFailure("InkRenderableBlock.updateExistingView must be implemented for in-place updates")
  }

  @MainActor
  @_spi(InkMarkdown)
  public func contentFingerprint(documentEpoch: UInt64, blockIndex: Int) -> UInt64 {
    var hash: UInt64 = documentEpoch
    hash ^= UInt64(bitPattern: Int64(blockIndex))
    hash ^= UInt64(bitPattern: Int64(ObjectIdentifier(Self.self).hashValue))
    return hash
  }

  @MainActor
  @_spi(InkMarkdown)
  public func resolvedIdentity(documentEpoch: UInt64, blockIndex: Int) -> InkBlockIdentity {
    if let blockIdentity {
      return blockIdentity
    }
    return InkBlockIdentity(
      documentEpoch: documentEpoch,
      blockIndex: blockIndex,
      kind: ObjectIdentifier(Self.self).hashValue
    )
  }
}

/// 为渲染结果批量写入块 identity；未知块类型视为工程错误。
@_spi(InkMarkdown)
public enum InkBlockIdentityStamper {
  public static func stamp(_ blocks: [InkRenderableBlock], documentEpoch: UInt64) -> [InkRenderableBlock] {
    blocks.enumerated().map { index, block in
      stamp(
        block,
        identity: InkBlockIdentity(
          documentEpoch: documentEpoch,
          blockIndex: index,
          kind: ObjectIdentifier(type(of: block)).hashValue
        )
      )
    }
  }

  private static func stamp(_ block: InkRenderableBlock, identity: InkBlockIdentity) -> InkRenderableBlock {
    switch block {
    case var value as InkAttributedTextBlock:
      value.blockIdentity = identity
      return value
    case var value as InkCodeBlock:
      value.blockIdentity = identity
      return value
    case var value as InkTableBlock:
      value.blockIdentity = identity
      return value
    case var value as InkThematicBreakBlock:
      value.blockIdentity = identity
      return value
    case var value as InkThoughtBlock:
      value.blockIdentity = identity
      return value
    case var value as InkImageBlock:
      value.blockIdentity = identity
      return value
    default:
      preconditionFailure("Unhandled InkRenderableBlock type: \(type(of: block))")
    }
  }
}

/// 源文本稳定 epoch（FNV-1a 64-bit）。
@_spi(InkMarkdown)
public enum InkDocumentEpoch {
  public static func hash(_ source: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in source.utf8 {
      hash ^= UInt64(byte)
      hash &*= 0x100000001b3
    }
    return hash
  }
}

/// 简易组合哈希。
@_spi(InkMarkdown)
public enum InkFingerprint {
  public static func combine(_ values: UInt64...) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for value in values {
      hash ^= value
      hash &*= 0x100000001b3
    }
    return hash
  }

  public static func hash(_ string: String) -> UInt64 {
    InkDocumentEpoch.hash(string)
  }
}
