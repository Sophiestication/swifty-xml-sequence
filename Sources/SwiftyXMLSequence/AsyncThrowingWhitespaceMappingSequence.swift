// MIT License
//
// Copyright (c) 2025 Sophiestication Software, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import Algorithms
import AsyncAlgorithms

extension AsyncSequence where Self: Sendable {
    public func map<T: ElementRepresentable>(
        whitespace policy: @Sendable @escaping (
            _ element: T,
            _ attributes: Attributes
        ) -> WhitespacePolicy
    ) async rethrows -> AsyncThrowingWhitespaceMappingSequence<Self, T>
        where Element == ParsingEvent<T>
    {
        return try await AsyncThrowingWhitespaceMappingSequence(base: self, policy: policy)
    }
}

public struct AsyncThrowingWhitespaceMappingSequence<Base, T>: AsyncSequence, Sendable
    where Base: AsyncSequence,
          Base: Sendable,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable
{
    fileprivate typealias PrivateBase = AsyncThrowingMapElementSequence<
            AsyncThrowingFlatMapSequence<
                AsyncChunkedByGroupSequence<Base, [Base.Element]
            >, AsyncSyncSequence<[Base.Element]>
        >, T, WhitespaceParsingEvent<T>
    > // ☠️
    private var base: PrivateBase

    internal typealias Policy = @Sendable (
        _ element: T,
        _ attributes: Attributes
    ) -> WhitespacePolicy

    internal init(base: Base, policy: @escaping Policy) async throws {
        self.base = try await base
            .joinAdjacentText()
            .map { (context, event) -> WhitespaceParsingEvent<T> in
                return switch event {
                case .begin(let element, let attributes):
                    .event(event, policy(element, attributes))
                default:
                    .event(event, Self.policy(for: context))
                }
            }
    }

    public typealias Element = WhitespaceParsingEvent<T>

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = WhitespaceParsingEvent<T>

        private var base: PrivateBase.AsyncIterator
        private var prepared: [Element] = []

        private typealias WhitespaceSegment = WhitespaceSegmentSequence.Element
        private var pending: Pending? = nil

        private struct CollectedText: CustomDebugStringConvertible {
            var preceding: [Element]
            var policy: WhitespacePolicy
            var segments: [WhitespaceSegment]

            var debugDescription: String {
                let formatter = ParsingEventDebugFormatter()
                return "\(formatter.format(preceding)) \(segments)"
            }

            var hasOnlyWhitespace: Bool {
                if segments.isEmpty {
                    return false
                }

                return segments.contains {
                    return switch $0 {
                    case .text(_):
                        false
                    default:
                        true
                    }
                } == false
            }

            var breaksText: Bool {
                beginTextBreak || endTextBreak
            }

            var beginTextBreak: Bool {
                return preceding.contains {
                    return switch $0 {
                    case .event(let element, let policy):
                        if policy == .block, case .begin(_, _) = element {
                            true
                        } else {
                            false
                        }
                    default:
                        false
                    }
                }
            }

            var endTextBreak: Bool {
                return preceding.contains {
                    return switch $0 {
                    case .event(let element, let policy):
                        if policy == .block, case .end(_) = element {
                            true
                        } else {
                            false
                        }
                    default:
                        false
                    }
                }
            }

            var hasText: Bool {
                return segments.contains {
                    return switch $0 {
                    case .text(_):
                        true
                    default:
                        false
                    }
                }
            }
        }

        private struct Pending {
            var segment: WhitespaceSegment
            var policy: WhitespacePolicy
            var preparedInlineText: Bool = false
        }

        fileprivate init(_ base: PrivateBase.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> Element? {
            while true {
                if try await prepare() == false {
                    break
                }

                if prepared.isEmpty == false || pending == nil {
                    break
                }
            }

            if prepared.isEmpty {
                return nil
            }

            return prepared.removeFirst()
        }

        private mutating func prepare() async throws -> Bool {
            let collected = try await collect()

            if collected.isEmpty, pending == nil {
                return false
            }

            prepare(collected)

            return true
        }

        private mutating func prepare(_ collected: [CollectedText]) {
            var events: [Element] = []

            var pendingWhitespace: Substring? = nil
            var pendingWhitespaceProcessing: WhitespaceProcessing = .remove
            var preparedPendingWhitespace = false

            var preparedInlineText = false

            if let pending {
                preparedInlineText = pending.preparedInlineText

                switch pending.segment {
                case .text(let text):
                    preparedInlineText = true
                    events.append(.event(.text(String(text)), pending.policy))

                    self.pending = nil

                    break

                case .whitespace(let whitespace, _):
                    pendingWhitespace = whitespace
                    break
                }
            }

            for (currentIndex, current) in collected.enumerated() {
                let breaksText = current.breaksText

                events += current.preceding

                for (segmentIndex, segment) in current.segments.enumerated() {
                    if pending == nil,
                       currentIndex + 1 == collected.endIndex,
                       segmentIndex + 1 == current.segments.endIndex
                    {
                        pending = Pending(
                            segment: segment,
                            policy: current.policy,
                            preparedInlineText: preparedInlineText
                        )

                        break
                    }

                    switch segment {
                    case .text(let text):
                        if preparedInlineText, preparedPendingWhitespace == false {
                            if breaksText == false {
                                pendingWhitespaceProcessing = .collapse
                            }

                            preparedPendingWhitespace = true
                        }

                        let textEvent: Element = .event(.text(String(text)), current.policy)
                        events.append(textEvent)

                        preparedInlineText = true

                        break

                    case .whitespace(let whitespace, let location):
                        var processing: WhitespaceProcessing = .remove

                        if location == .between {
                            processing = .collapse
                        }

                        if breaksText == false,
                           preparedInlineText == true,
                           pendingWhitespace == nil
                        {
                            processing = .collapse
                        }

                        let whitespaceEvent: Element = .whitespace(String(whitespace), processing)
                        events.append(whitespaceEvent)

                        break
                    }
                }
            }

            if let pendingWhitespace {
                let whitespaceEvent: Element = .whitespace(
                    String(pendingWhitespace),
                    pendingWhitespaceProcessing
                )
                events.insert(whitespaceEvent, at: 0)

//                pending = nil
            }

            yield(events)
        }

        private mutating func collect() async throws -> [CollectedText] {
            var collected: [CollectedText] = []
            var events: [Element] = []

            var foundTextCount: Int = 0

            while let whitespaceEvent = try await base.next() {
                switch whitespaceEvent {
                case .event(let event, let policy):
                    switch event {
                    case .text(let text):
                        let collectedText = CollectedText(
                            preceding: events,
                            policy: policy,
                            segments: whitespaceSegments(for: text, policy)
                        )
                        collected.append(collectedText)

                        if collectedText.hasText {
                            foundTextCount += 1
                        }

                        events.removeAll(keepingCapacity: true)

                    default:
                        events.append(whitespaceEvent)
                    }
                    break

                default:
                    events.append(whitespaceEvent)
                    break
                }

                if foundTextCount >= 1 {
                    break
                }
            }

            if events.isEmpty == false {
                let collectedText = CollectedText(
                    preceding: events,
                    policy: .preserve,
                    segments: []
                )
                collected.append(collectedText)
            }

            return collected
        }

        private func whitespaceSegments(
            for text: String,
            _ policy: WhitespacePolicy
        ) -> [WhitespaceSegment] {
            if policy == .preserve {
                return [.text(text[...])]
            }

            return [WhitespaceSegment](text.whitespaceSegments)
        }

        private func isTextSegment(_ segment: WhitespaceSegment) -> Bool {
            switch segment {
            case .text(_):
                true
            default:
                false
            }
        }

        private func has<S: Sequence>(
            _ sequence: S,
            only whitespacePolicy: WhitespacePolicy
        ) -> Bool
            where S.Element == CollectedText
        {
            has(sequence.flatMap { $0.preceding }, only: whitespacePolicy)
        }

        private func has<S: Sequence>(
            _ sequence: S?,
            only whitespacePolicy: WhitespacePolicy
        ) -> Bool
            where S.Element == WhitespaceParsingEvent<T>
        {
            guard let sequence else {
                return false
            }

            var foundElement = false

            return sequence.first { whitespaceEvent in
                foundElement = true

                return switch whitespaceEvent {
                case .event(_, let policy):
                    policy != whitespacePolicy
                default:
                    false
                }
            } == nil && foundElement
        }

        private mutating func yield(_ event: Element) {
            prepared.append(event)
        }

        private mutating func yield(_ events: [Element]) {
            prepared.append(contentsOf: events)
        }
    }

    private static func policy(
        for context: [ParsingEventMappingContext<T, Element>]
    ) -> WhitespacePolicy {
        if let last = context.last {
            switch last.mappedResult {
            case .event(_, let policy):
                return policy
            default:
                break
            }
        }

        return .block
    }
}
