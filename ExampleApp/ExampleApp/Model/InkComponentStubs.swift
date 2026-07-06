import UIKit
import InkMarkdown

// MARK: - 数据来源标签类型

/// 数据来源标签的种类（业务组件，InkMarkdown 核心库不含此类型）。
enum InkSourceTagKind {
  /// 企业维度跳转
  case entDimensionJump(eid: String, dimensionKey: String, dimensionName: String)
  /// 外链来源
  case source(title: String, url: String, snippet: String)
}

// MARK: - 数据来源组件数据

struct InkSourceComponentItem {
  let tags: [InkSourceTagKind]
}

// MARK: - 导出组件数据

struct InkExportComponentItem {
  let label: String
  let exportType: String
  let exportId: String
}

// MARK: - 组件事件

enum InkComponentEvent {
  case export(InkExportComponentItem)
  case sourceTag(InkSourceTagKind)
}

// MARK: - 组件 Block 种类

enum InkComponentKind {
  case export(InkExportComponentItem)
  case source(InkSourceComponentItem)
}

// MARK: - 组件 Block

/// 业务组件 Block（ExampleApp 本地定义，演示用）。
struct InkComponentBlock: InkRenderableBlock {
  let kind: InkComponentKind
  let action: (InkComponentEvent) -> Void

  init(kind: InkComponentKind, action: @escaping (InkComponentEvent) -> Void) {
    self.kind = kind
    self.action = action
  }

  func makeView() -> UIView {
    switch kind {
    case .export(let item):
      return InkExportComponentView(item: item, action: action)
    case .source(let item):
      return InkSourceComponentView(item: item, action: action)
    }
  }
}

// MARK: - 导出组件视图

private final class InkExportComponentView: UIView {

  private let item: InkExportComponentItem
  private let action: (InkComponentEvent) -> Void

  init(item: InkExportComponentItem, action: @escaping (InkComponentEvent) -> Void) {
    self.item = item
    self.action = action
    super.init(frame: .zero)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func setup() {
    let button = UIButton(type: .system)
    button.setTitle(item.label, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
    button.backgroundColor = UIColor(red: 0.93, green: 0.92, blue: 1.0, alpha: 1)
    button.setTitleColor(.label, for: .normal)
    button.layer.cornerRadius = 8
    button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
    button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    addSubview(button)
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: topAnchor, constant: 8),
      button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
      button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
    ])
  }

  @objc private func handleTap() {
    action(.export(item))
  }
}

// MARK: - 数据来源组件视图

private final class InkSourceComponentView: UIView {

  private let item: InkSourceComponentItem
  private let action: (InkComponentEvent) -> Void

  init(item: InkSourceComponentItem, action: @escaping (InkComponentEvent) -> Void) {
    self.item = item
    self.action = action
    super.init(frame: .zero)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func setup() {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
    ])

    for tag in item.tags {
      let button = UIButton(type: .system)
      let title: String
      switch tag {
      case .entDimensionJump(_, _, let name):
        title = name
      case .source(let t, _, _):
        title = t
      }
      button.setTitle(title, for: .normal)
      button.titleLabel?.font = .systemFont(ofSize: 14)
      button.contentHorizontalAlignment = .leading
      button.tag = stack.arrangedSubviews.count
      button.addTarget(self, action: #selector(tagTapped(_:)), for: .touchUpInside)
      stack.addArrangedSubview(button)
    }
  }

  @objc private func tagTapped(_ sender: UIButton) {
    let index = sender.tag
    guard index < item.tags.count else { return }
    action(.sourceTag(item.tags[index]))
  }
}
