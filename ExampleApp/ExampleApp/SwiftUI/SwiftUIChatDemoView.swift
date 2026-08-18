//
//  SwiftUIChatDemoView.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI
import InkMarkdownSwiftUI

/// SwiftUI 架构下的 AI SSE 流式对话问答页面（MVVM：逻辑在 `ChatDemoViewModel`）。
struct SwiftUIChatDemoView: View {

  @StateObject private var viewModel = ChatDemoViewModel()
  @ObservedObject private var configStore = LLMConfigurationStore.shared

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Image(systemName: configStore.activeConfig.isMock ? "internaldrive" : "network")
          .font(.caption)
        Text("当前服务: \(configStore.activeConfig.name)")
          .font(.caption)
          .fontWeight(.medium)
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

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 16) {
            if viewModel.messages.isEmpty {
              VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                  .font(.system(size: 40))
                  .foregroundColor(.secondary)
                Text("开始一次 AI 流式对话")
                  .font(.headline)
                Text("支持标准 Markdown、代码块、表格、LaTeX 公式与 Mermaid 图表。")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 24)

                HStack(spacing: 8) {
                  suggestionButton("介绍 Swift 闭包", proxy: proxy)
                  suggestionButton("展示公式与图表", proxy: proxy)
                }
              }
              .padding(.top, 40)
            }

            ForEach(viewModel.messages) { msg in
              HStack {
                if msg.isUser {
                  Spacer()
                  Text(msg.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .frame(maxWidth: 280, alignment: .trailing)
                } else {
                  VStack(alignment: .leading, spacing: 6) {
                    if msg.isStreaming {
                      InkStreamMarkdownView(session: viewModel.session)
                    } else {
                      InkMarkdownView(msg.content, configuration: viewModel.chatConfiguration)
                    }
                  }
                  .padding(14)
                  .background(Color(UIColor.secondarySystemBackground))
                  .cornerRadius(14)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  Spacer()
                }
              }
              .id(msg.id)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 16)
        }
        .onChange(of: viewModel.messages.count) { _ in
          if let last = viewModel.messages.last {
            withAnimation {
              proxy.scrollTo(last.id, anchor: .bottom)
            }
          }
        }
      }

      Divider()

      HStack(spacing: 10) {
        TextField("问点什么...", text: $viewModel.inputPrompt)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .disabled(viewModel.isLoading)

        Button {
          viewModel.sendMessage(viewModel.inputPrompt, config: configStore.activeConfig)
        } label: {
          if viewModel.isLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle())
              .frame(width: 24, height: 24)
          } else {
            Image(systemName: "paperplane.fill")
              .font(.system(size: 16))
          }
        }
        .disabled(viewModel.isLoading || viewModel.inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(8)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
      }
      .padding(12)
      .background(Color(UIColor.systemBackground))
    }
    .navigationBarTitle("AI SSE 对话", displayMode: .inline)
    .navigationBarItems(trailing: Button {
      viewModel.showingConfigSheet = true
    } label: {
      Image(systemName: "gearshape")
    })
    .sheet(isPresented: $viewModel.showingConfigSheet) {
      LLMConfigView()
    }
    .onDisappear {
      viewModel.onDisappear()
    }
  }

  private func suggestionButton(_ title: String, proxy: ScrollViewProxy) -> some View {
    Button(title) {
      viewModel.inputPrompt = title
      viewModel.sendMessage(title, config: configStore.activeConfig)
    }
    .font(.caption)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.blue.opacity(0.1))
    .foregroundColor(.blue)
    .cornerRadius(14)
  }
}
