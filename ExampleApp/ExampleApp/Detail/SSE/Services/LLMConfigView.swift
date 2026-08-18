//
//  LLMConfigView.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI

/// 大模型服务配置面板（支持选择、新增、编辑、删除与测试多套 API 端点）。
public struct LLMConfigView: View {

    @ObservedObject private var store = LLMConfigurationStore.shared
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingEditor = false
    @State private var editingConfig: LLMConfiguration?

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("服务协议说明"),
                    footer: Text("提示：所有配置与 API Key 仅保存在本机沙盒，不会上传至任何第三方服务器。")
                ) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("仅支持 OpenAI 兼容格式")
                                .font(.headline)
                            Text("接口需支持标准 `/chat/completions` SSE 流式输出（例如 RightCodes Codex、OpenAI、DeepSeek、Ollama 等）。")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("选择当前生效配置")) {
                    ForEach(store.configs) { config in
                        HStack(spacing: 12) {
                            // 选中勾选指示
                            Image(systemName: store.selectedConfigId == config.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(store.selectedConfigId == config.id ? .blue : .gray.opacity(0.4))
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(config.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    if config.isMock {
                                        Text("无需 Key")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .foregroundColor(.green)
                                            .cornerRadius(4)
                                    } else if config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("待配置 Key")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    } else {
                                        Text("已配置 Key")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    }
                                }

                                if !config.isMock {
                                    Text(config.baseURL)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("模型: \(config.model)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // 显式编辑与配置按钮
                            if !config.isMock {
                                Button {
                                    editingConfig = config
                                    showingEditor = true
                                } label: {
                                    Text(config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "配置 Key" : "编辑")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.orange.opacity(0.15) : Color.blue.opacity(0.1))
                                        .foregroundColor(config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .orange : .blue)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.select(id: config.id)
                            if !config.isMock && config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                editingConfig = config
                                showingEditor = true
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !config.isMock {
                                Button(role: .destructive) {
                                    store.delete(id: config.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }

                                Button {
                                    editingConfig = config
                                    showingEditor = true
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        editingConfig = LLMConfiguration(
                            name: "自定义端点",
                            baseURL: "https://",
                            apiKey: "",
                            model: "gpt-4o-mini"
                        )
                        showingEditor = true
                    } label: {
                        Label("新增服务配置", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }

                    Button {
                        store.resetToDefaults()
                    } label: {
                        Label("恢复默认预设", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("大模型服务设置", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
            )
            .sheet(isPresented: $showingEditor) {
                if let config = editingConfig {
                    LLMConfigEditorView(config: config) { updated in
                        if store.configs.contains(where: { $0.id == updated.id }) {
                            store.update(config: updated)
                        } else {
                            store.add(config: updated)
                        }
                    }
                }
            }
        }
    }
}

/// 单个配置编辑表单。
private struct LLMConfigEditorView: View {

    @Environment(\.presentationMode) private var presentationMode
    @State private var edited: LLMConfiguration
    private let onSave: (LLMConfiguration) -> Void

    init(config: LLMConfiguration, onSave: @escaping (LLMConfiguration) -> Void) {
        self._edited = State(initialValue: config)
        self.onSave = onSave
    }

    private var isValid: Bool {
        if edited.isMock { return true }
        let trimmedURL = edited.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !edited.name.isEmpty && !trimmedURL.isEmpty && trimmedURL.hasPrefix("http")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("配置基本信息")) {
                    TextField("配置名称（如 RightCodes Codex）", text: $edited.name)
                        .disabled(edited.isMock)

                    if !edited.isMock {
                        TextField("请求 Base URL（如 https://right.codes/codex/v1）", text: $edited.baseURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)

                        TextField("目标 Model Name（如 gpt-4o-mini）", text: $edited.model)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }

                if !edited.isMock {
                    Section(
                        header: Text("API 密钥"),
                        footer: Text("API Key 仅用于本地向该端点发起 Bearer 鉴权请求。")
                    ) {
                        SecureField("输入 API Key (sk-...)", text: $edited.apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                } else {
                    Section {
                        Text("此项为本地内置 Mock 模拟服务，按字符逐帧吐字，无需连接网络。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationBarTitle(edited.isMock ? "查看预设" : "编辑配置", displayMode: .inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    onSave(edited)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(!isValid || edited.isMock)
                .fontWeight(.semibold)
            )
        }
    }
}
