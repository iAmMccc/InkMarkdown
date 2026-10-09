import Foundation

/// 生成型 addon（LaTeX、Mermaid 等）在核心中的注册 seam。
///
/// 宿主在启动阶段显式调用 addon 的 `register()`，由 addon 写入
/// ``register(owner:rendererVersion:makeLoader:)`` 与 ``registerResourceBundle(_:owner:)``；
/// 核心在未注册时必须走 ``ImageLoadError/generatedLoaderUnavailable``，
/// 不得用编译期 stub 伪装可用 renderer。
package enum InkGeneratedAddonRuntime: Sendable {
  /// 按 owner 创建已注册的生成型图片 loader。
  public typealias LoaderFactory = @Sendable () -> any InkGeneratedImageLoading

  private struct Entry: Sendable {
    let rendererVersion: String
    let makeLoader: LoaderFactory
  }

  /// 单一同步状态容器。静态属性保持不可变；所有可变状态仅在锁内访问。
  private final class Registry: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var resourceBundles: [String: Bundle] = [:]

    func register(owner: String, entry: Entry) {
      lock.lock()
      entries[owner] = entry
      lock.unlock()
    }

    func registerResourceBundle(_ bundle: Bundle, owner: String) {
      lock.lock()
      resourceBundles[owner] = bundle
      lock.unlock()
    }

    func entry(owner: String) -> Entry? {
      lock.lock()
      defer { lock.unlock() }
      return entries[owner]
    }

    func resourceBundle(owner: String) -> Bundle? {
      lock.lock()
      defer { lock.unlock() }
      return resourceBundles[owner]
    }
  }

  private static let registry = Registry()

  /// 注册 addon 的 renderer 版本与 loader 工厂。
  @discardableResult
  public static func register(
    owner: String,
    rendererVersion: String,
    makeLoader: @escaping LoaderFactory
  ) -> Bool {
    registry.register(
      owner: owner,
      entry: Entry(rendererVersion: rendererVersion, makeLoader: makeLoader)
    )
    return true
  }

  /// 注册 addon 提供的资源 bundle（例如 Mermaid bridge HTML）。
  @discardableResult
  public static func registerResourceBundle(_ bundle: Bundle, owner: String) -> Bool {
    registry.registerResourceBundle(bundle, owner: owner)
    return true
  }

  /// 返回已注册 owner 的 renderer 版本；未注册时为 `nil`。
  public static func rendererVersion(owner: String) -> String? {
    registry.entry(owner: owner)?.rendererVersion
  }

  /// 返回已注册 owner 的 loader 实例；未注册时为 `nil`。
  public static func makeLoader(owner: String) -> (any InkGeneratedImageLoading)? {
    registry.entry(owner: owner)?.makeLoader()
  }

  /// 返回已注册 owner 的资源 bundle；未注册时为 `nil`。
  public static func resourceBundle(owner: String) -> Bundle? {
    registry.resourceBundle(owner: owner)
  }
}

/// LaTeX addon 向核心暴露的真实渲染能力。
package protocol InkLaTeXRenderingProviding: InkGeneratedImageLoading {
  /// 使用 iosMath 等后端渲染单次 LaTeX 请求。
  func renderLaTeX(_ request: InkLaTeXRenderRequest) async throws -> InkLaTeXRenderResult
}

/// Mermaid addon 向核心暴露的真实渲染能力。
package protocol InkMermaidRenderingProviding: InkGeneratedImageLoading {
  /// 使用 addon 注册的 bridge 资源渲染单次 Mermaid 请求。
  func renderMermaid(
    _ request: InkMermaidRenderRequest,
    limits: InkMermaidRenderLimits
  ) async throws -> InkMermaidRenderResult
}
