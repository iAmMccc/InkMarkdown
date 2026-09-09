//
//  InkThoughtStreamingScanner.swift
//  InkMarkdown
//

import Foundation

extension InkThoughtScanner {

  /// PREFIX Thought 协议的增量扫描器。
  ///
  /// 每个输入 Unicode scalar 只作为新 delta 被检查一次；静态/终态语义继续由
  /// ``InkThoughtScanner/scan(from:)`` 负责。该类型仅供 adapter 的 render session 使用。
  @_spi(InkMarkdown)
  public struct StreamingScanner: Sendable {

    public enum Phase: Equatable, Sendable {
      case prefixUndecided
      case passthrough
      case thought(isComplete: Bool)
    }

    public struct Update: Equatable, Sendable {
      public let phase: Phase
      public let thoughtBodyDelta: String
      public let remainderDelta: String

      fileprivate init(
        phase: Phase,
        thoughtBodyDelta: String = "",
        remainderDelta: String = ""
      ) {
        self.phase = phase
        self.thoughtBodyDelta = thoughtBodyDelta
        self.remainderDelta = remainderDelta
      }
    }

    private enum InternalPhase: Sendable {
      case awaitingPrefix
      case passthrough
      case thought
      case closed
    }

    private enum PrefixStep: Sendable {
      case leadingWhitespace
      case afterOpeningAngle
      case matchingName
      case trailingWhitespace
    }

    private enum CloseStep: Sendable {
      case idle
      case afterOpeningAngle
      case afterSlash
      case matchingName
      case trailingWhitespace
    }

    private enum CloseConsumption {
      case consumed
      case notCandidate
      case reprocess(flushedBody: String)
      case closed
    }

    private enum TagName: String, CaseIterable, Sendable {
      case think
      case thought

      var asciiScalars: [UInt32] {
        rawValue.unicodeScalars.map(\.value)
      }
    }

    private struct DeltaAccumulator {
      var thoughtBody = ""
      var remainder = ""
    }

    private var internalPhase: InternalPhase = .awaitingPrefix
    private var isFinished = false

    private var prefixStep: PrefixStep = .leadingWhitespace
    private var prefixBuffer = ""
    private var prefixCandidates = TagName.allCases
    private var prefixNameOffset = 0
    private var matchedTagName: TagName?

    private var activeCodeSpanLength: Int?
    private var pendingBacktickRunLength = 0
    private var pendingBacktickWasEscaped = false
    private var precedingBackslashCount = 0

    private var closeStep: CloseStep = .idle
    private var closeBuffer = ""
    private var closeNameOffset = 0

    private var hasVisibleThoughtBody = false
    private var pendingThoughtWhitespace = ""

    /// 确定性复杂度证据：累计检查的新输入 UTF-16 code units，不包含内部候选回放。
    public private(set) var debugInputUnitInspectionCount = 0

    public init() {}

    /// 消费一个已经通过 source-limit 的 canonical delta。
    public mutating func append(_ chunk: String) -> Update {
      guard !isFinished, !chunk.isEmpty else { return makeUpdate() }

      var delta = DeltaAccumulator()
      for scalar in chunk.unicodeScalars {
        debugInputUnitInspectionCount += String(scalar).utf16.count
        consume(scalar, into: &delta)
      }
      return makeUpdate(delta)
    }

    /// 结束增量协议，但不猜测缺失标签。
    ///
    /// 未决 PREFIX 按普通正文放行；未闭合 Thought 的局部闭标签候选回写正文。
    public mutating func finish() -> Update {
      guard !isFinished else { return makeUpdate() }
      isFinished = true

      var delta = DeltaAccumulator()
      switch internalPhase {
      case .awaitingPrefix:
        delta.remainder = prefixBuffer
        prefixBuffer = ""
        internalPhase = .passthrough
      case .thought:
        if !closeBuffer.isEmpty {
          emitThoughtBody(closeBuffer, into: &delta)
          resetCloseCandidate()
        }
      case .passthrough, .closed:
        break
      }
      return makeUpdate(delta)
    }

    public mutating func reset() {
      self = StreamingScanner()
    }

    private mutating func consume(
      _ scalar: Unicode.Scalar,
      into delta: inout DeltaAccumulator
    ) {
      switch internalPhase {
      case .awaitingPrefix:
        consumePrefix(scalar, into: &delta)
      case .passthrough, .closed:
        append(scalar, to: &delta.remainder)
      case .thought:
        consumeThought(scalar, into: &delta)
      }
    }

    private mutating func consumePrefix(
      _ scalar: Unicode.Scalar,
      into delta: inout DeltaAccumulator
    ) {
      append(scalar, to: &prefixBuffer)

      switch prefixStep {
      case .leadingWhitespace:
        if Self.isWhitespace(scalar) {
          return
        }
        guard scalar.value == 0x3C else {
          failPrefix(into: &delta)
          return
        }
        prefixStep = .afterOpeningAngle

      case .afterOpeningAngle:
        if Self.isWhitespace(scalar) {
          return
        }
        let value = Self.asciiLowercased(scalar.value)
        prefixCandidates = TagName.allCases.filter {
          $0.asciiScalars.first == value
        }
        guard !prefixCandidates.isEmpty else {
          failPrefix(into: &delta)
          return
        }
        prefixNameOffset = 1
        prefixStep = .matchingName

      case .matchingName:
        let completed = prefixCandidates.filter {
          $0.asciiScalars.count == prefixNameOffset
        }
        if scalar.value == 0x3E, let name = completed.first {
          openThought(named: name)
          return
        }
        if Self.isWhitespace(scalar), let name = completed.first {
          matchedTagName = name
          prefixStep = .trailingWhitespace
          return
        }

        let value = Self.asciiLowercased(scalar.value)
        prefixCandidates = prefixCandidates.filter { candidate in
          let name = candidate.asciiScalars
          return prefixNameOffset < name.count && name[prefixNameOffset] == value
        }
        guard !prefixCandidates.isEmpty else {
          failPrefix(into: &delta)
          return
        }
        prefixNameOffset += 1

      case .trailingWhitespace:
        if Self.isWhitespace(scalar) {
          return
        }
        guard scalar.value == 0x3E, let matchedTagName else {
          failPrefix(into: &delta)
          return
        }
        openThought(named: matchedTagName)
      }
    }

    private mutating func failPrefix(into delta: inout DeltaAccumulator) {
      delta.remainder.append(prefixBuffer)
      prefixBuffer = ""
      internalPhase = .passthrough
    }

    private mutating func openThought(named name: TagName) {
      matchedTagName = name
      prefixBuffer = ""
      internalPhase = .thought
      resetCloseCandidate()
    }

    private mutating func consumeThought(
      _ scalar: Unicode.Scalar,
      into delta: inout DeltaAccumulator
    ) {
      var shouldReprocess = true
      while shouldReprocess {
        shouldReprocess = false

        if pendingBacktickRunLength > 0 {
          if scalar.value == 0x60 {
            pendingBacktickRunLength += 1
            emitThoughtBody(scalar, into: &delta)
            return
          }
          finalizePendingBacktickRun()
          shouldReprocess = true
          continue
        }

        if activeCodeSpanLength != nil {
          if scalar.value == 0x60 {
            pendingBacktickRunLength = 1
            pendingBacktickWasEscaped = false
          }
          emitThoughtBody(scalar, into: &delta)
          return
        }

        switch consumeCloseCandidate(scalar) {
        case .consumed:
          precedingBackslashCount = 0
          return
        case .closed:
          precedingBackslashCount = 0
          internalPhase = .closed
          return
        case .reprocess(let flushedBody):
          emitThoughtBody(flushedBody, into: &delta)
          precedingBackslashCount = 0
          shouldReprocess = true
          continue
        case .notCandidate:
          break
        }

        if scalar.value == 0x60 {
          pendingBacktickRunLength = 1
          pendingBacktickWasEscaped = precedingBackslashCount % 2 != 0
          precedingBackslashCount = 0
          emitThoughtBody(scalar, into: &delta)
          return
        }

        emitThoughtBody(scalar, into: &delta)
        if scalar.value == 0x5C {
          precedingBackslashCount += 1
        } else {
          precedingBackslashCount = 0
        }
      }
    }

    private mutating func finalizePendingBacktickRun() {
      if let activeCodeSpanLength {
        if pendingBacktickRunLength == activeCodeSpanLength {
          self.activeCodeSpanLength = nil
        }
      } else if !pendingBacktickWasEscaped {
        activeCodeSpanLength = pendingBacktickRunLength
      }
      pendingBacktickRunLength = 0
      pendingBacktickWasEscaped = false
    }

    private mutating func consumeCloseCandidate(_ scalar: Unicode.Scalar) -> CloseConsumption {
      guard let matchedTagName else { return .notCandidate }

      switch closeStep {
      case .idle:
        guard scalar.value == 0x3C else { return .notCandidate }
        closeBuffer = "<"
        closeStep = .afterOpeningAngle
        return .consumed

      case .afterOpeningAngle:
        guard scalar.value == 0x2F else { return failCloseCandidate() }
        append(scalar, to: &closeBuffer)
        closeStep = .afterSlash
        return .consumed

      case .afterSlash:
        if Self.isWhitespace(scalar) {
          append(scalar, to: &closeBuffer)
          return .consumed
        }
        let name = matchedTagName.asciiScalars
        guard name.first == Self.asciiLowercased(scalar.value) else {
          return failCloseCandidate()
        }
        append(scalar, to: &closeBuffer)
        closeNameOffset = 1
        closeStep = closeNameOffset == name.count ? .trailingWhitespace : .matchingName
        return .consumed

      case .matchingName:
        let name = matchedTagName.asciiScalars
        guard closeNameOffset < name.count,
              name[closeNameOffset] == Self.asciiLowercased(scalar.value) else {
          return failCloseCandidate()
        }
        append(scalar, to: &closeBuffer)
        closeNameOffset += 1
        if closeNameOffset == name.count {
          closeStep = .trailingWhitespace
        }
        return .consumed

      case .trailingWhitespace:
        if Self.isWhitespace(scalar) {
          append(scalar, to: &closeBuffer)
          return .consumed
        }
        guard scalar.value == 0x3E else { return failCloseCandidate() }
        resetCloseCandidate()
        return .closed
      }
    }

    private mutating func failCloseCandidate() -> CloseConsumption {
      let flushedBody = closeBuffer
      resetCloseCandidate()
      return .reprocess(flushedBody: flushedBody)
    }

    private mutating func resetCloseCandidate() {
      closeStep = .idle
      closeBuffer = ""
      closeNameOffset = 0
    }

    private mutating func emitThoughtBody(
      _ scalar: Unicode.Scalar,
      into delta: inout DeltaAccumulator
    ) {
      if Self.isWhitespace(scalar) {
        if hasVisibleThoughtBody {
          append(scalar, to: &pendingThoughtWhitespace)
        }
        return
      }

      if hasVisibleThoughtBody, !pendingThoughtWhitespace.isEmpty {
        delta.thoughtBody.append(pendingThoughtWhitespace)
        pendingThoughtWhitespace = ""
      }
      hasVisibleThoughtBody = true
      append(scalar, to: &delta.thoughtBody)
    }

    private mutating func emitThoughtBody(
      _ text: String,
      into delta: inout DeltaAccumulator
    ) {
      for scalar in text.unicodeScalars {
        emitThoughtBody(scalar, into: &delta)
      }
    }

    private func makeUpdate(_ delta: DeltaAccumulator = DeltaAccumulator()) -> Update {
      let phase: Phase
      switch internalPhase {
      case .awaitingPrefix:
        phase = .prefixUndecided
      case .passthrough:
        phase = .passthrough
      case .thought:
        phase = .thought(isComplete: false)
      case .closed:
        phase = .thought(isComplete: true)
      }
      return Update(
        phase: phase,
        thoughtBodyDelta: delta.thoughtBody,
        remainderDelta: delta.remainder
      )
    }

    private static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
      CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    private static func asciiLowercased(_ value: UInt32) -> UInt32 {
      (0x41...0x5A).contains(value) ? value + 0x20 : value
    }

    private func append(_ scalar: Unicode.Scalar, to text: inout String) {
      text.unicodeScalars.append(scalar)
    }
  }
}
