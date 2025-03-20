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

public struct ParsingEventDebugFormatter: Sendable {
    func format<E, S>(_ sequence: S) async throws -> String
        where S: AsyncSequence,
              S.Element == WhitespaceParsingEvent<E>,
              E: ElementRepresentable
    {
        let array = try await Array(sequence.map { "\(format($0))" })
        return array.joined(separator: " ")
    }

    func format<E, S>(_ sequence: S) async throws -> String
        where S: AsyncSequence,
              S.Element == ParsingEvent<E>,
              E: ElementRepresentable
    {
        let array = try await Array(sequence.map { "\(format($0))" })
        return array.joined(separator: " ")
    }

    func format<E, S>(_ sequence: S) -> String
        where S: Sequence,
              S.Element == WhitespaceParsingEvent<E>,
              E: ElementRepresentable
    {
        sequence.map { "\(format($0))" }.joined(separator: " ")
    }

    func format<E, S>(_ sequence: S) -> String
        where S: Sequence,
              S.Element == ParsingEvent<E>,
              E: ElementRepresentable
    {
        sequence.map { "\(format($0))" }.joined(separator: " ")
    }

    func format<E>(_ event: WhitespaceParsingEvent<E>) -> String
        where E: ElementRepresentable
    {
        switch event {
        case .whitespace(let string, let processing):
            return "[\(format(processing)):\(format(whitespace: string))]"
        case .event(let event, let policy):
            return switch event {
            case .begin(_, _):
                "[\(format(policy))"
            case .end(_):
                "\(format(policy))]"
            case .text(let string):
                "[\(string)]"
            default:
                String()
            }
        }
    }

    func format<E>(
        _ event: ParsingEvent<E>
    ) -> String
        where E: ElementRepresentable
    {
        return switch event {
        case .begin(let element, _):
            "[\(element)"
        case .end(let element):
            "\(element)]"
        case .text(let string):
            "[\(string)]"
        default:
            String()
        }
    }

    func format(_ policy: WhitespacePolicy) -> String {
        return switch policy {
        case .inline:
            "inline"
        case .block:
            "block"
        case .preserve:
            "preserve"
        }
    }

    func format(_ processing: WhitespaceProcessing) -> String {
        return switch processing {
        case .collapse:
            "collapse"
        case .remove:
            "remove"
        }
    }

    func format(whitespace: String) -> String {
        whitespace.map {
            if $0 == "\t" { return "⇥" }
            if $0.isNewline { return "↩︎" }
            if $0.isWhitespace { return "·" }
            return String($0)
        }
        .joined()
    }
}
