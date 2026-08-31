//
//  SwiftUIStreamingMarkdownDemoView.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI
import InkMarkdown
import InkMarkdownSwiftUI

/// 展示宿主驱动 `InkMarkdownRenderSession` 的流式 Markdown 用法（支持本地模拟与真实 OpenAI SSE 请求）。
struct SwiftUIStreamingMarkdownDemoView: View {

  @StateObject private var viewModel = StreamingDemoViewModel()
  @ObservedObject private var configStore = LLMConfigurationStore.shared
  @State private var isStreamRendererMounted = true
  @State private var usesNarrowStreamWidth = false
  @State private var thoughtDemoStep = 0

  private var canAppendThought: Bool {
    viewModel.session.state == .idle || viewModel.session.state == .streaming
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        HStack(spacing: 4) {
          Image(systemName: configStore.activeConfig.isMock ? "internaldrive" : "network")
            .font(.caption2)
          Text(configStore.activeConfig.name)
            .font(.caption)
            .fontWeight(.medium)
            .lineLimit(1)
        }

        Spacer()

        if !configStore.activeConfig.isMock {
          // 快捷切换模型 Menu
          Menu {
            Section(header: Text("GPT 5.6 全系列")) {
              ForEach(LLMModelPresets.gpt56Series) { preset in
                Button {
                  configStore.updateActiveModel(preset.id)
                } label: {
                  HStack {
                    Text(preset.name)
                    if configStore.activeConfig.model == preset.id {
                      Image(systemName: "checkmark")
                    }
                  }
                }
              }
            }

            Section(header: Text("热门推理/通用模型")) {
              ForEach(LLMModelPresets.popularModels) { preset in
                Button {
                  configStore.updateActiveModel(preset.id)
                } label: {
                  HStack {
                    Text(preset.name)
                    if configStore.activeConfig.model == preset.id {
                      Image(systemName: "checkmark")
                    }
                  }
                }
              }
            }
          } label: {
            HStack(spacing: 3) {
              Text(configStore.activeConfig.model)
                .font(.caption2)
                .fontWeight(.medium)
              Image(systemName: "chevron.down")
                .font(.system(size: 8))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.12))
            .foregroundColor(.blue)
            .cornerRadius(5)
          }

          // 快捷切换推理程度 Menu
          Menu {
            ForEach(LLMReasoningEffort.allCases) { effort in
              Button {
                configStore.updateActiveReasoningEffort(effort)
              } label: {
                HStack {
                  Text(effort.displayName)
                  if configStore.activeConfig.reasoningEffort == effort {
                    Image(systemName: "checkmark")
                  }
                }
              }
            }
          } label: {
            HStack(spacing: 3) {
              Image(systemName: "brain.head.profile")
                .font(.system(size: 9))
              Text(configStore.activeConfig.reasoningEffort.shortName)
                .font(.caption2)
                .fontWeight(.medium)
              Image(systemName: "chevron.down")
                .font(.system(size: 8))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.purple.opacity(0.12))
            .foregroundColor(.purple)
            .cornerRadius(5)
          }
        }

        Button {
          viewModel.showingConfigSheet = true
        } label: {
          Image(systemName: "slider.horizontal.3")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(Color(UIColor.secondarySystemBackground))

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 10) {
            Text("连续性手工验收")
              .font(.headline)
            Text("重置后按顺序：追加 Thought 分片 → 折叠/展开 → 继续追加 → 切换宽度 → 卸载/重新挂载 → 结束 Thought 并完成输入观察 promotion；最后用取消/重置验证新周期。")
              .font(.footnote)
              .foregroundColor(.secondary)
            HStack(spacing: 8) {
              Button(isStreamRendererMounted ? "卸载渲染视图" : "重新挂载渲染视图") {
                isStreamRendererMounted.toggle()
              }
              Button(usesNarrowStreamWidth ? "切换全宽" : "切换窄宽") {
                usesNarrowStreamWidth.toggle()
              }
            }
          }

          if let error = viewModel.errorMessage {
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
              Text(error)
                .font(.footnote)
                .foregroundColor(.red)
            }
            .padding(10)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
          }

          if isStreamRendererMounted {
            InkStreamMarkdownView(session: viewModel.session)
              .frame(width: usesNarrowStreamWidth ? 280 : nil, alignment: .leading)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            Text("渲染视图已卸载；会话未重置。点击“重新挂载渲染视图”继续。")
              .font(.footnote)
              .foregroundColor(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(Color(UIColor.secondarySystemBackground))
              .cornerRadius(8)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
      }

      Divider()

      VStack(alignment: .leading, spacing: 10) {
        Text(viewModel.stateDescription)
          .font(.footnote)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
          TextField("输入自定义提问...", text: $viewModel.inputPrompt)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .disabled(viewModel.isLoading)

          Button {
            viewModel.sendRealPrompt(config: configStore.activeConfig)
          } label: {
            if viewModel.isLoading {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .frame(width: 24, height: 24)
            } else {
              Text("发送")
                .fontWeight(.medium)
            }
          }
          .disabled(viewModel.isLoading || viewModel.inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(8)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Thought 分片")
            .font(.subheadline)
            .fontWeight(.medium)
          HStack(spacing: 8) {
            Button("追加 Thought 分片") {
              viewModel.session.append("<think>\n第一片 Thought：先观察折叠状态。")
              thoughtDemoStep = 1
            }
            .disabled(thoughtDemoStep != 0 || !canAppendThought)

            Button("继续 Thought 分片") {
              viewModel.session.append("\n第二片 Thought：折叠后继续接收内容。")
              thoughtDemoStep = 2
            }
            .disabled(thoughtDemoStep != 1 || !canAppendThought)
          }
          Button("结束 Thought") {
            viewModel.session.append("\n</think>\n\nThought 后的普通回答。")
            thoughtDemoStep = 3
          }
          .disabled(thoughtDemoStep != 2 || !canAppendThought)
        }

        HStack(spacing: 8) {
          Button("追加模拟分片") {
            viewModel.appendNextMockChunk()
          }
          .disabled(!viewModel.canAppendMock)

          Button("完成输入") {
            viewModel.finishStreaming()
          }
          .disabled(!viewModel.canFinish)

          Spacer()

          Button("取消") {
            viewModel.cancelStreaming()
            thoughtDemoStep = 0
          }
          .disabled(!viewModel.canCancel)
          .foregroundColor(.red)

          Button("重置") {
            viewModel.resetSession()
            thoughtDemoStep = 0
          }
        }
        .font(.subheadline)
      }
      .padding(12)
      .background(Color(UIColor.systemBackground))
    }
    .navigationBarTitle("流式 Markdown", displayMode: .inline)
    .navigationBarItems(trailing: Button(action: {
      viewModel.showingConfigSheet = true
    }) {
      Image(systemName: "gearshape")
    })
    .sheet(isPresented: $viewModel.showingConfigSheet) {
      LLMConfigView()
    }
    .onDisappear {
      viewModel.onDisappear()
    }
  }
}
