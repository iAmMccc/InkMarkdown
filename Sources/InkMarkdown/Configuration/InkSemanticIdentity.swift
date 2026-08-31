import Foundation

/// 不透明渲染行为的稳定语义身份。
///
/// Swift 闭包与协议实例无法普遍做值比较。当宿主在 SwiftUI `body` 中反复构造
/// 等价的回调或 loader 时，可使用同一身份声明其行为等价，以便 adapter 安全跳过
/// 无效重渲染。只有行为与所有捕获状态都等价时，才能复用同一值。
public struct InkSemanticIdentity: Hashable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }

  static func unique() -> InkSemanticIdentity {
    InkSemanticIdentity(UUID().uuidString)
  }
}

/// 为协议型不透明值提供可选的稳定语义身份。
///
/// 默认返回 `nil`，因此既有第三方实现无需修改。实现者只能在动态类型、
/// 所有行为与捕获状态都等价时复用同一身份。
public protocol InkSemanticIdentityProviding {
  var semanticIdentity: InkSemanticIdentity? { get }
}

public extension InkSemanticIdentityProviding {
  var semanticIdentity: InkSemanticIdentity? { nil }
}

/// 不透明配置值的唯一内部比较 seam。
enum InkSemanticComparator {
  static func opaqueValuesAreEquivalent(
    lhsIsPresent: Bool,
    rhsIsPresent: Bool,
    lhsIdentity: InkSemanticIdentity?,
    rhsIdentity: InkSemanticIdentity?
  ) -> Bool {
    guard lhsIsPresent == rhsIsPresent else { return false }
    guard lhsIsPresent else { return true }
    return lhsIdentity == rhsIdentity
  }

  static func extensionsAreEquivalent(
    _ lhs: any InkConfigurationSemanticsProviding,
    _ rhs: any InkConfigurationSemanticsProviding
  ) -> Bool {
    guard sameDynamicType(lhs, rhs) else { return false }
    switch (lhs.semanticIdentity, rhs.semanticIdentity) {
    case let (lhsIdentity?, rhsIdentity?):
      return lhsIdentity == rhsIdentity
    case (nil, nil):
      return lhs.isSemanticallyEquivalent(to: rhs)
    case (.some, nil), (nil, .some):
      return false
    }
  }

  static func imageLoadersAreEquivalent(
    _ lhs: (any InkImageLoading)?,
    _ rhs: (any InkImageLoading)?,
    lhsFallbackIdentity: InkSemanticIdentity?,
    rhsFallbackIdentity: InkSemanticIdentity?
  ) -> Bool {
    guard let lhs, let rhs else { return lhs == nil && rhs == nil }
    guard sameDynamicType(lhs, rhs) else { return false }

    let lhsIdentity = lhs.semanticIdentity ?? lhsFallbackIdentity
    let rhsIdentity = rhs.semanticIdentity ?? rhsFallbackIdentity
    switch (lhsIdentity, rhsIdentity) {
    case let (lhsIdentity?, rhsIdentity?):
      return lhsIdentity == rhsIdentity
    case (nil, nil):
      guard let lhs = lhs as? any InkConfigurationSemanticsProviding,
            let rhs = rhs as? any InkConfigurationSemanticsProviding else {
        return false
      }
      return lhs.isSemanticallyEquivalent(to: rhs)
    case (.some, nil), (nil, .some):
      return false
    }
  }

  private static func sameDynamicType(_ lhs: Any, _ rhs: Any) -> Bool {
    String(reflecting: type(of: lhs)) == String(reflecting: type(of: rhs))
  }
}
