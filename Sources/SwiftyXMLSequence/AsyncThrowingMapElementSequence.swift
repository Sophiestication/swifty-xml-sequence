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

extension AsyncSequence where Self: Sendable {
    public func map<T: ElementRepresentable, Result>(
        _ transform: @Sendable @escaping (
            _ context: [ParsingEventMappingContext<T, Result>],
            _ event: Element
        ) throws -> Result
    ) async rethrows -> AsyncThrowingMapElementSequence<Self, T, Result>
        where Element == ParsingEvent<T>
    {
        return AsyncThrowingMapElementSequence(
            base: self,
            transform: transform
        )
    }
}

public struct ParsingEventMappingContext <
    T, Result
> where T: ElementRepresentable {
    var element: T
    var attributes: Attributes
    var mappedResult: Result
}

public struct AsyncThrowingMapElementSequence<Base, T, Result>: AsyncSequence, Sendable
    where Base: AsyncSequence,
          Base: Sendable,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable
{
    private let base: Base

    internal typealias Transform = @Sendable (
        _ context: [ParsingEventMappingContext<T, Result>],
        _ event: Base.Element
    ) throws -> Result

    private let transform: Transform

    internal init(base: Base, transform: @escaping Transform) {
        self.base = base
        self.transform = transform
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator(), transform: transform)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = Result

        private var base: Base.AsyncIterator
        private let transform: Transform

        internal init(_ base: Base.AsyncIterator, transform: @escaping Transform) {
            self.base = base
            self.transform = transform
        }

        public typealias Context = ParsingEventMappingContext<T, Result>
        private var context: [Context] = []

        public mutating func next() async throws -> Element? {
            guard let event = try await base.next() else {
                return nil
            }

            let result = try transform(context, event)

            switch event {
            case .begin(let element, let attributes):
                context.append(
                    Context(element: element, attributes: attributes, mappedResult: result)
                )
                break

            case .end(_):
                _ = context.popLast()
                break

            default:
                break
            }

            return result
        }
    }
}
