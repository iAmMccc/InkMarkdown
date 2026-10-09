/// 图片加载过程中抛出的错误。
public enum ImageLoadError: Error, Sendable {
  /// 已启用图片，但未注入图片管理后端。
  case backendNotConfigured
  /// 图片来源被策略拒绝。
  case sourceRejected
  /// 后端等待队列已满。
  case queueFull
  /// HTTP 响应无效（非 2xx 或无法解析）。
  case invalidResponse
  /// 响应体不是可识别的图片数据。
  case notImageData
  /// 图片解码失败。
  case decodeFailed
  /// Data URL 的 Base64 段无效。
  case invalidBase64
  /// Asset catalog 中找不到指定资源名。
  case assetNotFound(String)
  /// Bundle 中找不到指定路径。
  case bundleNotFound(String)
  /// URL scheme 不在允许列表内。
  case unsupportedScheme
  /// 网络响应超过配置的大小上限（字节数）；在完整载入和解码前安全失败。
  case payloadTooLarge(Int)
  /// 加载超时。
  case timeout
  /// 任务被取消。
  case cancelled
  /// 生成型图片未注入匹配的本地 renderer；绝不会降级为 URL 加载。
  case generatedLoaderUnavailable(owner: String)
}

/// 图片请求被安全策略拒绝的原因（不抛出，供宿主展示或日志）。
public enum ImageRejectReason: Sendable {
  /// 图片功能被全局关闭。
  case disabledByPolicy
  /// 主机名不在白名单。
  case hostNotAllowed(String)
  /// URL scheme 不在白名单。
  case schemeNotAllowed(String)
  /// URL 无法形成当前来源类型所需的有效地址（例如 HTTP(S) 缺少 host）。
  case invalidURL(String)
  /// 载荷超过大小上限（字节数）。
  case payloadTooLarge(Int)
  /// 相对 URL 缺少 `baseURL` 无法解析。
  case noBaseURL
  /// 重定向被策略拦截。
  case redirectBlocked
  /// 等待队列达到 Store 配置的上限。
  case pendingQueueFull(limit: Int)
}
