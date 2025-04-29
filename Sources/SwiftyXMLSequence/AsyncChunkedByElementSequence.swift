//
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
    public func chunked<T: ElementRepresentable, Group>(
        by matchingElement: @Sendable @escaping (
            _ element: T,
            _ attributes: Attributes
        ) throws -> Group?
    ) async rethrows -> AsyncChunkedByElementSequence<Self, T, Group>
        where Element == ParsingEvent<T>
    {
        return AsyncChunkedByElementSequence(
            base: self,
            predicate: matchingElement
        )
    }
}

public struct AsyncChunkedByElementSequence<Base, T, Group>: AsyncSequence & Sendable
    where Base: AsyncSequence & Sendable,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable
{
    private let base: Base

    internal typealias Predicate = @Sendable (
        _ element: T,
        _ attributes: Attributes
    ) throws -> Group?

    private let predicate: Predicate

    internal init(base: Base, predicate: @escaping Predicate) {
        self.base = base
        self.predicate = predicate
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator(), predicate: predicate)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = (Group?, [Base.Element])
        private typealias Event = Base.Element

        private var base: PeekingAsyncIterator<Base.AsyncIterator>
        private let predicate: Predicate

        private var pending: Element? = nil

        internal init(_ base: Base.AsyncIterator, predicate: @escaping Predicate) {
            self.base = PeekingAsyncIterator(base: base)
            self.predicate = predicate
        }

        public mutating func next() async throws -> Element? {
            if let pending {
                self.pending = nil
                return pending
            }

            var chunk: [Event] = []

            while let event = try await base.peek() {
                if case .begin(let element, let attributes) = event {
                    let group = try predicate(element, attributes)

                    if group != nil {
                        let element = try await nextElement()

                        if chunk.isEmpty {
                            return (group, element)
                        } else {
                            pending = (group, element)
                            return (nil, chunk)
                        }
                    }
                }

                _ = try await base.next()
                chunk.append(event)
            }

            if chunk.isEmpty {
                return nil
            }

            return (nil, chunk)
        }

        private mutating func nextElement() async throws -> [Event] {
            var element: [Event] = []
            var depth = 0

            while let event = try await base.next() {
                element.append(event)

                switch event {
                case .begin(_, attributes: _):
                    depth += 1
                case .end(_):
                    depth -= 1

                    if depth <= 0 {
                        return element
                    }
                default:
                    break
                }
            }

            return element
        }
    }
}
