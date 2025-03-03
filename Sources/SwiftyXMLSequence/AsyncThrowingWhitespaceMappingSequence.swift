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

public enum WhitespaceCollapsingBehavior: Equatable, Sendable {
    case collapse(inline: Bool)
    case preserve
}

public enum WhitespaceParsingEvent<Element>: Equatable, Sendable
    where Element: ElementRepresentable
{
    case event(ParsingEvent<Element>)
    case whitespace(String, WhitespaceCollapsingBehavior)
}

extension AsyncSequence {
    public func map<T: ElementRepresentable>(
        whitespace behavior: @Sendable @escaping (
            _ element: T,
            _ attributes: Attributes
        ) -> WhitespaceCollapsingBehavior
    ) async rethrows -> AsyncThrowingWhitespaceMappingSequence<Self, T>
        where Element == ParsingEvent<T>
    {
        return AsyncThrowingWhitespaceMappingSequence(
            base: self,
            behavior: behavior
        )
    }
}

public struct AsyncThrowingWhitespaceMappingSequence<Base, T>: AsyncSequence, Sendable
    where Base: AsyncSequence,
          Base: Sendable,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable
{
    private let base: Base

    internal typealias Behavior = @Sendable (
        _ element: T,
        _ attributes: Attributes
    ) -> WhitespaceCollapsingBehavior

    private let behavior: Behavior

    internal init(base: Base, behavior: @escaping Behavior) {
        self.base = base
        self.behavior = behavior
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator(), behavior: behavior)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = WhitespaceParsingEvent<T>

        private var base: Base.AsyncIterator
        private let behavior: Behavior

        private var prepared: [Element] = []
        private var behaviorStack: [WhitespaceCollapsingBehavior] = []

        internal init(_ base: Base.AsyncIterator, behavior: @escaping Behavior) {
            self.base = base
            self.behavior = behavior
        }

        public mutating func next() async throws -> Element? {
            if prepared.isEmpty {
                prepared = try await prepare()
            }

            let next = try nextPrepared()
            return next
        }

        private mutating func prepare() async throws -> [Element] {
            var newPrepared: [Element] = []
            var text = String()

            while true {
                if let event = try await base.next() {
                    let hasText = text.isEmpty == false

                    if case .begin(let element, let attributes) = event {
                        if hasText {
                            newPrepared.append(contentsOf:
                                prepare(for: text, behavior: behaviorStack.last)
                            )
                        }

                        newPrepared.append(.event(event))
                        behaviorStack.append(
                            whitespaceBehavior(for: element, attributes)
                        )

                        if hasText {
                            return newPrepared
                        }
                    }

                    if case .end(_) = event {
                        if hasText {
                            newPrepared.append(contentsOf:
                                prepare(for: text, behavior: behaviorStack.last)
                            )
                        }

                        newPrepared.append(.event(event))
                        behaviorStack.removeLast()

                        if hasText {
                            return newPrepared
                        }
                    }

                    if case .text(let string) = event {
                        text += string
                    }
                } else {
                    if text.isEmpty == false {
                        newPrepared.append(contentsOf:
                            prepare(for: text, behavior: behaviorStack.last)
                        )
                    }

                    return newPrepared
                }
            }

            return []
        }

        private func whitespaceBehavior(
            for element: T,
            _ attributes: Attributes
        ) -> WhitespaceCollapsingBehavior {
            self.behavior(element, attributes)
        }

        private func prepare(
            for text:String,
            behavior: WhitespaceCollapsingBehavior?
        ) -> [Element] {
            return switch behavior {
            case .collapse(let inline):
                makeWhitespaceCollapsingEvents(for: text, inline)
            default:
                [.event(.text(text))]
            }
        }

        private func makeWhitespaceCollapsingEvents(
            for text: String,
            _ inline: Bool
        ) -> [Element] {
            let chunks = text.chunked { first, second in
                first.isWhitespace == second.isWhitespace
            }

            var events: [Element] = []
            var buffer = String()

            for (index, substring) in chunks.enumerated() {
                if substring.first!.isWhitespace {
                    if substring.count > 1 || index == 0 || index + 1 == chunks.count {
                        if buffer.isEmpty == false {
                            events.append(.event(.text(buffer)))
                            buffer.removeAll(keepingCapacity: true)
                        }

                        events.append(.whitespace(String(substring), .collapse(inline: inline)))
                    } else {
                        buffer.append(String(substring))
                    }
                } else {
                    buffer.append(String(substring))

                    if index + 1 == chunks.count {
                        events.append(.event(.text(buffer)))
                    }
                }
            }

            return events
        }

        private mutating func nextPrepared() throws -> Element? {
            if prepared.isEmpty {
                return nil
            }

            return prepared.removeFirst()
        }
    }
}
