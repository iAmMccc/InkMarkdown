import UIKit

enum MermaidWidgetState {
    case loading
    case codeOnly(String)
    case ready(String, UIImage)
}

/// 固定尺寸的 Mermaid 卡片视图，处理流式解析时的布局跳跃问题
final class MermaidWidgetView: UIView, SSETypewriterSegment {
    
    // MARK: - UI Components
    private let headerView = UIView()
    private let segmentedControl = UISegmentedControl(items: ["预览", "代码"])
    private let copyButton = UIButton(type: .system)
    private let fullscreenButton = UIButton(type: .system)
    
    private let contentView = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let loadingLabel = UILabel()
    private let codeTextView = UITextView()
    private let imageView = UIImageView()
    
    // MARK: - State & Callbacks
    private var state: MermaidWidgetState = .loading {
        didSet { updateUI() }
    }
    
    /// 全屏查看回调
    var onFullscreenRequest: ((UIImage) -> Void)?
    
    /// 高度变化回调（本 Widget 高度固定，但仍需通知以保持协议一致）
    var onHeightChange: (() -> Void)?
    
    private let fixedHeight: CGFloat
    
    init(fixedHeight: CGFloat = 240) {
        self.fixedHeight = fixedHeight
        super.init(frame: .zero)
        setupUI()
        updateUI()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public API
    
    /// 更新 Mermaid 源码（流式追加时调用）
    func updateSource(_ source: String) {
        if case .ready(_, let img) = state {
            state = .ready(source, img)
        } else {
            state = .codeOnly(source)
        }
    }
    
    /// 设置渲染完成的图片
    func setRenderedImage(_ image: UIImage) {
        let currentSource: String
        switch state {
        case .loading: currentSource = ""
        case .codeOnly(let src): currentSource = src
        case .ready(let src, _): currentSource = src
        }
        state = .ready(currentSource, image)
    }
    
    // MARK: - SSETypewriterSegment
    
    var typewriterLength: Int { 1 }
    
    func setVisibleLength(_ length: Int) {
        isHidden = length < 1
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(white: 0.15, alpha: 1) : UIColor(white: 0.95, alpha: 1)
        }
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor
        layer.masksToBounds = true
        
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: fixedHeight).isActive = true
        
        // Header
        headerView.backgroundColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(white: 0.2, alpha: 1) : .white
        }
        headerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerView)
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(segmentedControl)
        
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(copyButton)
        
        fullscreenButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
        fullscreenButton.addTarget(self, action: #selector(fullscreenTapped), for: .touchUpInside)
        fullscreenButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(fullscreenButton)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            segmentedControl.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            
            fullscreenButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            fullscreenButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            fullscreenButton.widthAnchor.constraint(equalToConstant: 32),
            fullscreenButton.heightAnchor.constraint(equalToConstant: 32),
            
            copyButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: fullscreenButton.leadingAnchor, constant: -8),
            copyButton.widthAnchor.constraint(equalToConstant: 32),
            copyButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // Content View
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Loading
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingIndicator)
        
        loadingLabel.text = "正在生成图表..."
        loadingLabel.font = .systemFont(ofSize: 14)
        loadingLabel.textColor = .secondaryLabel
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingLabel)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -12),
            loadingLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 8)
        ])
        
        // Code Text View
        codeTextView.isEditable = false
        codeTextView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        codeTextView.backgroundColor = .clear
        codeTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(codeTextView)
        
        NSLayoutConstraint.activate([
            codeTextView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            codeTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            codeTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            codeTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        
        // Image View
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    private func updateUI() {
        let isPreview = segmentedControl.selectedSegmentIndex == 0
        
        loadingIndicator.isHidden = true
        loadingIndicator.stopAnimating()
        loadingLabel.isHidden = true
        codeTextView.isHidden = true
        imageView.isHidden = true
        fullscreenButton.isEnabled = false
        
        switch state {
        case .loading:
            loadingIndicator.isHidden = false
            loadingIndicator.startAnimating()
            loadingLabel.isHidden = false
            codeTextView.text = ""
            imageView.image = nil
        case .codeOnly(let source):
            codeTextView.text = source
            if isPreview {
                loadingIndicator.isHidden = false
                loadingIndicator.startAnimating()
                loadingLabel.isHidden = false
            } else {
                codeTextView.isHidden = false
            }
        case .ready(let source, let image):
            codeTextView.text = source
            imageView.image = image
            if isPreview {
                imageView.isHidden = false
                fullscreenButton.isEnabled = true
            } else {
                codeTextView.isHidden = false
            }
        }
    }
    
    @objc private func segmentChanged() {
        updateUI()
    }
    
    @objc private func copyTapped() {
        let sourceToCopy: String
        switch state {
        case .loading: return
        case .codeOnly(let src): sourceToCopy = src
        case .ready(let src, _): sourceToCopy = src
        }
        
        guard !sourceToCopy.isEmpty else { return }
        UIPasteboard.general.string = sourceToCopy
        
        // HUD Feedback
        let hud = UILabel()
        hud.text = "已复制"
        hud.textColor = .white
        hud.backgroundColor = UIColor(white: 0, alpha: 0.7)
        hud.font = .systemFont(ofSize: 14)
        hud.textAlignment = .center
        hud.layer.cornerRadius = 6
        hud.layer.masksToBounds = true
        hud.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(hud)
        NSLayoutConstraint.activate([
            hud.centerXAnchor.constraint(equalTo: centerXAnchor),
            hud.centerYAnchor.constraint(equalTo: centerYAnchor),
            hud.widthAnchor.constraint(equalToConstant: 80),
            hud.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        hud.alpha = 0
        UIView.animate(withDuration: 0.2, animations: {
            hud.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 1.0, options: [], animations: {
                hud.alpha = 0
            }) { _ in
                hud.removeFromSuperview()
            }
        }
    }
    
    @objc private func fullscreenTapped() {
        if case .ready(_, let image) = state {
            onFullscreenRequest?(image)
        }
    }
}
