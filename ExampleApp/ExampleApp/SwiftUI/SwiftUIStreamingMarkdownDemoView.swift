//
//  SwiftUIStreamingMarkdownDemoView.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI
import InkMarkdownSwiftUI

/// 展示宿主驱动 `InkMarkdownRenderSession` 的流式 Markdown 用法（支持本地模拟与真实 OpenAI SSE 请求）。
struct SwiftUIStreamingMarkdownDemoView: View {

  @StateObject private var viewModel = StreamingDemoViewModel()
  @ObservedObject private var configStore = LLMConfigurationStore.shared

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Image(systemName: configStore.activeConfig.isMock ? "internaldrive" : "network")
          .font(.caption)
        Text("当前端点: \(configStore.activeConfig.name)")
          .font(.caption)
          .fontWeight(.medium)
        if !configStore.activeConfig.isMock {
          Text("(\(configStore.activeConfig.model))")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        Spacer()
        Button {
          viewModel.showingConfigSheet = true
        } label: {
          Text("切换配置")
            .font(.caption)
            .foregroundColor(.blue)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Color(UIColor.secondarySystemBackground))

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
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

          InkStreamMarkdownView(session: viewModel.session)
            .frame(maxWidth: .infinity, alignment: .leading)
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
          }
          .disabled(!viewModel.canCancel)
          .foregroundColor(.red)

          Button("重置") {
            viewModel.resetSession()
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
