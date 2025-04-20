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
    public func reduce<T: ElementRepresentable, Result: Sendable>(
        _ initialResult: Result,
        _ nextPartialResult: @Sendable @escaping (
            _ partialResult: Result,
            _ element: T,
            _ attributes: Attributes,
            _ sequence: AsyncThrowingElementSequence<Self, T>
        ) throws -> Result
    ) async rethrows -> Result
        where Element == ParsingEvent<T>
    {
        var iterator = self.makeAsyncIterator()
        var result = initialResult

        while let event = try await iterator.next() {
            switch event {
            case .begin(let element, let attributes):
                let sequence = AsyncThrowingElementSequence(base: self)
                result = try nextPartialResult(result, element, attributes, sequence)
                _ = try await sequence.reduce(()) { _, _ in } // consume remaining
            default:
                break
            }
        }

        return result
    }
}
