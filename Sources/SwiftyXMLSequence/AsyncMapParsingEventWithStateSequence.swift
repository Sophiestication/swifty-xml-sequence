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
    public func map<T: ElementRepresentable, State: Sendable, Result>(
        with initialState: State,
        _ transform: @Sendable @escaping (
            _ state: inout State,
            _ event: Element
        ) throws -> Result
    ) async rethrows -> AsyncMapParsingEventWithStateSequence<Self, T, State, Result>
        where Element == ParsingEvent<T>
    {
        return AsyncMapParsingEventWithStateSequence(
            base: self,
            state: initialState,
            transform: transform
        )
    }
}
public struct AsyncMapParsingEventWithStateSequence<
    Base, T, State, Result
>: AsyncSequence, Sendable
    where Base: AsyncSequence & Sendable,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable,
          State: Sendable
{
    private let base: Base

    internal typealias Transform = @Sendable (
        _ state: inout State,
        _ event: Base.Element
    ) throws -> Result

    private let transform: Transform
    private var state: State

    internal init(base: Base, state: State, transform: @escaping Transform) {
        self.base = base
        self.state = state
        self.transform = transform
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator(), state: state, transform: transform)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = Result

        private var base: Base.AsyncIterator
        private let transform: Transform

        internal init(_ base: Base.AsyncIterator, state: State, transform: @escaping Transform) {
            self.base = base
            self.state = state
            self.transform = transform
        }

        private var state: State

        public mutating func next() async throws -> Element? {
            guard let event = try await base.next() else {
                return nil
            }

            return try transform(&state, event)
        }
    }
}
