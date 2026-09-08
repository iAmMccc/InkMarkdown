# ADR-012: 可替换图片管理后端

状态：Accepted。2026-09-07 用户已确认架构、资源责任和配置生命周期，并授权破坏式重构。实现与验证状态见 current-status.md。

现有自定义 loader 只能替换加载阶段，缓存、请求合并、排队和取消仍由 InkImageStore 控制。为让宿主复用完整的图片管理模块，核心提供与 Kingfisher 无关的公开后端接口，库提供的 Kingfisher 实现位于独立 product；删除旧 URLSession 后端，不维护第三套实现。允许破坏式 API 迁移。

后端负责下载、解码、缓存、请求合并和取消；核心负责布局、占位、刷新与呈现生命周期。生成图也纳入统一管理，LaTeX 和 Mermaid 的生成职责仍归各自 addon。

包分发采用单一 Package.swift，新增可选 InkMarkdownKingfisher product 及其独立 target，沿用仓库现有 addon 组织方式。核心 target 不依赖 Kingfisher，也不在公开接口中暴露 Kingfisher 类型；宿主只使用核心与自定义后端时，不因核心而编译或链接 Kingfisher。包级依赖解析仍可能下载 Kingfisher，这是用户接受的取舍，不承诺完全零下载。无需为此维护第二个 Swift Package。

核心在请求入口校验来源，负责取消呈现订阅和丢弃旧结果；后端负责网络响应、重定向、解码、缓存预算和并发限制。自定义后端须遵循公开契约，核心不能替它检查其内部网络实现。

启用图片但没有配置后端时，显示占位并通过失败回调报告 backendNotConfigured。切换后端通过新渲染配置开启新的呈现请求，取消旧订阅，不清空任何宿主共享缓存。后端实例身份参与配置语义比较。

Kingfisher 固定 8.12.0，通过 Packages/packages.json 拉取本地缓存，发布 Package.swift 使用远程 exact 依赖。内置后端默认只使用内存缓存，磁盘持久化由宿主显式开启；生成器与图片尺寸、安全策略共同参与缓存身份。

本 ADR 替代 ADR-011 的 Store 缓存及配置所有权方案，并修订 ADR-006 / ADR-007 的默认网络加载与生成图缓存实现；保留其呈现语义。
