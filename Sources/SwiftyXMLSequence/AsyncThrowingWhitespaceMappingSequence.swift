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

public enum WhitespacePolicy: Equatable, Sendable {
    case inline
    case block
    case preserve
}

public enum WhitespaceProcessing: Equatable, Sendable {
    case collapse
    case remove
}

public enum WhitespaceParsingEvent<Element>: Equatable, Sendable
    where Element: ElementRepresentable
{
    case event(ParsingEvent<Element>, WhitespacePolicy)
    case whitespace(String, WhitespaceProcessing)
}

extension AsyncSequence {
    public func map<T: ElementRepresentable>(
        whitespace policy: @Sendable @escaping (
            _ element: T,
            _ attributes: Attributes
        ) -> WhitespacePolicy
    ) async rethrows -> AsyncThrowingWhitespaceMappingSequence<Self, T>
        where Element == ParsingEvent<T>
    {
        return AsyncThrowingWhitespaceMappingSequence(base: self, policy)
    }
}

public struct AsyncThrowingWhitespaceMappingSequence<Base, T>: AsyncSequence, Sendable
    where Base: AsyncSequence,
          Base: Sendable,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable
{
    private let base: Base

    internal typealias Policy = @Sendable (
        _ element: T,
        _ attributes: Attributes
    ) -> WhitespacePolicy

    private let policy: Policy

    internal init(base: Base, _ policy: @escaping Policy) {
        self.base = base
        self.policy = policy
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator(), policy)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = WhitespaceParsingEvent<T>

        private var base: Base.AsyncIterator
        private let policy: Policy

        private var prepared: [Element] = []
        private var elementStack: [(T, WhitespacePolicy)] = []

        internal init(_ base: Base.AsyncIterator, _ policy: @escaping Policy) {
            self.base = base
            self.policy = policy
        }

        public mutating func next() async throws -> Element? {
            if prepared.isEmpty {
                prepared = try await prepare()
            }

            let next = try nextPrepared()
            return next
        }

        private mutating func prepare() async throws -> [Element] {
            var prepared: [Element] = []

            var foundTextEvent = false

            while true {
                guard let event = try await base.next() else {
                    return prepareWhitespace(for: prepared)
                }

                var shouldPrepareWhitespace = false

                switch event {
                case .begin(let element, let attributes):
                    let whitespacePolicy = push(element, attributes)
                    prepared.append(.event(event, whitespacePolicy))

                    shouldPrepareWhitespace = whitespacePolicy != .inline

                    break

                case .end(let element):
                    let whitespacePolicy = pop(element)
                    prepared.append(.event(event, whitespacePolicy))

                    shouldPrepareWhitespace = whitespacePolicy != .inline

                    break

                case .text(_):
                    let whitespacePolicy = currentWhitespacePolicy
                    prepared.append(.event(event, whitespacePolicy))

                    foundTextEvent = true

                    break

                default:
                    break
                }

                if foundTextEvent, shouldPrepareWhitespace {
                    return prepareWhitespace(for: prepared)
                }
            }
        }

        private mutating func push(_ element: T, _ attributes: Attributes) -> WhitespacePolicy {
            let whitespacePolicy = policy(element, attributes)
            elementStack.append((element, whitespacePolicy))
            return whitespacePolicy
        }

        private mutating func pop(_ element: T) -> WhitespacePolicy {
            let element = elementStack.removeLast()
            return element.1
        }

        private var currentWhitespacePolicy: WhitespacePolicy {
            guard let element = elementStack.last else {
                return .block
            }

            return element.1
        }

        private func prepareWhitespace(for prepared: [Element]) -> [Element] {
            var newPrepared = mergeAdjacentTextEvents(for: prepared)
            newPrepared = prepareWhitespaceEvents(for: newPrepared)
            return newPrepared
        }

        private func mergeAdjacentTextEvents(for prepared: [Element]) -> [Element] {
            var buffer = String()
            var whitespacePolicy: WhitespacePolicy = .block

            var merged = [Element]()

            for whitespaceEvent in prepared {
                switch whitespaceEvent {
                case .event(let event, let policy):
                    switch event {
                    case .text(let string):
                        buffer.append(string)
                        whitespacePolicy = policy
                        break
                    default:
                        if buffer.isEmpty == false {
                            merged.append(
                                .event(.text(buffer), whitespacePolicy)
                            )
                            buffer.removeAll(keepingCapacity: true)
                        }

                        merged.append(whitespaceEvent)
                        break
                    }
                default:
                    break
                }
            }

            return merged
        }

        private func prepareWhitespaceEvents(for prepared: [Element]) -> [Element] {
            var newPrepared: [Element] = []

            for (index, whitespaceEvent) in prepared.enumerated() {
                switch whitespaceEvent {
                case .event(let event, let policy):
                    switch event {
                    case .text(let string):
                        newPrepared.append(contentsOf:
                            makeWhitespaceCollapsingEvents(
                                for: string,
                                index == 0 ? .block : policy,
                                following: prepared.suffix(from: index).dropFirst()
                            )
                        )
                        break
                    default:
                        newPrepared.append(whitespaceEvent)
                        break
                    }
                    break
                default:
                    break
                }
            }

            return newPrepared
        }

        private mutating func nextPrepared() throws -> Element? {
            if prepared.isEmpty {
                return nil
            }

            return prepared.removeFirst()
        }

        private func makeWhitespaceCollapsingEvents(
            for text: String,
            _ policy: WhitespacePolicy,
            following: [Element].SubSequence
        ) -> [Element] {
            let chunks = text.chunked { first, second in
                first.isWhitespace == second.isWhitespace
            }

            var events: [Element] = []
            var buffer = String()

            for (index, substring) in chunks.enumerated() {
                if substring.first!.isWhitespace {
                    if index == 0, substring.count > 1 {
                        let processing: WhitespaceProcessing =
                            policy == .inline ? .collapse : .remove
                        events.append(.whitespace(String(substring), processing))
                    } else if index + 1 == chunks.count {
                        if buffer.isEmpty == false {
                            events.append(.event(.text(buffer), policy))
                            buffer.removeAll(keepingCapacity: true)
                        }

                        var processing: WhitespaceProcessing = .collapse

                        if whitespacePolicy(for: following) == .block {
                            processing = .remove
                        } else if policy == .inline {
                            if firstLeadingWhitespaceIndex(following) != nil {
                                processing = .remove
                            }
                        } else {
                            processing = .remove
                        }

                        events.append(.whitespace(String(substring), processing))
                    } else if substring.count == 1 {
                        if policy == .block {
                            events.append(.whitespace(String(substring), .remove))
                        } else {
                            buffer.append(String(substring))
                        }
                    } else {
                        if buffer.isEmpty == false {
                            events.append(.event(.text(buffer), policy))
                            buffer.removeAll(keepingCapacity: true)
                        }

                        events.append(.whitespace(String(substring), .collapse))
                    }
                } else {
                    buffer.append(String(substring))
                }
            }

            if buffer.isEmpty == false {
                events.append(.event(.text(buffer), policy))
            }

            return events
        }

        private func whitespacePolicy(
            for following: [Element].SubSequence
        ) -> WhitespacePolicy {
            if let followingEvent = following.first {
                switch followingEvent {
                case .event(_, let policy):
                    return policy
                default:
                    break
                }
            }

            return .block
        }

        private func firstLeadingWhitespaceIndex(_ following: [Element].SubSequence) -> Int? {
            let index = following.firstIndex { whitespaceEvent in
                switch whitespaceEvent {
                case .event(let event, let policy):
                    if policy != .inline {
                        return false
                    }

                    switch event {
                    case .text(let string):
                        guard let first = string.first else {
                            return false
                        }

                        return first.isWhitespace
                    default:
                        break
                    }
                    break
                default:
                    break
                }

                return false
            }

            return index
        }
    }
}

fileprivate func isTextEvent<T>(_ whitespaceEvent: WhitespaceParsingEvent<T>) -> Bool
    where T: ElementRepresentable
{
    switch whitespaceEvent {
    case .event(let event, _):
        switch event {
        case .text(_):
            return true
        default:
            return false
        }
    default:
        return false
    }
}
