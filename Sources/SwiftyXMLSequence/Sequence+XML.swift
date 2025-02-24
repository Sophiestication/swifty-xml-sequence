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
    public func drop<T: Equatable & Sendable>(
        while predicate: @Sendable @escaping (
            _ element: T,
            _ attributes: [String:String]
        ) async throws -> Bool
    ) async rethrows -> AsyncThrowingDropWhileSequence<Self>
        where Element == XMLParsingEvent<T>
    {
        drop { event in
            if case .begin(let element, let attributes) = event {
                return try await predicate(element, attributes)
            }

            return true
        }
    }
}

extension AsyncSequence {
    public func element<T: Equatable & Sendable>(
        matching predicate: @Sendable @escaping (
            _ element: T,
            _ attributes: [String:String]
        ) throws -> Bool
    ) async throws -> AsyncThrowingMatchElementSequence<Self, T>
        where Element == XMLParsingEvent<T>
    {
        return AsyncThrowingMatchElementSequence(
            base: self,
            predicate: predicate
        )
    }
}

public struct AsyncThrowingMatchElementSequence<Base, T>: AsyncSequence
    where Base: AsyncSequence,
          Base.Element == XMLParsingEvent<T>,
          T: Equatable & Sendable
{
    private let base: Base

    internal typealias Predicate = (
        _ element: T,
        _ attributes: [String:String]
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
        public typealias Element = XMLParsingEvent<T>

        private var base: Base.AsyncIterator
        private let predicate: Predicate

        private var depth: Int = 0

        private enum State { case matching, depth(Int), finished }
        private var state: State = .matching

        internal init(_ base: Base.AsyncIterator, predicate: @escaping Predicate) {
            self.base = base
            self.predicate = predicate
        }

        public mutating func next() async throws -> Element? {
            return switch state {
            case .matching:
                try await nextUntilMatch()
            case .depth(_):
                try await nextUntilMatchedElementEnd()
            case .finished:
                nil
            }
        }

        private mutating func nextUntilMatch() async throws -> Element? {
            while let event = try await base.next() {
                if case .begin(let element, let attributes) = event {
                    if try predicate(element, attributes) {
                        state = .depth(1)
                        return event
                    }
                }
            }

            return nil
        }

        private mutating func nextUntilMatchedElementEnd() async throws -> Element? {
            let event = try await base.next()

            switch event {
            case .begin(_, _):
                increaseDepth()
            case .endElement:
                if decreaseDepth() == 0 {
                    state = .finished
                }
            default:
                break
            }

            return event
        }

        private mutating func increaseDepth() {
            if case .depth(let value) = state {
                state = .depth(value + 1)
            }
        }

        private mutating func decreaseDepth() -> Int {
            if case .depth(let value) = state {
                let newValue = value - 1
                state = .depth(newValue)
                return newValue
            }

            return 0
        }
    }
}
