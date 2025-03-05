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
        return AsyncThrowingWhitespaceCollapsingSequence(
            base: self
        )
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
        private var previousInlineWhitespace: Base.Element? = nil

        internal init(_ base: Base.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> Element? {
//            while true {
//                guard let event = try await base.next() else {
//                    return nil
//                }
//
//                switch event {
//                case .whitespace(let whitespace, let behavior):
//                    break
//                case .event(let event, let behavior):
//                    return event
//                }
//            }

            // TODO

            return nil
        }
    }
}
