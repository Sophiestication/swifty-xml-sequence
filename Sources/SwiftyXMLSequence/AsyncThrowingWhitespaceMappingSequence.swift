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
import Algorithms
import AsyncAlgorithms

extension AsyncSequence {
    public func map<T: ElementRepresentable>(
        whitespace policy: @Sendable @escaping (
            _ element: T,
            _ attributes: Attributes
        ) -> WhitespacePolicy
    ) async rethrows -> AsyncThrowingWhitespaceMappingSequence<Self, T>
        where Element == ParsingEvent<T>
    {
        return try await AsyncThrowingWhitespaceMappingSequence(base: self, policy: policy)
    }
}

public struct AsyncThrowingWhitespaceMappingSequence<Base, T>: AsyncSequence
    where Base: AsyncSequence,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable
{
    fileprivate typealias PrivateBase = AsyncFlatMapSequence<
        AsyncThrowingMapWithContextElementSequence<
            AsyncThrowingFlatMapSequence<
                AsyncChunkedByGroupSequence<
                    Base, [Base.Element]
                >, AsyncSyncSequence<[Base.Element]>
            >, T, AsyncThrowingWhitespaceMappingSequence<Base, T>.Element
        >, AsyncSyncSequence<[AsyncThrowingWhitespaceMappingSequence<Base, T>.Element]>
    > // ☠️
    private var base: PrivateBase

    internal typealias Policy = @Sendable (
        _ element: T,
        _ attributes: Attributes
    ) -> WhitespacePolicy

    internal init(base: Base, policy: @escaping Policy) async throws {
        self.base = try await base
            .joinAdjacentText()
            .mapWithContext { (context, event) -> Element in
                return switch event {
                case .begin(let element, let attributes):
                    .event(event, policy(element, attributes))
                default:
                    .event(event, Self.policy(for: context))
                }
            }
            .flatMap({ whitespaceEvent in
                switch whitespaceEvent {
                case .event(let event, let policy):
                    if policy != .preserve {
                        switch event {
                        case .text(let string):
                            return Self.segments(for: string, policy).async
                        default:
                            break
                        }
                    }
                default:
                    break
                }

                return [whitespaceEvent].async
            })
    }

    public typealias Element = WhitespaceParsingEvent<T>

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = WhitespaceParsingEvent<T>

        private var base: PrivateBase.AsyncIterator

        private var preparedInlineText: Bool = false
        private var pendingWhitespace: Element? = nil
        private var prepared: [Element] = []

        fileprivate init(_ base: PrivateBase.AsyncIterator) {
            self.base = base
        }

        public mutating func next() async throws -> Element? {
            if prepared.isEmpty == false {
                return prepared.removeFirst()
            }

            var preparing = true

            while preparing {
                let whitespaceEvent = try await base.next()

                switch whitespaceEvent {
                case .event(let event, let policy):
                    switch event {
                    case .begin(_, _), .end(_):
                        if policy == .block {
                            preparedInlineText = false
                            yield(pending: .remove)
                        }

                        yield(whitespaceEvent)
                        break

                    case .text(_):
                        yield(pending: .collapse)

                        preparedInlineText = true
                        yield(whitespaceEvent)
                        break

                    default:
                        yield(whitespaceEvent)
                        break
                    }
                    break

                case .whitespace(_, _):
                    if preparedInlineText == true,
                       pendingWhitespace == nil {
                        pendingWhitespace = whitespaceEvent
                    } else {
                        yield(whitespaceEvent)
                    }
                    break

                case .none:
                    yield(pending: .remove)
                    break
                }

                if pendingWhitespace == nil {
                    preparing = false
                }
            }

            if prepared.isEmpty == false {
                return prepared.removeFirst()
            }

            return nil
        }

        private mutating func yield(_ whitespaceEvent: Element?) {
            if let whitespaceEvent {
                prepared.append(whitespaceEvent)
            }
        }

        private mutating func yield(
            pending processing: WhitespaceProcessing
        ) {
            guard let pendingWhitespace else {
                return
            }

            switch pendingWhitespace {
            case .whitespace(let whitespace, _):
                prepared.insert(.whitespace(whitespace, processing), at: 0)
            default:
                break
            }

            self.pendingWhitespace = nil
        }
    }

    private static func policy(
        for context: [ParsingEventMappingContext<T, Element>]
    ) -> WhitespacePolicy {
        if let last = context.last {
            switch last.mappedResult {
            case .event(_, let policy):
                return policy
            default:
                break
            }
        }

        return .block
    }

    private static func segments(
        for string: String,
        _ policy: WhitespacePolicy
    ) -> [Element] {
        string
            .whitespaceSegments
            .map { segment -> Element in
                return switch segment {
                case .text(let substring):
                    .event(.text(String(substring)), policy)
                case .whitespace(let whitespace, _):
                    .whitespace(String(whitespace), .remove)
                }
            }
    }
}
