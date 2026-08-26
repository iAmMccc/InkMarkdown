//
//  InkMarkdownViewTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import SwiftUI
@testable import InkMarkdownSwiftUI
import InkMarkdown

@Suite("InkMarkdownView 静态视图契约与集成测试")
@MainActor
struct InkMarkdownViewTests {

  @Test("InkMarkdownView 在 UIHostingController 中完成全链路静态渲染")
  func viewRendersContentThroughUIHostingController() throws {
    let view = InkMarkdownView("## 测试标题\n正文第一段内容。")
    let host = renderInWindow(view)

    let container = try #require(findContainerView(in: host.view))
    #expect(!container.subviews.isEmpty)

    let textView = try #require(container.subviews.first as? UITextView)
    #expect(textView.attributedText.string.contains("测试标题"))
    #expect(textView.attributedText.string.contains("正文第一段内容。"))
  }

  @Test("InkMarkdownView 接受显式 configuration 并正确生效")
  func viewAppliesExplicitConfiguration() throws {
    var config = InkConfiguration.standard
    config.sourceFilter = { _ in "被 sourceFilter 重写的内容" }

    let view = InkMarkdownView("原始文本", configuration: config)
    let host = renderInWindow(view)

    let container = try #require(findContainerView(in: host.view))
    let textView = try #require(container.subviews.first as? UITextView)
    #expect(textView.attributedText.string.contains("被 sourceFilter 重写的内容"))
    #expect(!textView.attributedText.string.contains("原始文本"))
  }

  @Test("InkMarkdownView 组合 .inkConfiguration 修饰符由环境注入配置")
  func viewAppliesEnvironmentConfigurationModifier() throws {
    var customConfig = InkConfiguration.standard
    customConfig.sourceFilter = { _ in "来自 Environment 的文本" }

    let view = InkMarkdownView("待渲染源文本")
      .inkConfiguration(customConfig)

    let host = renderInWindow(view)

    let container = try #require(findContainerView(in: host.view))
    let textView = try #require(container.subviews.first as? UITextView)
    #expect(textView.attributedText.string.contains("来自 Environment 的文本"))
  }

  @Test("InkMarkdownCoordinator 保证相同 Markdown 与相同配置下的渲染幂等性")
  func coordinatorStaticRenderingIdempotency() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container

    coordinator.updateStatic(markdown: "幂等测试文本", configuration: .standard)
    let firstTextView = try #require(container.subviews.first as? UITextView)
    let firstText = firstTextView.attributedText.string

    // 相同参数再次调用：保持既有视图实例，不重复创建
    coordinator.updateStatic(markdown: "幂等测试文本", configuration: .standard)
    let secondTextView = try #require(container.subviews.first as? UITextView)
    #expect(firstTextView === secondTextView)
    #expect(firstText == secondTextView.attributedText.string)

    // 配置变更：重新生成渲染块
    var alteredConfig = InkConfiguration.standard
    alteredConfig.sourceFilter = { _ in "变更后的文本" }
    coordinator.updateStatic(markdown: "幂等测试文本", configuration: alteredConfig)
    let thirdTextView = try #require(container.subviews.first as? UITextView)
    #expect(thirdTextView.attributedText.string.contains("变更后的文本"))

    coordinator.teardown()
    #expect(coordinator.containerView == nil)
  }

  @Test("InkMarkdownView 适配 iPhone 窄屏与 iPad 宽屏视口尺寸")
  func viewAdaptsToVariousDeviceWidthsAndiPadViewports() throws {
    let markdown = """
    # 跨平台视口排版测试
    这是一段用于验证各种屏幕宽度自适应的段落文本。
    - 列表项 A
    - 列表项 B
    """

    let widths: [CGFloat] = [320, 375, 430, 768, 1024]
    for width in widths {
      let host = renderInWindow(InkMarkdownView(markdown), frame: CGRect(x: 0, y: 0, width: width, height: 800))
      let container = try #require(findContainerView(in: host.view))
      let size = container.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
      #expect(size.width == width)
      #expect(size.height > 50)
    }
  }

  @Test("InkMarkdownView 在深色模式环境下正确解析为 dark style")
  func viewResolvesDarkColorSchemeInSwiftUIEnvironment() throws {
    let view = InkMarkdownView("## 深色环境测试")
      .preferredColorScheme(.dark)
    let host = renderInWindow(view)

    let container = try #require(findContainerView(in: host.view))
    #expect(container.currentConfiguration?.renderEnvironment.userInterfaceStyle == .dark)
  }

  // MARK: - Helpers

  private func renderInWindow<V: View>(_ view: V, frame: CGRect = CGRect(x: 0, y: 0, width: 375, height: 667)) -> UIHostingController<V> {
    let host = UIHostingController(rootView: view)
    let window = UIWindow(frame: frame)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.frame = frame
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    return host
  }

  private func findContainerView(in view: UIView) -> InkMarkdownContainerView? {
    if let container = view as? InkMarkdownContainerView {
      return container
    }
    for sub in view.subviews {
      if let found = findContainerView(in: sub) {
        return found
      }
    }
    return nil
  }
}
