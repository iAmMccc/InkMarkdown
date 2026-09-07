import Testing
import UIKit
import SwiftUI
import InkMarkdownSemanticCorpus
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("InkStreamingPresentationHost", .serialized)
@MainActor
struct InkStreamingPresentationHostTests {

  @Test("单 host append→finish 保留 Thought 与终态正文")
  func host_singleAppendFinishKeepsThoughtAndBody() async throws {
    var configuration = InkConfiguration.standard
    configuration.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: configuration)
    session.renderer.charactersPerFrame = 200
    let host = InkStreamingPresentationHost()
    let container = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )

    #expect(host.update(session: session, container: container))
    session.append("<think>\n步骤\n</think>\n\n正文答案")
    await InkAsyncTestProbe.wait {
      container.subviews.contains(where: { $0 is InkThoughtBlockView })
        && container.subviews.contains(where: { $0 is UITextView })
    }

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await InkAsyncTestProbe.wait { session.isPromoted }
    #expect(host.update(session: session, container: container))
    #expect(container.subviews.contains(where: { $0 is InkThoughtBlockView }))
    #expect(session.blocks.contains(where: { $0 is InkThoughtBlock }))
  }

  @Test("双 host：等待环境不污染活跃 host，接管后应用最新环境")
  func host_waitingEnvironmentDoesNotPolluteActiveOwner() async throws {
    var configuration = InkConfiguration.standard
    configuration.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: configuration)
    session.renderer.charactersPerFrame = 200

    let hostA = InkStreamingPresentationHost()
    let containerA = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )
    #expect(
      hostA.update(
        session: session,
        container: containerA,
        renderEnvironment: InkRenderEnvironment(userInterfaceStyle: .light)
      )
    )
    session.append("<think>\n交叠")
    await InkAsyncTestProbe.wait {
      containerA.subviews.contains(where: { $0 is InkThoughtBlockView })
    }
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .light)

    let hostB = InkStreamingPresentationHost()
    let containerB = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )
    #expect(
      !hostB.update(
        session: session,
        container: containerB,
        renderEnvironment: InkRenderEnvironment(userInterfaceStyle: .dark)
      )
    )
    #expect(containerB.subviews.isEmpty)
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .light)

    session.append("\n仍在 A")
    await InkAsyncTestProbe.wait {
      (containerA.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)?
        .thought.contains("仍在 A") == true
    }

    hostA.teardown(from: containerA)
    #expect(containerA.subviews.isEmpty)
    await InkAsyncTestProbe.wait {
      !containerB.subviews.isEmpty
    }
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .dark)
    #expect(containerB.subviews.contains(where: { $0 is InkThoughtBlockView }))

    // 旧 A 再 teardown 无副作用
    hostA.teardown(from: containerA)
    session.append("\n</think>\n\nB 正文")
    await InkAsyncTestProbe.wait {
      (containerB.subviews.first(where: { $0 is UITextView }) as? UITextView)?
        .text.contains("B 正文") == true
    }
  }

  @Test("等待者先 teardown 不解绑活跃 owner")
  func host_abandonedWaiterDoesNotUnbindActiveOwner() async throws {
    let session = InkMarkdownRenderSession()
    session.renderer.charactersPerFrame = 200
    let hostA = InkStreamingPresentationHost()
    let containerA = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )
    #expect(hostA.update(session: session, container: containerA))
    session.append("<think>\n活跃")
    await InkAsyncTestProbe.wait {
      containerA.subviews.contains(where: { $0 is InkThoughtBlockView })
    }

    let abandoned = InkStreamingPresentationHost()
    let abandonedContainer = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )
    _ = abandoned.update(session: session, container: abandonedContainer)
    abandoned.teardown(from: abandonedContainer)

    session.append("\n继续")
    await InkAsyncTestProbe.wait {
      (containerA.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)?
        .thought.contains("继续") == true
    }
    #expect(!containerA.subviews.isEmpty)
  }

  @Test("连续调用 teardown 具备幂等性且已 teardown 状态正确清理")
  func host_repeatedTeardownIsIdempotentAndCleansState() async throws {
    let session = InkMarkdownRenderSession()
    session.renderer.charactersPerFrame = 200
    let host = InkStreamingPresentationHost()
    let container = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )

    #expect(host.update(session: session, container: container))
    session.append("<think>\n测试步骤\n</think>\n正文")
    await InkAsyncTestProbe.wait {
      container.subviews.contains(where: { $0 is InkThoughtBlockView })
    }
    #expect(!host.isTornDown)

    // 首次 teardown
    host.teardown(from: container)
    #expect(host.isTornDown)
    let generationAfterFirstTeardown = host.currentHostGeneration

    // 连续多次 teardown：因 guard !isReleasing, session != nil || ownedAttachmentToken != nil 短路
    host.teardown(from: container)
    host.teardown(from: container)
    #expect(host.isTornDown)
    #expect(host.currentHostGeneration == generationAfterFirstTeardown)
  }

  @Test("同一 session 传入新 container 时释放旧 container 上下文并由新 container 接管")
  func host_replacesContainerUnderSameSession_cleansOldAndAcceptsNew() async throws {
    let session = InkMarkdownRenderSession()
    session.renderer.charactersPerFrame = 200
    let host = InkStreamingPresentationHost()
    let oldContainer = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )

    #expect(host.update(session: session, container: oldContainer))
    session.append("第一段文字")
    await InkAsyncTestProbe.wait {
      oldContainer.subviews.contains(where: { $0 is UITextView })
    }
    #expect(oldContainer.onContinuityLayoutEnvironmentChanged != nil)

    let newContainer = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )
    #expect(host.update(session: session, container: newContainer))

    // 旧容器回调已被释放且子视图已被移除
    #expect(oldContainer.onContinuityLayoutEnvironmentChanged == nil)
    #expect(oldContainer.subviews.isEmpty)

    // 新容器成功接管呈现
    #expect(newContainer.onContinuityLayoutEnvironmentChanged != nil)
    #expect(newContainer.subviews.contains(where: { $0 is UITextView }))

    // 后续 append 继续在 newContainer 上呈现
    session.append("\n第二段文字")
    await InkAsyncTestProbe.wait {
      (newContainer.subviews.first(where: { $0 is UITextView }) as? UITextView)?
        .text.contains("第二段文字") == true
    }
    #expect(oldContainer.subviews.isEmpty)
  }

  @Test("旧 Session 先释放后，容器仍可被新 Session 顺利接管并清理旧视图")
  func host_sessionDeallocatedFirst_containerCanBeReusedByNewSession() async throws {
    var configuration = InkConfiguration.standard
    configuration.appearance.thought.isCollapsible = true
    var sessionA: InkMarkdownRenderSession? = InkMarkdownRenderSession(configuration: configuration)
    sessionA?.renderer.charactersPerFrame = 200

    let host = InkStreamingPresentationHost()
    let container = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )

    #expect(host.update(session: sessionA!, container: container))
    sessionA?.append("<think>\nSession A 思考\n</think>\n\nSession A 正文")
    await InkAsyncTestProbe.wait {
      container.subviews.contains(where: { $0 is InkThoughtBlockView })
        && container.subviews.contains(where: { $0 is UITextView })
    }
    #expect(!container.subviews.isEmpty)

    // Session A 被外部完全释放（模拟 session 生命周期先于 container/host 结束）
    sessionA = nil

    // 传入 Session B，在同一个 container 上接管
    let sessionB = InkMarkdownRenderSession(configuration: configuration)
    sessionB.renderer.charactersPerFrame = 200
    sessionB.append("Session B 全新内容")

    let applied = host.update(session: sessionB, container: container)
    #expect(applied)

    // 旧 Session A 的视图被完全清理，新 Session B 视图正确呈现
    await InkAsyncTestProbe.wait {
      let textViews = container.subviews.compactMap { $0 as? UITextView }
      return textViews.contains(where: { $0.text.contains("Session B 全新内容") })
    }
    #expect(!container.subviews.contains(where: { $0 is InkThoughtBlockView }))
    let bTextView = container.subviews.compactMap { $0 as? UITextView }.first
    #expect(bTextView?.text.contains("Session A") == false)
    #expect(bTextView?.text.contains("Session B 全新内容") == true)
  }
}

@Suite("SwiftUI Stream remount", .serialized)
@MainActor
struct InkStreamMarkdownRemountTests {

  private final class HarnessState: ObservableObject {
    @Published var isMounted: Bool = true
  }

  private struct HarnessView: View {
    @ObservedObject var state: HarnessState
    let session: InkMarkdownRenderSession

    var body: some View {
      if state.isMounted {
        InkStreamMarkdownView(session: session)
      } else {
        Color.clear.frame(width: 10, height: 10)
      }
    }
  }

  private static func findSubviews<T>(in view: UIView, type: T.Type) -> [T] {
    var result: [T] = []
    if let match = view as? T {
      result.append(match)
    }
    for subview in view.subviews {
      result.append(contentsOf: findSubviews(in: subview, type: type))
    }
    return result
  }

  private static func findStreamingTextView(in view: UIView) -> UITextView? {
    let textViews = findSubviews(in: view, type: UITextView.self)
    return textViews.first { textView in
      var current: UIView? = textView
      while let parent = current?.superview {
        if parent is InkThoughtBlockView { return false }
        current = parent
      }
      return true
    }
  }

  @Test("UIHostingController 移除再插入后同一 Session 可继续显示并保留 Thought 折叠状态与新 delta 可见")
  func streamView_remountContinuesSameSession() async throws {
    var configuration = InkConfiguration.standard
    configuration.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: configuration)
    session.renderer.charactersPerFrame = 200
    session.append("<think>\n思考过程\n</think>\n\n首屏文本")

    let state = HarnessState()
    let root = HarnessView(state: state, session: session)
    let host = UIHostingController(rootView: root)
    host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 720)
    let window = UIWindow(frame: host.view.bounds)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    // 等待首屏真实渲染：Thought 块与正文 TextView 必须在视图树中可见
    let initialRendered = await InkAsyncTestProbe.wait(timeoutNanoseconds: 1_000_000_000) {
      let thoughts = Self.findSubviews(in: host.view, type: InkThoughtBlockView.self)
      let streamTV = Self.findStreamingTextView(in: host.view)
      return thoughts.first?.thought.contains("思考过程") == true
        && streamTV?.text.contains("首屏文本") == true
    }
    try #require(initialRendered, "首屏渲染应在超时内完成")

    let initialThought = try #require(Self.findSubviews(in: host.view, type: InkThoughtBlockView.self).first)
    let initialStreamTV = try #require(Self.findStreamingTextView(in: host.view))
    #expect(!initialThought.isCollapsed)
    #expect(initialStreamTV.text.contains("首屏文本"))

    // 用户交互：折叠思考过程
    initialThought.handleHeaderTap()
    #expect(initialThought.isCollapsed)

    // 触发 SwiftUI 真实条件移除（触发 dismantleUIView 推进生命周期）
    state.isMounted = false
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    let unmounted = await InkAsyncTestProbe.wait(timeoutNanoseconds: 1_000_000_000) {
      Self.findSubviews(in: host.view, type: InkThoughtBlockView.self).isEmpty
        && Self.findSubviews(in: host.view, type: InkMarkdownContainerView.self).isEmpty
    }
    try #require(unmounted, "必须成功卸载旧视图，确保后续断言非旧视图残留")

    // 在 unmounted 状态下向 Session 追加新 delta
    session.append("\nremount 后续")

    // 重新插入同一 Session（推进 makeUIView / updateUIView）
    state.isMounted = true
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    // 关键断言：新挂载的视图树中真实可见首屏正文与新 delta，且 Thought 折叠状态按同周期保留
    let remountRendered = await InkAsyncTestProbe.wait(timeoutNanoseconds: 1_000_000_000) {
      let thoughts = Self.findSubviews(in: host.view, type: InkThoughtBlockView.self)
      let streamTV = Self.findStreamingTextView(in: host.view)
      guard let thought = thoughts.first, let textView = streamTV else { return false }
      return thought.thought.contains("思考过程")
        && thought.isCollapsed
        && textView.text.contains("首屏文本")
        && textView.text.contains("remount 后续")
    }
    #expect(remountRendered)

    let remountedThought = try #require(Self.findSubviews(in: host.view, type: InkThoughtBlockView.self).first)
    let remountedTextView = try #require(Self.findStreamingTextView(in: host.view))

    #expect(remountedThought.isCollapsed)
    #expect(remountedTextView.text.contains("首屏文本"))
    #expect(remountedTextView.text.contains("remount 后续"))
    #expect(session.state == .streaming)

    window.rootViewController = nil
    host.view.removeFromSuperview()
  }
}
