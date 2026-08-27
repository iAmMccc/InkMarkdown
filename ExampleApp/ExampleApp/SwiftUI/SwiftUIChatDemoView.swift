//
//  SwiftUIChatDemoView.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI
import InkMarkdown
import InkMarkdownSwiftUI

private struct ScrollBottomMaxYKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ScrollViewportHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// SwiftUI 架构下的 AI SSE 流式对话问答页面（MVVM：逻辑在 `ChatDemoViewModel`）。
struct SwiftUIChatDemoView: View {

  @StateObject private var viewModel = ChatDemoViewModel()
  @ObservedObject private var configStore = LLMConfigurationStore.shared
  @Environment(\.colorScheme) private var colorScheme
  @State private var bottomMaxY: CGFloat = 0
  @State private var viewportHeight: CGFloat = 0

  private var distanceFromBottom: CGFloat {
    max(0, bottomMaxY - viewportHeight)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        // 服务与端点标识
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

            Section {
              Button {
                viewModel.showingConfigSheet = true
              } label: {
                Label("输入其他自定义模型...", systemImage: "pencil")
              }
            }
          } label: {
            HStack(spacing: 3) {
              Text(configStore.activeConfig.model)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
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
                  suggestionButton("深度思考", proxy: proxy)
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
                    if let renderSession = msg.renderSession {
                      InkStreamMarkdownView(session: renderSession)
                    } else if msg.isStreaming {
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

            Color.clear
              .frame(height: 1)
              .id("chatBottomAnchor")
              .background(
                GeometryReader { proxy in
                  Color.clear.preference(
                    key: ScrollBottomMaxYKey.self,
                    value: proxy.frame(in: .named("chatScroll")).maxY
                  )
                }
              )
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 16)
        }
        .coordinateSpace(name: "chatScroll")
        .background(
          GeometryReader { proxy in
            Color.clear.preference(key: ScrollViewportHeightKey.self, value: proxy.size.height)
          }
        )
        .onPreferenceChange(ScrollBottomMaxYKey.self) { bottomMaxY = $0 }
        .onPreferenceChange(ScrollViewportHeightKey.self) { viewportHeight = $0 }
        .onChange(of: bottomMaxY) { _ in
          viewModel.handleScrollOffsetChanged(
            distanceFromBottom: distanceFromBottom,
            isDragging: false
          )
        }
        .simultaneousGesture(
          DragGesture(minimumDistance: 10)
            .onChanged { _ in
              viewModel.handleScrollDragBegan()
              viewModel.handleScrollOffsetChanged(
                distanceFromBottom: distanceFromBottom,
                isDragging: true
              )
            }
            .onEnded { _ in
              viewModel.handleScrollDragEnded(
                distanceFromBottom: distanceFromBottom,
                isDecelerating: false
              )
            }
        )
        .onReceive(viewModel.streamDisplayPulse) { _ in
          if viewModel.shouldAutoScroll() {
            proxy.scrollTo("chatBottomAnchor", anchor: .bottom)
          }
        }
        .onChange(of: viewModel.messages.count) { _ in
          if viewModel.shouldAutoScroll() {
            withAnimation {
              proxy.scrollTo("chatBottomAnchor", anchor: .bottom)
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
    .onChange(of: colorScheme) { _ in
      viewModel.updateUserInterfaceStyle(colorScheme == .dark ? .dark : .light)
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
