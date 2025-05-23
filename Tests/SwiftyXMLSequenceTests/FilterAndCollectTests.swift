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
import AsyncAlgorithms
@testable import SwiftyXMLSequence

struct FilterAndCollectTests {
    enum Error: Swift.Error {
        case fileNoSuchFile
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

    @Test func testCollectTitle() async throws {
        let events = try await Array(
            try await makeEvents(HTMLElement.self, for: "sample1")
        )

        let title = events.collect { element, attributes in
            return switch element {
            case .title:
                true
            default:
                false
            }
        }.reduce(String()) { partialResult, event in
            return switch event {
            case .text(let string):
                partialResult + string
            default:
                partialResult
            }
        }

        #expect(title == "Der Blaue Reiter")
    }

    @Test func testAsyncCollectTitle() async throws {
        let title = try await makeEvents(HTMLElement.self, for: "sample1")
            .collect { element, attributes in
                return switch element {
                case .title:
                    true
                default:
                    false
                }
            }.reduce(String()) { partialResult, event in
                return switch event {
                case .text(let string):
                    partialResult + string
                default:
                    partialResult
                }
            }

        #expect(title == "Der Blaue Reiter")
    }

    @Test func testFilterSection() async throws {
        let events = try await Array(
            try await makeEvents(HTMLElement.self, for: "sample1")
        )

        let listItem = events.collect { element, attributes in
            return switch element {
            case .li:
                true
            default:
                false
            }
        }.filter { element, attributes in
            attributes.contains(id: ["mwqA"])
        }.reduce(String()) { partialResult, event in
            return switch event {
            case .text(let string):
                partialResult + string
            default:
                partialResult
            }
        }

        #expect(listItem == "Kandinsky's \"On Stage Composition\"")
    }

    @Test func testAsyncFilterSection() async throws {
        let listItem = try await makeEvents(HTMLElement.self, for: "sample1")
            .collect { element, attributes in
                return switch element {
                case .li:
                    true
                default:
                    false
                }
            }.filter { element, attributes in
                attributes.contains(id: ["mwqA"])
            }.reduce(String()) { partialResult, event in
                return switch event {
                case .text(let string):
                    partialResult + string
                default:
                    partialResult
                }
            }

        #expect(listItem == "Kandinsky's \"On Stage Composition\"")
    }
}
