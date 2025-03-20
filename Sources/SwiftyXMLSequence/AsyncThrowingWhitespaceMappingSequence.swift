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

        private var previous: [Element] = []
        private var next: [Element]? = nil

        private var elementStack: [(T, WhitespacePolicy)] = []

        internal init(_ base: Base.AsyncIterator, _ policy: @escaping Policy) {
            self.base = base
            self.policy = policy
        }

        public mutating func next() async throws -> Element? {
            if prepared.isEmpty {
                if next == nil {
                    next = try await collect()
                }

                let events = next!

                let collected = try await collect()
                next = collected

                prepared = prepare(events, previous: previous, next: collected)
                previous = prepared
            }

            if prepared.isEmpty {
                return nil
            }

            return prepared.removeFirst()
        }

        private mutating func collect() async throws -> [Element] {
            var collected: [Element] = []

            var text = String()
            var textWhitespacePolicy: WhitespacePolicy = .block

            while true {
                guard let event = try await base.next() else {
                    return collected
                }

                switch event {
                case .begin(let element, let attributes):
                    let whitespacePolicy = push(element, attributes)

                    if text.isEmpty == false {
                        collected += events(for: text, textWhitespacePolicy)
                        collected.append(.event(event, whitespacePolicy))

                        if whitespacePolicy != .inline {
                            return collected
                        }

                        text.removeAll(keepingCapacity: true)
                    } else {
                        collected.append(.event(event, whitespacePolicy))
                    }

                    break

                case .end(let element):
                    let whitespacePolicy = pop(element)

                    if text.isEmpty == false {
                        collected += events(for: text, textWhitespacePolicy)
                        collected.append(.event(event, whitespacePolicy))

                        if whitespacePolicy != .inline {
                            return collected
                        }

                        text.removeAll(keepingCapacity: true)
                    } else {
                        collected.append(.event(event, whitespacePolicy))
                    }

                    break

                case .text(let string):
                    textWhitespacePolicy = currentWhitespacePolicy
                    text += string

                    break

                default:
                    break
                }
            }
        }

        private func prepare(
            _ events: [Element],
            previous: [Element],
            next: [Element]
        ) -> [Element] {
            let all = previous + events + next
            var prepared = events

            let filteredIndices = all.indices.filter { index in
                let event = all[index]

                if isTextEvent(event) {
                    return true
                }

                if let policy = policy(for: event) {
                    return policy != .inline
                }

                return true
            }

            for (filteredIndex, eventIndex) in filteredIndices.enumerated() {
                if eventIndex < previous.count || eventIndex >= (previous.count + events.count) {
                    continue
                }

                let event = all[eventIndex]

                if isWhitespaceEvent(event) == false {
                    continue
                }

                var previousEvent: Element? = nil
                let previousFilteredIndex = filteredIndices.index(before: filteredIndex)

                if previousFilteredIndex >= 0 {
                    previousEvent = all[filteredIndices[previousFilteredIndex]]
                }

                var previousIsBlock = false
                var previousIsWhitespace = false
                var previousIsText = false

                if let previousEvent {
                    previousIsWhitespace = isWhitespaceEvent(previousEvent)
                    previousIsBlock = policy(for: previousEvent) != .inline
                    previousIsText = isTextEvent(previousEvent)
                }

                var followingEvent: Element? = nil
                let followingFilteredIndex = filteredIndices.index(after: filteredIndex)

                if followingFilteredIndex < filteredIndices.count {
                    followingEvent = all[filteredIndices[followingFilteredIndex]]
                }

                var followingIsBlock = false
                var followingIsWhitespace = false
                var followingIsText = false

                if let followingEvent {
                    followingIsWhitespace = isWhitespaceEvent(followingEvent)
                    followingIsBlock = policy(for: followingEvent) != .inline
                    followingIsText = isTextEvent(followingEvent)
                }

                var newProcessing: WhitespaceProcessing? = nil

                if previousIsText, followingIsText {
                    // newProcessing = .collapse
                } else if previousIsBlock, followingIsBlock {
                    newProcessing = .remove
                } else if (previousIsText || previousIsWhitespace), followingIsText {
                    // newProcessing = .collapse
                } else if (previousIsText || previousIsWhitespace), followingIsWhitespace {
                    newProcessing = .remove
                } else if previousIsText, followingIsBlock {
                    newProcessing = .remove
                } else if previousIsText == false,
                   previousIsBlock || followingIsText || followingIsWhitespace {
                    newProcessing = .remove
                }

                if let newProcessing {
                    let preparedIndex = eventIndex - previous.count

                    let newEvent: Element = .whitespace(
                        whitespace(from: event),
                        newProcessing
                    )
                    prepared[preparedIndex] = newEvent
                }
            }

            return prepared
        }

        private func policy(for event: Element?) -> WhitespacePolicy? {
            guard let event else {
                return nil
            }

            return switch event {
            case .event(_, let policy):
                policy
            default:
                nil
            }
        }

        private func isTextEvent(_ whitespaceEvent: Element?) -> Bool {
            guard let whitespaceEvent else {
                return false
            }

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

        private func isWhitespaceEvent(_ event: Element) -> Bool {
            return switch event {
            case .whitespace(_, _):
                true
            default:
                false
            }
        }

        private func whitespace(from whitespaceEvent: Element) -> String {
            return switch whitespaceEvent {
            case .whitespace(let string, _):
                string
            default:
                String()
            }
        }

        private func events(
            for text: String,
            _ whitespacePolicy: WhitespacePolicy
        ) -> [Element] {
            if whitespacePolicy == .preserve {
                return [.event(.text(text), whitespacePolicy)]
            }

            var events = [Element]()

            let chunks = text.chunked { first, second in
                first.isWhitespace == second.isWhitespace
            }

            var buffer = String()

            for (index, substring) in chunks.enumerated() {
                let isLeadingOrTrailing = index == 0 || index + 1 == chunks.count
                let isWhitespace = substring.first!.isWhitespace

                if isWhitespace, (isLeadingOrTrailing || substring.count > 1) {
                    if buffer.isEmpty == false {
                        events.append(.event(.text(buffer), whitespacePolicy))
                        buffer.removeAll(keepingCapacity: true)
                    }

                    // Processing will be adjusted in prepare()
                    events.append(.whitespace(String(substring), .collapse))
                } else {
                    buffer += substring
                }
            }

            if buffer.isEmpty == false {
                events.append(.event(.text(buffer), whitespacePolicy))
                buffer.removeAll(keepingCapacity: true)
            }

            return events
        }

        private mutating func push(_ element: T, _ attributes: Attributes) -> WhitespacePolicy {
            var whitespacePolicy: WhitespacePolicy

            if currentWhitespacePolicy == .preserve { // override if needed
                whitespacePolicy = .preserve
            } else {
                whitespacePolicy = policy(element, attributes)
            }

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
    }
}
