import Foundation

/// 把 WKNavigationDelegate 回调严格路由到创建它的 WebView 与 request generation。
///
/// WebKit 可能在 `navigationDelegate = nil` 后仍投递已入队的回调。该对象不信任 delegate
/// 生命周期：只有当前 view、当前 request 实例及相同 generation 同时匹配时才触发 completion。
@MainActor
final class InkMermaidPageLoadRouter {
  private final class Route {
    weak var view: AnyObject?
    weak var state: InkMermaidRenderRequestState?
    let generation: UUID
    let completion: (Result<Void, Error>) -> Void

    init(
      view: AnyObject,
      state: InkMermaidRenderRequestState,
      completion: @escaping (Result<Void, Error>) -> Void
    ) {
      self.view = view
      self.state = state
      self.generation = state.generation
      self.completion = completion
    }
  }

  private var route: Route?

  func bind(
    view: AnyObject,
    state: InkMermaidRenderRequestState,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    route = Route(view: view, state: state, completion: completion)
  }

  /// 仅在路由的 view、state 实例、generation 与当前 request 都相符时分发。
  func hasActiveRoute(for view: AnyObject, currentRequest: InkMermaidRenderRequestState?) -> Bool {
    matches(view: view, currentRequest: currentRequest)
  }

  @discardableResult
  func complete(
    from view: AnyObject,
    currentRequest: InkMermaidRenderRequestState?,
    result: Result<Void, Error>
  ) -> Bool {
    guard matches(view: view, currentRequest: currentRequest), let route else {
      return false
    }
    self.route = nil
    route.completion(result)
    return true
  }

  func clear(for state: InkMermaidRenderRequestState) {
    guard let route,
          let boundState = route.state,
          boundState === state,
          route.generation == state.generation else {
      return
    }
    self.route = nil
  }

  private func matches(view: AnyObject, currentRequest: InkMermaidRenderRequestState?) -> Bool {
    guard let route,
          route.view === view,
          let state = route.state,
          currentRequest === state,
          route.generation == state.generation else {
      return false
    }
    return true
  }
}
