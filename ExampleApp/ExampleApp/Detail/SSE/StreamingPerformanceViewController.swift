import UIKit
@_spi(Performance) import InkMarkdown

final class StreamingPerformanceViewController: UIViewController {
  private let resultLabel = UILabel()
  private let previewTextView = UITextView()
  private let runButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "增量渲染性能对比"
    view.backgroundColor = .systemBackground
    setupLayout()
    runBenchmark()
  }

  private func setupLayout() {
    let scrollView = UIScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)

    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 16
    stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(stackView)

    let introLabel = UILabel()
    introLabel.numberOfLines = 0
    introLabel.font = .preferredFont(forTextStyle: .body)
    introLabel.text = "同一批 AI 流式 Markdown 分片：旧路径每次追加后全量解析当前 buffer；新路径缓存稳定块，只解析当前活跃尾部。"

    runButton.setTitle("重新测试", for: .normal)
    runButton.addTarget(self, action: #selector(runBenchmark), for: .touchUpInside)

    resultLabel.numberOfLines = 0
    resultLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
    resultLabel.textColor = .secondaryLabel

    previewTextView.isEditable = false
    previewTextView.isScrollEnabled = false
    previewTextView.backgroundColor = .secondarySystemBackground
    previewTextView.layer.cornerRadius = 8
    previewTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

    stackView.addArrangedSubview(introLabel)
    stackView.addArrangedSubview(runButton)
    stackView.addArrangedSubview(resultLabel)
    stackView.addArrangedSubview(previewTextView)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),

      stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
    ])
  }

  @objc private func runBenchmark() {
    runButton.isEnabled = false
    resultLabel.text = "测试中..."
    previewTextView.attributedText = nil

    Task { @MainActor [weak self] in
      await Task.yield()
      let result = InkStreamingPerformanceBenchmark.measure()
      self?.apply(result)
    }
  }

  private func apply(_ result: InkStreamingPerformanceBenchmark.Result) {
    runButton.isEnabled = true
    let speedup = result.incrementalRenderSeconds > 0 ? result.fullRenderSeconds / result.incrementalRenderSeconds : 0
    resultLabel.text = """
    chunks: \(result.chunkCount)
    full render: \(Self.format(result.fullRenderSeconds))
    incremental: \(Self.format(result.incrementalRenderSeconds))
    speedup: \(String(format: "%.1f", speedup))x
    output match: \(result.outputMatches ? "yes" : "no")
    """
    previewTextView.attributedText = result.preview
  }

  private static func format(_ seconds: TimeInterval) -> String {
    String(format: "%.3f ms", seconds * 1000)
  }
}
