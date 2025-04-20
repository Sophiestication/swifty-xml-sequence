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

public final class AsyncThrowingElementSequence<Base, T>: AsyncSequence
    where Base: AsyncIteratorProtocol,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable
{
    private let base: Base

    internal final class IteratorState: @unchecked Sendable {
        var depth = 1
        var terminated = false
    }
    private let state = IteratorState()

    internal init(base: Base) {
        self.base = base
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base, state)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = ParsingEvent<T>

        private var base: Base

        internal init(_ base: Base, _ state: IteratorState) {
            self.base = base
            self.state = state
        }

        private var state: IteratorState

        public mutating func next() async throws -> Element? {
            guard state.terminated == false else {
                return nil
            }

            let event = try await base.next()

            if let event {
                switch event {
                case .begin(_, attributes: _):
                    state.depth += 1
                case .end(_):
                    state.depth -= 1
                default:
                    break
                }
            }

            if event == nil || state.depth <= 0 { // found end of element
                state.terminated = true
                return nil
            }

            return event
        }
    }
}
