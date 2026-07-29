import Foundation
import XCTest
@testable import InkMarkdown

final class InkLaTeXSyntaxTests: XCTestCase {

  func testParseRecognizesInlineAndBlockDelimiters() throws {
    let source = "速度为 $v = \\frac{s}{t}$，\\(a = \\Delta v\\)，以及：\n$$E = mc^2$$"

    let expressions = try InkLaTeXSyntax.parse(source).get()

    XCTAssertEqual(expressions.map(\.delimiter), [.inlineDollar, .inlineParentheses, .blockDollar])
    XCTAssertEqual(expressions.map(\.latex), ["v = \\frac{s}{t}", "a = \\Delta v", "E = mc^2"])
  }

  func testParseIgnoresEscapedDelimiters() throws {
    let source = "价格是 \\$5，路径是 \\\\(not math\\)，但 $x$ 是公式。"

    let expressions = try InkLaTeXSyntax.parse(source).get()

    XCTAssertEqual(expressions.count, 1)
    XCTAssertEqual(expressions.first?.latex, "x")
  }

  func testParseRejectsUnclosedAndEmptyExpressions() {
    XCTAssertEqual(
      InkLaTeXSyntax.parse("$x + 1").failure,
      .unclosedDelimiter(.inlineDollar)
    )
    XCTAssertEqual(
      InkLaTeXSyntax.parse("\\(  \\)").failure,
      .emptyExpression
    )
  }

  func testExpressionRangeIncludesDelimiters() throws {
    let source = "前缀 $x$ 后缀"
    let expression = try XCTUnwrap(InkLaTeXSyntax.parse(source).get().first)

    XCTAssertEqual((source as NSString).substring(with: expression.utf16Range), "$x$")
  }
}

private extension Result where Failure == InkLaTeXError {
  var failure: InkLaTeXError? {
    guard case .failure(let error) = self else { return nil }
    return error
  }
}
