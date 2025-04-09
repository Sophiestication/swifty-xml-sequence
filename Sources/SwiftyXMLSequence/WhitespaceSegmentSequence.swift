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

internal struct WhitespaceSegmentSequence: Sequence {
    let input: String

    enum Location: Equatable {
        case start
        case between
        case end
        case single
    }

    enum Element: Equatable, CustomDebugStringConvertible, CustomStringConvertible {
        case text(Substring)
        case whitespace(Substring, Location)

        var description: String {
            return switch self {
            case .text(let substring):
                String(substring)
            case .whitespace(let whitespace, _):
                String(whitespace)
            }
        }

        var debugDescription: String {
            description
        }
    }

    func makeIterator() -> Iterator {
        Iterator(input: input)
    }

    struct Iterator: IteratorProtocol {
        private let input: String
        private var current: String.Index

        init(input: String) {
            self.input = input
            self.current = input.startIndex
        }

        mutating func next() -> Element? {
            guard current < input.endIndex else { return nil }

            if let match = input[current...].firstMatch(of: /(^\s+)|(\s{2,})|(\s+$)/) {
                let range = match.range

                if current < range.lowerBound {
                    let text = input[current..<range.lowerBound]
                    current = range.lowerBound
                    return .text(text)
                } else {
                    let whitespace = input[range]
                    current = range.upperBound

                    var location: Location
                    let isStart = range.lowerBound == input.startIndex
                    let isEnd = range.upperBound == input.endIndex

                    switch (isStart, isEnd) {
                    case (true, true):
                        location = .single
                    case (true, false):
                        location = .start
                    case (false, true):
                        location = .end
                    default:
                        location = .between
                    }

                    return .whitespace(whitespace, location)
                }
            }

            if current < input.endIndex {
                let text = input[current..<input.endIndex]
                current = input.endIndex
                return .text(text)
            }

            return nil
        }
    }
}

internal extension String {
    var whitespaceSegments: WhitespaceSegmentSequence {
        WhitespaceSegmentSequence(input: self)
    }
}
