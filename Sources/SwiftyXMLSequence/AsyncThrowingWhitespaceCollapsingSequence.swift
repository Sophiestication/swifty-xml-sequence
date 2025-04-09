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
import AsyncAlgorithms

public typealias AsyncThrowingWhitespaceCollapsingSequence<
    Base: AsyncSequence,
    T: ElementRepresentable
> = AsyncThrowingFlatMapSequence<
        AsyncChunkedByGroupSequence<
            AsyncCompactMapSequence<Base, ParsingEvent<T>>,
            [AsyncCompactMapSequence<Base, ParsingEvent<T>>.Element]
        >,
        AsyncSyncSequence<[AsyncCompactMapSequence<Base, ParsingEvent<T>>.Element]>
    >

extension AsyncSequence  {
    public func collapse<T: ElementRepresentable>(
    ) async rethrows -> AsyncThrowingWhitespaceCollapsingSequence<Self, T>
        where Element == WhitespaceParsingEvent<T>
    {
        try await compactMap {
            return switch $0 {
            case .event(let event, _):
                event
            case .whitespace(_, let processing):
                if processing == .collapse {
                    .text(" ")
                } else {
                    nil
                }
            }
        }
        .joinAdjacentText()
    }

    public func collapse<T: ElementRepresentable>(
    ) async rethrows -> AsyncThrowingWhitespaceCollapsingSequence<Self, T>
        where Element == LinebreakParsingEvent<T>
    {
        try await compactMap {
            return switch $0 {
            case .event(let event, _):
                event
            case .whitespace(_, let processing):
                if processing == .collapse {
                    .text(" ")
                } else {
                    nil
                }
            case .linebreak:
                .text("\n")
            }
        }
        .joinAdjacentText()
    }
}
