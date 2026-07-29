import Foundation
import Markdown
import XCTest
@testable import InkMarkdown

final class InkLaTeXSyntaxTests: XCTestCase {

  func testParseRecognizesInlineAndBlockDelimitersWithDollarOptIn() throws {
    let source = "速度为 $v = \\frac{s}{t}$，\\(a = \\Delta v\\)，以及：\n$$E = mc^2$$\n\\[F = ma\\]"
    let options = InkLaTeXParseOptions(allowsInlineDollarDelimiter: true)

    let expressions = try InkLaTeXSyntax.parse(source, options: options).get()

    XCTAssertEqual(
      expressions.map(\.delimiter),
      [.inlineDollar, .inlineParentheses, .blockDollar, .blockBrackets]
    )
    XCTAssertEqual(expressions.map(\.latex), ["v = \\frac{s}{t}", "a = \\Delta v", "E = mc^2", "F = ma"])
  }

  func testParseIgnoresInlineDollarWithoutOptIn() throws {
    let source = "价格是 $5，但 \\(a\\) 仍识别。"

    let expressions = try InkLaTeXSyntax.parse(source).get()

    XCTAssertEqual(expressions.count, 1)
    XCTAssertEqual(expressions.first?.delimiter, .inlineParentheses)
    XCTAssertEqual(expressions.first?.latex, "a")
  }

  func testParseIgnoresEscapedDelimiters() throws {
    let source = "价格是 \\$5，路径是 \\\\(not math\\)，但 $x$ 是公式。"
    let options = InkLaTeXParseOptions(allowsInlineDollarDelimiter: true)

    let expressions = try InkLaTeXSyntax.parse(source, options: options).get()

    XCTAssertEqual(expressions.count, 1)
    XCTAssertEqual(expressions.first?.latex, "x")
  }

  func testParseRejectsUnclosedAndEmptyExpressions() {
    XCTAssertEqual(
      InkLaTeXSyntax.parse("$x + 1", options: InkLaTeXParseOptions(allowsInlineDollarDelimiter: true)).failure,
      .unclosedDelimiter(.inlineDollar)
    )
    XCTAssertEqual(
      InkLaTeXSyntax.parse("\\(  \\)").failure,
      .emptyExpression
    )
    XCTAssertEqual(
      InkLaTeXSyntax.parse("\\[  \\]").failure,
      .emptyExpression
    )
    XCTAssertEqual(
      InkLaTeXSyntax.parse("\\[x + 1").failure,
      .unclosedDelimiter(.blockBrackets)
    )
  }

  func testExpressionRangeIncludesDelimiters() throws {
    let source = "前缀 $x$ 后缀"
    let expression = try XCTUnwrap(
      InkLaTeXSyntax.parse(source, options: InkLaTeXParseOptions(allowsInlineDollarDelimiter: true)).get().first
    )

    XCTAssertEqual((source as NSString).substring(with: expression.utf16Range), "$x$")
  }

  func testBlockBracketsRequiresExclusiveParagraphContent() throws {
    let positive = "\\[E = mc^2\\]"
    let expression = try XCTUnwrap(InkLaTeXSyntax.parse(positive).get().first)
    XCTAssertEqual(expression.delimiter, .blockBrackets)
    XCTAssertEqual(expression.latex, "E = mc^2")

    let mixed = "前缀 \\[E = mc^2\\] 后缀"
    let mixedExpressions = try InkLaTeXSyntax.parse(mixed).get()
    XCTAssertEqual(mixedExpressions.first?.delimiter, .blockBrackets)
  }

  func testSourcePreservationSurvivesMarkdownParser() {
    let prepared = InkLaTeXSourcePreservation.preserveBracketDelimiters(in: "前缀 \\(x\\) 后缀")
    let document = InkParser.parse(prepared)
    let text = plainText(in: document)
    XCTAssertEqual(
      text,
      "前缀 \(InkLaTeXSourcePreservation.inlineOpen)x\(InkLaTeXSourcePreservation.inlineClose) 后缀"
    )
  }

  func testSourcePreservationSkipsEscapedAndCodeDelimiters() {
    let escaped = InkLaTeXSourcePreservation.preserveBracketDelimiters(in: "\\\\(not math\\\\)")
    XCTAssertEqual(escaped, "\\\\(not math\\\\)")

    let code = InkLaTeXSourcePreservation.preserveBracketDelimiters(in: "`\\(x\\)`")
    XCTAssertEqual(code, "`\\(x\\)`")

    let fenced = InkLaTeXSourcePreservation.preserveBracketDelimiters(in: "```\n\\(x\\)\n```")
    XCTAssertEqual(fenced, "```\n\\(x\\)\n```")
  }

  func testRestoreBracketDelimitersReversesPlaceholders() {
    let preserved = InkLaTeXSourcePreservation.preserveBracketDelimiters(in: "前缀 \\(x\\) 后缀")
    let restored = InkLaTeXSourcePreservation.restoreBracketDelimiters(in: preserved)
    XCTAssertEqual(restored, "前缀 \\(x\\) 后缀")
  }

  func testMarkupParseOptionsIgnoreBackslashBracketDelimiters() throws {
    let markupText = "\\(x\\)"
    let options = InkLaTeXParseOptions(
      recognizesPreservedBracketDelimiters: true,
      recognizesBackslashBracketDelimiters: false
    )
    XCTAssertTrue(try InkLaTeXSyntax.parse(markupText, options: options).get().isEmpty)

    let preserved = InkLaTeXSourcePreservation.preserveBracketDelimiters(in: "\\(x\\)")
    let expressions = try InkLaTeXSyntax.parse(preserved, options: options).get()
    XCTAssertEqual(expressions.count, 1)
    XCTAssertEqual(expressions.first?.latex, "x")
  }
}

private extension Result where Failure == InkLaTeXError {
  var failure: InkLaTeXError? {
    guard case .failure(let error) = self else { return nil }
    return error
  }
}

private func plainText(in markup: Markup) -> String {
  if let text = markup as? Text { return text.string }
  return markup.children.map { plainText(in: $0) }.joined()
}
