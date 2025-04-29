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

import Testing
import Foundation
@testable import SwiftyXMLSequence

struct ElementMapReduceTest {
    enum Error: Swift.Error {
        case fileNoSuchFile
        case unexpectedElement
    }

    private func makeEvents<Element: ElementRepresentable & Equatable & Sendable>(
        _ elementType: Element.Type = XMLElement.self,
        for filename: String
    ) async throws -> URLSession.AsyncXMLParsingEvents<Element> {
        guard let fileURL = Bundle.module.url(forResource: filename, withExtension: "html") else {
            #expect(Bool(false), "Failed to find \(filename).html file.")
            throw Error.fileNoSuchFile
        }

        let (events, _) = try await URLSession.shared.xml(
            Element.self,
            for: fileURL
        )

        return events
    }

    @Test func testMarkupDocument() async throws {
        let groups = try await makeEvents(HTMLElement.self, for: "sample2")
            .collect { element, _ in
                return switch element {
                case .head, .body, .section:
                    true
                default:
                    false
                }
            }
            .filter { element, _ in
                return switch element {
                case .style:
                    false
                default:
                    true
                }
            }
            .filter { element, attributes in
                if attributes.contains(class: "noprint") { return false }
                if attributes.contains(class: "mw-ref") { return false }
                if attributes.contains(class: "reflist") { return false }
                if attributes.contains(class: "navigation-not-searchable") { return false }

                return true
            }
            .map(whitespace: { element, attributes in
                element.whitespacePolicy
            })
            .collapse()
            .chunked { element, attributes in
                return switch element {
                case .head, .section:
                    element
                default:
                    nil
                }
            }
            .map {
                return $0.0
            }

        let expectedGroups: [HTMLElement?] =
            [ .head, nil ] +
            Array(repeating: HTMLElement.section, count: 27) +
            [ nil ]

        #expect(try await Array(groups) == expectedGroups)
    }
}
