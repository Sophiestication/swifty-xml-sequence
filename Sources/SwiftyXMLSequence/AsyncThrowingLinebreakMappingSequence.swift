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

public enum LinebreakParsingEvent<Element>: Equatable
    where Element: ElementRepresentable
{
    case event(ParsingEvent<Element>, WhitespacePolicy)
    case whitespace(String, WhitespaceProcessing)
    case linebreak(String)
}

extension AsyncSequence {
    public func map<T: ElementRepresentable>(
        linebreaks transform: @Sendable @escaping (
            _ element: T,
            _ attributes: Attributes
        ) -> String
    ) async rethrows -> AsyncThrowingLinebreakMappingSequence<Self, T>
        where Element == WhitespaceParsingEvent<T>
    {
        return try await AsyncThrowingLinebreakMappingSequence(base: self, transform: transform)
    }
}

public struct AsyncThrowingLinebreakMappingSequence<Base, T>: AsyncSequence
    where Base: AsyncSequence,
          Base.Element == WhitespaceParsingEvent<T>,
          T: ElementRepresentable
{
    private var base: Base

    internal typealias Transform = @Sendable (
        _ element: T,
        _ attributes: Attributes
    ) -> String

    private let transform: Transform

    internal init(base: Base, transform: @escaping Transform) async throws {
        self.base = base
        self.transform = transform
    }

    public typealias Element = Iterator.Element

    public func makeAsyncIterator() -> Iterator {
        return Iterator(base.makeAsyncIterator(), transform: transform)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = LinebreakParsingEvent<T>

        private var base: Base.AsyncIterator
        private var transform: Transform

        private var preparedInlineText: Bool = false

        private var collectedLinebreakElement: ParsingEvent<T>? = nil
        private var pendingLinebreakElement: ParsingEvent<T>? = nil
        private var pendingLinebreak: Bool = false

        private var prepared: [Element] = []

        fileprivate init(_ base: Base.AsyncIterator, transform: @escaping Transform) {
            self.base = base
            self.transform = transform
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
                            if preparedInlineText {
                                preparedInlineText = false

                                pendingLinebreak = true
                                pendingLinebreakElement = collectedLinebreakElement
                            }

                            if case .begin(_, _) = event {
                                collectedLinebreakElement = event
                            }
                        }

                        yield(whitespaceEvent)
                        break

                    case .text(_):
                        if pendingLinebreak {
                            yieldPendingLinebreak()
                        }

                        preparedInlineText = true
                        yield(whitespaceEvent)
                        break

                    default:
                        yield(whitespaceEvent)
                        break
                    }
                    break

                case .whitespace(_, _):
                    yield(whitespaceEvent)
                    break

                case .none:
                    pendingLinebreak = false
                    break
                }

                if pendingLinebreak == false {
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

        private mutating func yield(_ whitespaceEvent: Base.Element?) {
            guard let whitespaceEvent else {
                return
            }

            switch whitespaceEvent {
            case .event(let event, let policy):
                prepared.append(.event(event, policy))
                break

            case .whitespace(let whitespace, let processing):
                prepared.append(.whitespace(whitespace, processing))
                break
            }
        }

        private mutating func yieldPendingLinebreak() {
            if pendingLinebreak {
                let string = linebreak(for: pendingLinebreakElement)
                prepared.insert(.linebreak(string), at: 0)
            }

            self.pendingLinebreak = false
            self.pendingLinebreakElement = nil
        }

        private func linebreak(for event: ParsingEvent<T>?) -> String {
            return switch event {
            case .begin(let element, let attributes):
                transform(element, attributes)
            default:
                "\n"
            }
        }
    }
}
