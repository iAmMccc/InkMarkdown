import Foundation
import Testing
import UIKit
@testable import InkMarkdown

// MARK: - 图片业务策略与相对 URL 契约（ticket 06）
//
// 只覆盖默认 host 开放、可选 allowlist、query/fragment 规范化与 relative URL 关键路径；
// 不做 host/URL 非核心排列矩阵。真图渲染继续 opt-in（`isEnabled` 默认 `false`）。

@Suite("图片业务策略与相对 URL 契约")
@MainActor
struct ImageBusinessPolicyTests {

  // MARK: - 默认开关与占位

  @Test("图片真图渲染默认关闭：占位且不产生附件")
  func imageRendering_disabledByDefault_keepsPlaceholder() {
    #expect(InkImageRendering().isEnabled == false)

    let result = InkAttributedRenderer.render("![替代文本](https://example.com/pic.png)")
    #expect(result.string.contains("[🖼 替代文本]"))
    #expect(!Self.hasImageAttachment(result))
  }

  // MARK: - 业务策略默认开放

  @Test("空 host 白名单默认允许所有有效 HTTP(S) host")
  func emptyAllowlist_allowsAllHTTPSByDefault() {
    // 默认策略即 .allowAll（ADR-006：业务策略默认开放）。
    #expect(ImageSecurityPolicy().emptyHostPolicy == .allowAll)
    #expect(ImageSecurityPolicy().allowedHosts.isEmpty)

    let configuration = InkConfiguration(appearance: Self.appearance(with: Self.enabledRendering()))
    let result = InkAttributedRenderer.render("![图](https://any-host.example.com/pic.png)", configuration: configuration)
    #expect(Self.hasImageAttachment(result), "开启真图后任意有效 HTTPS host 无需配置白名单即可渲染")
  }

  @Test("显式 allowlist 时非允许 host 继续被拒绝")
  func explicitAllowlist_rejectsOtherHosts() {
    var rendering = Self.enabledRendering()
    rendering.securityPolicy.allowedHosts = ["cdn.example.com"]

    let allowed = InkAttributedRenderer.render(
      "![图](https://cdn.example.com/pic.png)",
      configuration: InkConfiguration(appearance: Self.appearance(with: rendering))
    )
    #expect(Self.hasImageAttachment(allowed))

    let blocked = InkAttributedRenderer.render(
      "![图](https://other.example.net/pic.png)",
      configuration: InkConfiguration(appearance: Self.appearance(with: rendering))
    )
    #expect(!Self.hasImageAttachment(blocked), "非白名单 host 走占位 fallback")
  }

  @Test("非 HTTP(S) 危险 scheme 仍被资源安全边界拒绝")
  func unsupportedScheme_rejected() {
    let configuration = InkConfiguration(appearance: Self.appearance(with: Self.enabledRendering()))
    let result = InkAttributedRenderer.render("![图](ftp://example.com/pic.png)", configuration: configuration)
    #expect(!Self.hasImageAttachment(result))
  }

  // MARK: - query / fragment 规范化

  @Test("query 默认保留、fragment 默认剥离，且请求与缓存身份一致")
  func queryPreserved_fragmentStripped_byDefault() {
    let source = ImageSource(url: URL(string: "https://cdn.example.com/pic.png?token=abc&size=2#frag")!)

    #expect(source.requestURL.query == "token=abc&size=2")
    #expect(source.requestURL.fragment == nil)
    #expect(source.canonicalID == source.requestURL.absoluteString)
  }

  @Test("开启 stripsQuery 后请求与缓存身份同步剥离")
  func stripsQuery_appliesToRequestAndCanonicalID() {
    let source = ImageSource(
      url: URL(string: "https://cdn.example.com/pic.png?token=abc#frag")!,
      stripsQuery: true,
      stripsFragment: true
    )
    #expect(source.requestURL.query == nil)
    #expect(source.canonicalID == source.requestURL.absoluteString)
  }

  // MARK: - 相对 URL

  @Test("提供 baseURL 时相对图片 source 解析为确定请求 URL")
  func baseURL_resolvesRelativeSource() {
    var rendering = Self.enabledRendering()
    rendering.baseURL = URL(string: "https://docs.example.com/guide/")!

    let appearance = Self.appearance(with: rendering)
    let configuration = InkConfiguration(appearance: appearance)
    let result = InkAttributedRenderer.render("![架构图](images/arch.png)", configuration: configuration)

    #expect(Self.hasImageAttachment(result))
    let source = Self.firstAttachmentSource(result)
    #expect(source?.scheme == .https)
    #expect(source?.requestURL.absoluteString == "https://docs.example.com/guide/images/arch.png")

    // 块级通道同样解析：独占段图片提升为 InkImageBlock。
    let blocks = InkBlockRenderer.render("![](images/hero.png)\n", configuration: configuration)
    let imageBlock = blocks.compactMap { $0 as? InkImageBlock }.first
    #expect(imageBlock?.source.requestURL.absoluteString == "https://docs.example.com/guide/images/hero.png")
  }

  @Test("未提供 baseURL 时相对图片 source 返回明确失败（占位），不猜测来源")
  func missingBaseURL_rejectsRelativeSource() {
    let rendering = Self.enabledRendering()
    let configuration = InkConfiguration(appearance: Self.appearance(with: rendering))

    let inline = InkAttributedRenderer.render("![相对图](images/missing.png)", configuration: configuration)
    #expect(!Self.hasImageAttachment(inline), "相对 URL 且无 baseURL：占位契约，不加载")
    #expect(inline.string.contains("[🖼 相对图]"))

    let blocks = InkBlockRenderer.render("![](images/missing.png)\n", configuration: configuration)
    #expect(blocks.compactMap { $0 as? InkImageBlock }.isEmpty, "块级通道同样不提升未解析的相对图片")

    switch InkImageSourceResolution.resolve(from: "images/missing.png", rendering: rendering) {
    case .rejected(.noBaseURL):
      break
    default:
      Issue.record("无 baseURL 的相对来源必须返回明确 noBaseURL 结果")
    }
  }

  // MARK: - 重定向策略（默认放行 / 白名单重校验）

  @Test("重定向策略复核白名单且不允许非 HTTP(S) 目标")
  func redirectPolicy_revalidatesWhenAllowlistConfigured() {
    let target = URL(string: "https://redirect.example.org/b")!
    #expect(ImageSecurityPolicy().rejectionReason(forRedirectURL: target) == nil)
    var restricted = ImageSecurityPolicy()
    restricted.allowedHosts = ["start.example.com"]
    restricted.redirectRevalidatesHost = false
    #expect(restricted.rejectionReason(forRedirectURL: target) != nil)
    #expect(ImageSecurityPolicy().rejectionReason(forRedirectURL: URL(string: "ftp://example.org/b")!) != nil)
  }

  // MARK: - Helpers

  private static func enabledRendering() -> InkImageRendering {
    var rendering = InkImageRendering()
    rendering.isEnabled = true
    return rendering
  }

  private static func appearance(with rendering: InkImageRendering) -> InkAppearance {
    var appearance = InkAppearance()
    appearance.supportsDynamicType = false
    appearance.imageRendering = rendering
    return appearance
  }

  private static func hasImageAttachment(_ attributed: NSAttributedString) -> Bool {
    var found = false
    attributed.enumerateAttribute(
      .attachment,
      in: NSRange(location: 0, length: attributed.length),
      options: []
    ) { value, _, stop in
      if value is InkImageAttachment {
        found = true
        stop.pointee = true
      }
    }
    return found
  }

  private static func firstAttachmentSource(_ attributed: NSAttributedString) -> ImageSource? {
    var source: ImageSource?
    attributed.enumerateAttribute(
      .attachment,
      in: NSRange(location: 0, length: attributed.length),
      options: []
    ) { value, _, stop in
      if let attachment = value as? InkImageAttachment {
        source = attachment.source
        stop.pointee = true
      }
    }
    return source
  }
}
