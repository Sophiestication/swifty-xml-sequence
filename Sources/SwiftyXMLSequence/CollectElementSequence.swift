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

extension Sequence {
    public func collect<T: ElementRepresentable>(
        _ matching: @escaping (
            _ element: T,
            _ attributes: Attributes
        ) -> Bool
    ) -> CollectElementSequence<Self, T>
        where Element == ParsingEvent<T>
    {
        return CollectElementSequence(
            base: self,
            predicate: matching
        )
    }
}

public struct CollectElementSequence<Base, T>: Sequence
    where Base: Sequence,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable
{
    private let base: Base

    internal typealias Predicate = (
        _ element: T,
        _ attributes: Attributes
    ) -> Bool

    private let predicate: Predicate

    internal init(base: Base, predicate: @escaping Predicate) {
        self.base = base
        self.predicate = predicate
    }

    public func makeIterator() -> Iterator {
        return Iterator(base.makeIterator(), predicate: predicate)
    }

    public struct Iterator: IteratorProtocol {
        public typealias Element = ParsingEvent<T>

        private var base: Base.Iterator
        private let predicate: Predicate

        internal init(_ base: Base.Iterator, predicate: @escaping Predicate) {
            self.base = base
            self.predicate = predicate
        }

        private var depth = 0

        public mutating func next() -> Element? {
            var nextEvent = base.next()

            if depth == 0 {
                while nextEvent != nil {
                    if case .begin(let element, let attributes) = nextEvent {
                        if predicate(element, attributes) {
                            depth = 1
                            return nextEvent
                        }
                    }

                    nextEvent = base.next()
                }
            } else if let nextEvent {
                switch nextEvent {
                case .begin(_, attributes: _):
                    depth += 1
                case .end(_):
                    depth -= 1
                default:
                    break
                }
            }

            return nextEvent
        }
    }
}
