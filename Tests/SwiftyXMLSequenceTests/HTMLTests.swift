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

struct HTMLTest {
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

    private func makeSample1Events() async throws -> URLSession.AsyncXMLParsingEvents<HTMLElement> {
        try await makeEvents(HTMLElement.self, for: "sample1")
    }

    @Test func testHTMLElementParsing() async throws {
       let events = try await makeSample1Events()

        let sections = try await events.reduce(into: [HTMLElement]()) { result, event in
            if case .begin(let element, _) = event,
               element == .section
            {
                result.append(element)
            }
        }

        #expect(sections.count > 0)
    }

    @Test func testDropUntilElement() async throws {
        let elementId = "mwGQ"
        let events = try await makeSample1Events()

        let sequence = try await events.drop { element, attributes in
            if case .p = element,
               attributes["id"] == elementId {
                return false
            }

            return true
        }

        let foundEvent = try await sequence.first(where: { _ in true })

        var isExpectedElement = false

        if let foundEvent,
           case .begin(_, let attributes) = foundEvent,
           attributes["id"] == elementId {
            isExpectedElement = true
        }

        #expect(isExpectedElement, "Could not find element with id \(elementId)")
    }

    @Test func testFilterElement() async throws {
        let elementId = "mwAQ"
        let events = try await makeSample1Events()

        let text = try await events.collect { element, attributes in
            attributes["id"] == elementId
        }.filter { element, attributes in
            return switch element {
            case .figure, .style:
                false
            default:
                true
            }
        }.reduce(String()) { partialResult, event in
            return switch event {
            case .text(let string):
                partialResult.appending(string)
            default:
                partialResult
            }
        }

        #expect(text.count > 0)
    }

    @Test func testParagraphText() async throws {
        let events = try await makeSample1Events()

        let paragraph = events.drop(while: { event in
            if case .begin(let element, let attributes) = event,
               element == .p
            {
                if attributes["id"] == "mwGQ" {
                    return false
                }
            }

            return true
        })

        var text: String = ""
        var stack: [HTMLElement] = []

        for try await event in paragraph {
            switch event {
            case .begin(let element, _):
                stack.append(element)
                break

            case .endElement:
                _ = stack.popLast()
                break

            case .text(let string):
                text += string
                break

            default:
                break
            }

            if stack.isEmpty {
                break
            }
        }

        let expectedText = "The artists associated with Der Blaue Reiter were important pioneers of modern art of the 20th century; they formed a loose network of relationships, but not an art group in the narrower sense like Die Brücke (The Bridge) in Dresden. The work of the affiliated artists is assigned to German Expressionism."

        #expect(text == expectedText)
    }

    @Test func testElementMatching() async throws {
        let events = try await makeSample1Events()

        let text = try await events.element { element, attributes in
            attributes["id"] == "mwGQ"
        }.reduce(into: String()) { partialResult, event in
            if case .text(let string) = event {
                partialResult += string
            }
        }

        let expectedText = "The artists associated with Der Blaue Reiter were important pioneers of modern art of the 20th century; they formed a loose network of relationships, but not an art group in the narrower sense like Die Brücke (The Bridge) in Dresden. The work of the affiliated artists is assigned to German Expressionism."

        #expect(text == expectedText)
    }

    private enum MediaWikiElement: ElementRepresentable, Equatable {
        case thumbnail(id: String)
        case html(HTMLElement)

        init(element: String, attributes: Attributes) {
            let html = HTMLElement(element: element, attributes: attributes)

            switch html {
            case .figure:
                if attributes["typeof"] == "mw:File/Thumb",
                   let id = attributes["id"] {
                    self = .thumbnail(id: id)
                    return
                }

            default:
                break
            }

            self = .html(html)
        }
    }

    @Test func testMatchThumbnails() async throws {
        let events = try await makeEvents(MediaWikiElement.self, for: "sample1")

        var foundURLs = [URL]()

        while true {
            let element = try await events.element { element, attributes in
                if case .thumbnail(_) = element {
                    return true
                }

                return false
            }.reduce(into: [ParsingEvent<MediaWikiElement>]()) {
                $0.append($1)
            }

            guard element.count > 0 else {
                break
            }

            let urls = element.reduce(into: [URL]()) { partialResult, event in
                if case .begin(let element, let attributes) = event,
                   case .html(let htmlElement) = element,
                   case .img = htmlElement
                {
                    if let string = attributes["src"],
                       let url = URL(string: string) {
                        partialResult.append(url)
                    }
                }
            }

            foundURLs.append(contentsOf: urls)
        }

        #expect(foundURLs.count == 5)
    }
}
