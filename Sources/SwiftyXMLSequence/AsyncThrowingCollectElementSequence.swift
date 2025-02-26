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
    public func collect<T: Equatable & Sendable>(
        _ matching: @Sendable @escaping (
            _ element: T,
            _ attributes: Attributes
        ) throws -> Bool
    ) async rethrows -> AsyncThrowingCollecyElementSequence<Self, T>
        where Element == ParsingEvent<T>
    {
        return AsyncThrowingCollecyElementSequence(
            base: self,
            predicate: matching
        )
    }
}

public struct AsyncThrowingCollecyElementSequence<Base, T>: AsyncSequence, Sendable
    where Base: AsyncSequence,
          Base: Sendable,
          Base.Element == ParsingEvent<T>,
          T: Equatable & Sendable
{
    private let base: Base

    internal typealias Predicate = @Sendable (
        _ element: T,
        _ attributes: Attributes
    ) throws -> Bool

    private let predicate: Predicate

    internal init(base: Base, predicate: @escaping Predicate) {
        self.base = base
        self.predicate = predicate
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator(), predicate: predicate)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = ParsingEvent<T>

        private var base: Base.AsyncIterator
        private let predicate: Predicate

        internal init(_ base: Base.AsyncIterator, predicate: @escaping Predicate) {
            self.base = base
            self.predicate = predicate
        }

        private var depth = 0

        public mutating func next() async throws -> Element? {
            var nextEvent = try await base.next()

            if depth == 0 {
                while nextEvent != nil {
                    if case .begin(let element, let attributes) = nextEvent {
                        if try predicate(element, attributes) {
                            depth = 1
                            return nextEvent
                        }
                    }

                    nextEvent = try await base.next()
                }
            } else if let nextEvent {
                switch nextEvent {
                case .begin(_, attributes: _):
                    depth += 1
                case .endElement:
                    depth -= 1
                default:
                    break
                }
            }

            return nextEvent
        }
    }
}
