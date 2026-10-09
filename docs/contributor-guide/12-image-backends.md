# 可替换图片后端与迁移

未发布版本按 ADR-012 进行破坏式重构。单一 Package 提供核心 InkMarkdown 与可选 InkMarkdownKingfisher product；核心不引用 Kingfisher 类型。仅使用核心的宿主不编译或链接适配器，但 SPM 解析包时仍可能下载 Kingfisher。

## 使用内置后端

```swift
import InkMarkdown
import InkMarkdownKingfisher

@MainActor
func makeConfiguration() -> InkConfiguration {
  var budget = InkKingfisherImageBackend.Configuration()
  budget.memoryBytes = 60 * 1024 * 1024
  budget.maxConcurrentLoads = 4
  budget.maxPendingLoads = 32
  // 默认仅内存缓存。业务允许持久化图片（含生成图）时再开启。
  budget.usesDiskCache = false
  let backend = InkKingfisherImageBackend(configuration: budget)
  var configuration = InkConfiguration.standard
  configuration.appearance.imageRendering.isEnabled = true
  configuration.appearance.imageRendering.backend = backend
  configuration.appearance.imageRendering.onFailure = { source, error in
    // 在这里上报业务错误；避免记录含鉴权信息的完整 URL。
  }
  return configuration
}
```

需要跨视图共享缓存时，持有并复用同一个 backend；不要在每次 SwiftUI body 计算中创建实例。切换账户或鉴权域时使用独立实例。显式配置后端也是 LaTeX / Mermaid 生成图的必要条件，生成器仍由 addon 注册。

磁盘缓存会连同图片数据保存实际 `UIImage.scale`，保证首次生成、内存命中、磁盘命中和重新创建后端后的点尺寸一致。磁盘命中只回填内存，不重复写盘。本次修复使用 v2 缓存命名空间，不复用或主动删除此前未保存 scale 的旧格式缓存。

Asset 图片降采样保留 `UIImage(named:)` 返回的原始 scale；将像素预算除以该 scale 后交给 Kingfisher，避免 2x/3x 图片点尺寸放大，同时遵守请求与后端的像素上限。后端仅为 Asset 增加 `asset-scale-v1:` 内部缓存键前缀，不再读取此前首次解码已丢失 scale 的条目；其他来源缓存不受影响，旧条目不主动删除。宿主仍使用原有 `InkImageRequest.cacheKey` 契约，无需迁移接口。

内置后端将非 2xx 响应报告为 `ImageLoadError.invalidResponse`，将响应长度或累计字节超限报告为 `payloadTooLarge`（包含字节数），将被拒绝的重定向报告为 `sourceRejected`。这些原因会传递到 `onFailure`；主动取消不会伪装成资源拒绝，也不会通知过期的呈现回调。

## 接入宿主模块

实现 `@MainActor InkImageBackend`：

- `cachedImage(for:)` 只查询已解码的内存图片，可返回 nil；不要同步读取磁盘或网络。
- `image(for:) async throws` 返回图片或错误；内部负责加载、解码、缓存、请求合并和资源限制。
- 对生成图请求调用 `request.generator.loadImage(source:display:)`，并将生成结果纳入相同缓存与调度体系；不要把生成图 URL 发送到网络。
- 使用 `request.cacheKey` 或包含同等信息的键，隔离尺寸、生成器和安全策略。不同租户与鉴权域另外隔离后端或缓存命名空间。
- 遵守 `request.securityPolicy` 的传输和来源限制。核心做入口来源校验，但无法检查宿主内部的下载、重定向或缓存实现。
- 取消一个调用只释放它的订阅，不取消其他使用者；最后一个使用者取消后停止底层任务，并保证等待调用完成。不要在取消后缓存过期结果。

将自定义实例赋给 `configuration.appearance.imageRendering.backend`。核心不会再添加第二层图片缓存或并发队列。核心保证取消后的呈现回调不会生效，但无法阻止不遵守取消契约的自定义后端继续占用资源。

## 迁移对照

| 旧入口 | 新入口 |
| --- | --- |
| `imageRendering.loader` / `setLoader` | `imageRendering.backend`，接管完整管理职责 |
| `DefaultURLSessionImageLoader` | `InkKingfisherImageBackend` 或自定义后端 |
| `InkImageStore.Configuration` / `storeConfiguration` | 后端实例的 Configuration；配置不由视图覆盖 |
| `storeConfiguration.maxDataURLBytes` | `imageRendering.maxDataURLBytes` |
| `InkImageStore.shared` | 宿主显式持有和共享 backend |
| `InkImageStore.removeAllCachedImages` | 宿主调用其后端的缓存清理 API |
| 预览的 `loader` / `store` / `bypassStore` | 传入 `rendering` 复用完整后端；缓存由后端管理 |

InkImageStore 现在只负责呈现订阅桥接，不拥有缓存和调度预算。其 `resolve` 的异步结果在调用 `subscribe` 后才开始加载；订阅取消后不再通知。底层 `InkImageLoading` 用于生成器与请求桥接，不再是完整后端配置入口。

`InkImageBlock` 在首次加载前和复用重置后预留 `placeholderHeight`，不再返回零高度；加载完成或失败时会更新 intrinsic content size，直接使用 Auto Layout 的 UIKit 宿主无需另外维护高度约束。

图片未配置后端时显示失败占位，通过 `onFailure` 报告 `backendNotConfigured`。生成图失败仍按原呈现契约降级。替换渲染配置的 backend 后，宿主应更新渲染内容；SwiftUI adapter 根据配置语义重建呈现，旧订阅取消，已有后端缓存保持不变。

## 本地依赖

`Packages/packages.json` 固定 Kingfisher 8.12.0，运行 `bash Packages/scripts/fetch-packages.sh` 可准备 `Packages/Caches/Kingfisher`。该目录由 Git 忽略。发布 manifest 保持远程 exact 依赖，不提交本地 path 覆盖。
