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

struct WhitespaceCollapseTest {
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

    @Test func testWhitespaceMapping() async throws {
        let events = try await makeEvents(HTMLElement.self, for: "whitespace-collapse")

        let text = try await events.map(whitespace: { element, attributes in
            element.whitespacePolicy
        }).reduce(into: String()) { partialResult, event in
            switch event {
            case .whitespace(let string, let processing):
                partialResult.append(contentsOf: string.map {
                    character(for: $0, processing)
                })
            case .event(let event, _):
                switch event {
                case .text(let string):
                    partialResult.append(string)
                    break
                default:
                    break
                }
            }
        }

        let expectedText = "₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋Art····Deco₋₋₋₋Art Deco got its name after the₋₋₋₋₋₋1925₋₋₋₋₋₋Exposition₋ internationale₋₋₋₋₋₋ des arts décoratifs et industriels modernes···········(International Exhibition of Modern Decorative and Industrial Arts) held in Paris. Art Deco has its origins in bold geometric forms of the Vienna Secession and Cubism.₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋₋·········From its outset, it was influenced····by the bright colors of Fauvism and of the Ballets······Russes, and the exoticized styles of art from···············China, Japan, India, Persia, ancient Egypt, and Maya.₋₋₋₋₋₋₋₋"

        #expect(text == expectedText)
    }

    @Test func testWhitespaceCollapsing() async throws {
        typealias Event = ParsingEvent<HTMLElement>
        typealias WhitespaceEvent = WhitespaceParsingEvent<HTMLElement>

        let events = try await makeEvents(HTMLElement.self, for: "whitespace-collapse")

        let text = try await events.collect { element, _ in
            return switch element {
            case .body:
                true
            default:
                false
            }
        }
        .collapseWhitespace()
        .reduce(into: String()) { partialResult, event in
            switch event {
            case .text(let string):
                partialResult.append(string)
                break
            default:
                break
            }
        }

        let expectedText = "Art DecoArt Deco got its name after the1925Exposition internationale des arts décoratifs et industriels modernes (International Exhibition of Modern Decorative and Industrial Arts) held in Paris. Art Deco has its origins in bold geometric forms of the Vienna Secession and Cubism. From its outset, it was influenced by the bright colors of Fauvism and of the Ballets Russes, and the exoticized styles of art from China, Japan, India, Persia, ancient Egypt, and Maya."

        #expect(text == expectedText)
    }

    @Test func testWhitespacePreserving() async throws {
        typealias Event = ParsingEvent<HTMLElement>
        typealias WhitespaceEvent = WhitespaceParsingEvent<HTMLElement>

        let events = try await makeEvents(HTMLElement.self, for: "whitespace-collapse")

        let text = try await events.collect { element, _ in
            return switch element {
            case .h1:
                true
            default:
                false
            }
        }.map(whitespace: { element, _ in
            .preserve
        })
        .collapse()
        .reduce(into: String()) { partialResult, event in
            switch event {
            case .text(let string):
                partialResult.append(string)
                break
            default:
                break
            }
        }

        let expectedText = " Art    Deco    "

        #expect(text == expectedText)
    }

    private func character(
        for c: Character,
        _ processing: WhitespaceProcessing
    ) -> Character {
        if processing == .collapse {
            "·"
        } else {
            "₋"
        }
    }
}
