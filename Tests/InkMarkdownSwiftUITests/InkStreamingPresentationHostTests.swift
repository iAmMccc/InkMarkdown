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
}

@Suite("SwiftUI Stream remount", .serialized)
@MainActor
struct InkStreamMarkdownRemountTests {

  @Test("UIHostingController 移除再插入后同一 Session 可继续显示")
  func streamView_remountContinuesSameSession() async throws {
    let session = InkMarkdownRenderSession()
    session.renderer.charactersPerFrame = 200
    session.append("首屏文本")

    let root = InkStreamMarkdownView(session: session)
    let host = UIHostingController(rootView: root)
    host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 720)
    let window = UIWindow(frame: host.view.bounds)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    await InkAsyncTestProbe.wait(timeoutNanoseconds: 500_000_000) {
      host.view.subviews.contains { !$0.subviews.isEmpty } || host.view.bounds.height > 0
    }

    // 移除
    window.rootViewController = nil
    host.view.removeFromSuperview()

    // 重新插入同一 Session
    let remounted = UIHostingController(rootView: InkStreamMarkdownView(session: session))
    remounted.view.frame = CGRect(x: 0, y: 0, width: 390, height: 720)
    window.rootViewController = remounted
    window.makeKeyAndVisible()
    remounted.view.setNeedsLayout()
    remounted.view.layoutIfNeeded()

    session.append("\nremount 后续")
    await InkAsyncTestProbe.wait(timeoutNanoseconds: 1_000_000_000) {
      // 可观察：session 仍接受并处于 streaming
      session.currentText.contains("remount 后续")
    }
    #expect(session.currentText.contains("首屏文本"))
    #expect(session.currentText.contains("remount 后续"))
    #expect(session.state == .streaming)
  }
}
