import UIKit
import InkMarkdown

/// 第一层：大分类入口列表。
class StoreViewController: DemoListViewController {

  private let categories = DemoCategory.allCases

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "InkMarkdown"
      
    print("首页启动了")

    // TODO: YC - 目前用于测试的代码，后续记得删除
    let markdown = "**~~x~~**"
    let result = InkAttributedRenderer.render(markdown)

    print("纯文本内容 \"\(result.string)\"")

    print("----【属性 RUNs 遍历检测】-----")

    let fullRange = NSRange(location: 0, length: result.length)
    result.enumerateAttributes(in: fullRange) {
      attributes,
      range,
      _ in
      guard let swiftRange = Range(range, in: result.string) else { return }

      let slice = result.string[swiftRange]

      // 解析查看是否有删除线样式
      let rawStyle = attributes[.strikethroughStyle] as? Int ?? 0
      let underlineStyle = NSUnderlineStyle(rawValue: rawStyle)
      let hasStrikethrough = underlineStyle.contains(.single) || rawStyle != 0

      // 解析字体粗体样式
      let font = attributes[.font] as? UIFont
      let isBold = font?.fontDescriptor.symbolicTraits.contains(
        .traitBold
      ) ?? false
      // 格式化输出检测结果


      print("""
       📍 范围: \(range.location..<(range.location + range.length)) | 文本: "\(slice)"
          └─ 删除线(Strikethrough): \(hasStrikethrough ? "✅ 存在 (Style RawValue=\(rawStyle))" : "❌ 无")
          └─ 粗体(Bold): \(isBold ? "✅ 存在" : "❌ 无")
       """)
    }

  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    categories.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let category = categories[indexPath.row]
    return dequeueSubtitleCell(title: category.title, subtitle: category.subtitle)
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    super.tableView(tableView, didSelectRowAt: indexPath)
    let category = categories[indexPath.row]
    let listVC = CategoryListViewController(category: category)
    navigationController?.pushViewController(listVC, animated: true)
  }
}
