///
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

public enum WhitespaceBehavior {
    case collapse
    case preserve
    case preserveBreak
}

extension AsyncSequence {
    public func whitespace<T: ElementRepresentable>(
        _ behavior: @Sendable @escaping (
            _ element: T,
            _ attributes: Attributes
        ) -> WhitespaceBehavior
    ) async rethrows -> AsyncThrowingWhitespaceTransformingSequence<Self, T>
        where Element == ParsingEvent<T>
    {
        return AsyncThrowingWhitespaceTransformingSequence(
            base: self,
            behavior: behavior
        )
    }
}

public struct AsyncThrowingWhitespaceTransformingSequence<Base, T>: AsyncSequence, Sendable
    where Base: AsyncSequence,
          Base: Sendable,
          Base.Element == ParsingEvent<T>,
          T: ElementRepresentable
{
    private let base: Base

    internal typealias Behavior = @Sendable (
        _ element: T,
        _ attributes: Attributes
    ) -> WhitespaceBehavior

    private let behavior: Behavior

    internal init(base: Base, behavior: @escaping Behavior) {
        self.base = base
        self.behavior = behavior
    }

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator(), behavior: behavior)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = ParsingEvent<T>

        private var base: Base.AsyncIterator
        private let behavior: Behavior

        private var currentElement: (T, Attributes)? = nil
        private var currentText: String? = nil
        private var pendingEvent: Element? = nil

        internal init(_ base: Base.AsyncIterator, behavior: @escaping Behavior) {
            self.base = base
            self.behavior = behavior
        }

        public mutating func next() async throws -> Element? {
            if let pendingEvent {
                self.pendingEvent = nil
                return pendingEvent
            }

            while let event = try await base.next() {
                switch event {
                case .begin(let element, attributes: let attributes):
                    currentElement = (element, attributes)
                    return makeNextEvent(for: event)
                case .end(_), .endDocument:
                    let nextEvent = makeNextEvent(for: event)
                    currentElement = nil
                    return nextEvent
                case .text(let string):
                    if var currentText {
                        currentText += string
                    } else {
                        currentText = string
                    }
                    break
                default:
                    return event
                }
            }

            if let currentText { // we reached the end of the stream
                if let processedText = processText(for: currentElement, text: currentText) {
                    return Element.text(processedText)
                }
            }

            return nil
        }

        private mutating func makeNextEvent(for event: Element) -> Element {
            guard let currentText else {
                return event
            }

            guard let processedText = processText(for: currentElement, text: currentText) else {
                return event
            }

            self.pendingEvent = event

            let nextEvent: Element = .text(processedText)

            self.currentText = nil

            return nextEvent
        }

        private func processText(for element: (T, Attributes)?, text: String) -> String? {
            switch whitespaceBehavior(for: element) {
            case .collapse:
                return collapse(text)
            case .preserve:
                return preserve(text)
            case .preserveBreak:
                return preserveBreak(text)
            }
        }

        private func whitespaceBehavior(for element: (T, Attributes)?) -> WhitespaceBehavior {
            guard let element else {
                return .collapse
            }

            let whitespaceBehavior = behavior(element.0, element.1)
            return whitespaceBehavior
        }

        private func collapse(_ text: String) -> String {
            let normalized = text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

            return normalized.isEmpty ? "" : normalized
        }

        private func preserve(_ text: String) -> String {
            return text
        }

        private func preserveBreak(_ text: String) -> String {
            text
                .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression) // Collapse spaces
                .trimmingCharacters(in: .whitespacesAndNewlines) // Remove leading/trailing spaces
        }
    }
}
