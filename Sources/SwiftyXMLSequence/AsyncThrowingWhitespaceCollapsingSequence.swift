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

extension AsyncSequence {
    public func collapse<T: ElementRepresentable>(
    ) async rethrows -> AsyncThrowingWhitespaceCollapsingSequence<Self, T>
        where Element == WhitespaceParsingEvent<T>
    {
        AsyncThrowingWhitespaceCollapsingSequence(base: self)
    }

    public func collapseWhitespace<T: ElementRepresentable & WhitespaceCollapsing>(
    ) async rethrows ->
        AsyncThrowingWhitespaceCollapsingSequence<
            AsyncThrowingWhitespaceMappingSequence<Self, T>, T
        >
        where Element == ParsingEvent<T>
    {
        try await self.map(whitespace: { element, attributes in
            element.whitespacePolicy
        })
        .collapse()
    }
}

public struct AsyncThrowingWhitespaceCollapsingSequence<Base, T>: AsyncSequence, Sendable
    where Base: AsyncSequence,
          Base: Sendable,
          Base.Element == WhitespaceParsingEvent<T>,
          T: ElementRepresentable
{
    private let base: Base

    internal init(base: Base) {
        self.base = base
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = ParsingEvent<T>

        private var base: Base.AsyncIterator
        private var pending: Element? = nil

        internal init(_ base: Base.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> Element? {
            if let pending {
                self.pending = nil
                return pending
            }

            var textEvent: Element? = nil

            while true {
                guard let whitespaceEvent = try await base.next() else {
                    return textEvent
                }

                switch whitespaceEvent {
                case .whitespace(_, let processing):
                    if processing == .collapse {
                        textEvent = appending(" ", to: textEvent)
                    }
                    break
                case .event(let event, _):
                    switch event {
                    case .text(let string):
                        textEvent = appending(string, to: textEvent)
                        break
                    default:
                        if textEvent == nil {
                            return event
                        } else {
                            pending = event
                            return textEvent
                        }
                    }
                    break
                }
            }

            return textEvent
        }

        private func appending(_ string: String, to textEvent: Element?) -> Element? {
            guard let textEvent else {
                return .text(string)
            }

            return .text(text(from: textEvent) + string)
        }

        private func text(from event: Element) -> String {
            return switch event {
            case .text(let string):
                string
            default:
                String()
            }
        }
    }
}
