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

        private struct CollectedText {
            var preceding: [Element]
            var policy: WhitespacePolicy
            var segments: [WhitespaceSegment]

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

        fileprivate init(_ base: PrivateBase.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> Element? {
            if prepared.isEmpty {
                try await prepare()

                let formatter = ParsingEventDebugFormatter()
                print(": \(formatter.format(prepared))")
            }

            if prepared.isEmpty {
                return nil
            }

            return prepared.removeFirst()
        }

        private mutating func prepare() async throws {
            var collected = try await collect()

            if collected.isEmpty == false {
                collected += try await collect()
            }

            if collected.isEmpty {
                return
            }

            prepare(collected)
        }

        private mutating func prepare(
            _ collected: [CollectedText]
        ) {
            var foundCollapsableWhitespaceAtEnd = false
            var lastTextOrBeginIndex: Int = 0

            for (currentIndex, current)in collected.enumerated() {
                yield(current.preceding)

                for (segmentIndex, segment) in current.segments.enumerated() {
                    let isAtStart = segmentIndex == current.segments.startIndex
                    let isAtEnd = segmentIndex + 1 == current.segments.endIndex

                    switch segment {
                    case .text(let text):
                        yield(.event(.text(String(text)), current.policy))
                        lastTextOrBeginIndex = currentIndex
                        break

                    case .whitespace(let whitespace, _):
                        var processing: WhitespaceProcessing = .remove
                        let next = collected.suffix(from: currentIndex + 1)

                        if isAtEnd,
                           foundCollapsableWhitespaceAtEnd == false,
                           current.hasText,
                           has(next, only: .inline)
                        {
                            foundCollapsableWhitespaceAtEnd = true
                            processing = .collapse
                        } else if isAtStart,
                                  isAtEnd,
                                  foundCollapsableWhitespaceAtEnd == false
                        {
                            let afterLastText = collected
                                .suffix(from: lastTextOrBeginIndex + 1)
                                .prefix(upTo: currentIndex + 1)

                            if has(afterLastText, only: .inline) {
                                processing = .collapse
                            }
                        } else if isAtStart == false,
                                  isAtEnd == false,
                                  foundCollapsableWhitespaceAtEnd == false
                        {
                            processing = .collapse
                        } else if foundCollapsableWhitespaceAtEnd == false,
                                  isAtStart,
                                  isAtEnd == false
                        {
                            let afterLastText = collected
                                .suffix(from: lastTextOrBeginIndex + 1)
                                .prefix(upTo: currentIndex + 1)

                            if has(afterLastText, only: .inline) {
                                processing = .collapse
                            }
                        }

                        yield(.whitespace(String(whitespace), processing))

                        break
                    }
                }
            }
        }

        private mutating func collect() async throws -> [CollectedText] {
            var collected: [CollectedText] = []
            var events: [Element] = []

            var foundText = false

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

                        foundText = collectedText.hasText
                        events.removeAll(keepingCapacity: true)

                    default:
                        events.append(whitespaceEvent)
                    }
                    break

                default:
                    events.append(whitespaceEvent)
                    break
                }

                if foundText {
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
                return [.text(text[...])] // TODO
            }

            return [WhitespaceSegment](text.whitespaceSegments)
        }

        private func hasText(_ collected: CollectedText?) -> Bool {
            guard let collected else {
                return false
            }

            return collected.segments.contains {
                return switch $0 {
                case .text(_):
                    true
                default:
                    false
                }
            }
        }

        private func startsWithText(_ collected: CollectedText?) -> Bool {
            guard let collected else {
                return false
            }

            guard let first = collected.segments.first else {
                return false
            }

            return switch first {
            case .text(_):
                true
            default:
                false
            }
        }

        private func endsWithText(_ collected: CollectedText?) -> Bool {
            guard let collected else {
                return false
            }

            guard let last = collected.segments.last else {
                return false
            }

            return switch last {
            case .text(_):
                true
            default:
                false
            }
        }

        private func isBeginEvent(_ event: Element?) -> Bool {
            guard let event else {
                return false
            }

            switch event {
            case .event(let event, _):
                switch event {
                case .begin(_, _),
                     .beginDocument:
                    return true
                default:
                    break
                }
            default:
                break
            }

            return false
        }

        private func isEndEvent(_ event: Element?) -> Bool {
            guard let event else {
                return false
            }

            switch event {
            case .event(let event, _):
                switch event {
                case .end(_):
                    return true
                default:
                    break
                }
            default:
                break
            }

            return false
        }

        private func hasLeadingWhitespace<S: Sequence>(
            _ sequence: S
        ) -> Bool
            where S.Element == CollectedText
        {
            sequence.contains {
                $0.segments.prefix(1).contains {
                    return switch $0 {
                    case .whitespace(_, _):
                        true
                    default:
                        false
                    }
                }
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

        private func first<S: Sequence>(
            matching whitespacePolicy: WhitespacePolicy,
            in sequence: S?
        ) -> Element?
            where S.Element == WhitespaceParsingEvent<T>
        {
            guard let sequence else {
                return nil
            }

            return sequence.first {
                return switch $0 {
                case .event(_, let policy):
                    whitespacePolicy == policy
                default:
                    false
                }
            }
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
