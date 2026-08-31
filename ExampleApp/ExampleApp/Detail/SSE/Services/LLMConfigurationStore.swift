//
//  LLMConfigurationStore.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import Foundation
import Combine

/// 大模型服务配置持久化管理器。
@MainActor
public final class LLMConfigurationStore: ObservableObject {

  public static let shared = LLMConfigurationStore()

  private let storageKey = "InkMarkdown_LLM_Configurations"
  private let selectedIdKey = "InkMarkdown_LLM_SelectedConfigID"

  @Published public private(set) var configs: [LLMConfiguration] = []
  @Published public private(set) var selectedConfigId: UUID = LLMConfiguration.mockPreset.id

  private init() {
    load()
  }

  /// 当前激活生效的大模型配置。
  public var activeConfig: LLMConfiguration {
    if let found = configs.first(where: { $0.id == selectedConfigId }) {
      return found
    }
    return configs.first ?? LLMConfiguration.mockPreset
  }

  /// 快捷切换当前激活配置的目标模型。
  public func updateActiveModel(_ model: String) {
    var current = activeConfig
    guard current.model != model else { return }
    current.model = model
    update(config: current)
  }

  /// 快捷切换当前激活配置的推理程度。
  public func updateActiveReasoningEffort(_ effort: LLMReasoningEffort) {
    var current = activeConfig
    guard current.reasoningEffort != effort else { return }
    current.reasoningEffort = effort
    update(config: current)
  }

  /// 选中指定配置。
  public func select(id: UUID) {
    guard configs.contains(where: { $0.id == id }) else { return }
    selectedConfigId = id
    save()
  }

  /// 添加新配置并自动设为当前选中。
  public func add(config: LLMConfiguration) {
    configs.append(config)
    selectedConfigId = config.id
    save()
  }

  /// 更新已有配置。
  public func update(config: LLMConfiguration) {
    if let index = configs.firstIndex(where: { $0.id == config.id }) {
      configs[index] = config
      save()
    }
  }

  /// 删除指定配置（如果是内置 Mock 则不允许删除）。
  public func delete(id: UUID) {
    guard id != LLMConfiguration.mockPreset.id else { return }
    configs.removeAll(where: { $0.id == id })
    if selectedConfigId == id {
      selectedConfigId = configs.first?.id ?? LLMConfiguration.mockPreset.id
    }
    save()
  }

  /// 重置为默认预设列表。
  public func resetToDefaults() {
    configs = LLMConfiguration.defaultPresets
    selectedConfigId = LLMConfiguration.mockPreset.id
    save()
  }

  // MARK: - Persistence

  private func load() {
    let defaults = UserDefaults.standard
    if let data = defaults.data(forKey: storageKey),
      let decoded = try? JSONDecoder().decode([LLMConfiguration].self, from: data),
      !decoded.isEmpty {
      self.configs = migratePersistedConfigs(decoded)
      if self.configs != decoded {
        save()
      }
    } else {
      self.configs = LLMConfiguration.defaultPresets
    }

    if let savedIdString = defaults.string(forKey: selectedIdKey),
      let savedId = UUID(uuidString: savedIdString),
      configs.contains(where: { $0.id == savedId }) {
      self.selectedConfigId = savedId
    } else {
      self.selectedConfigId = configs.first?.id ?? LLMConfiguration.mockPreset.id
    }
  }

  /// 迁移已持久化的配置：按稳定 id 合并新增内置预设（如 DeepSeek R1），并平滑升级旧 host / model。
  private func migratePersistedConfigs(_ configs: [LLMConfiguration]) -> [LLMConfiguration] {
    let rightCodesId = LLMConfiguration.rightCodesPreset.id
    var result = configs.map { config -> LLMConfiguration in
      guard config.id == rightCodesId else { return config }
      var migrated = config
      if migrated.baseURL.contains("right.codes") {
        migrated.baseURL = LLMEndpointPresets.rightCodesBaseURL
      }
      if migrated.model == "gpt-4o-mini" {
        migrated.model = LLMModelPresets.rightCodesDefault
      }
      return migrated
    }

    // 按稳定 ID 补齐新版本新增的内置预设，保留老用户已有配置与 Key
    for preset in LLMConfiguration.defaultPresets {
      if !result.contains(where: { $0.id == preset.id }) {
        result.append(preset)
      }
    }

    return result
  }

  private func save() {
    let defaults = UserDefaults.standard
    if let encoded = try? JSONEncoder().encode(configs) {
      defaults.set(encoded, forKey: storageKey)
    }
    defaults.set(selectedConfigId.uuidString, forKey: selectedIdKey)
  }
}
