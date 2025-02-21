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

    private typealias HTMLParsingEvents = URLSession.AsyncXMLParsingEvents<HTMLElement>

    private func makeSample1Events() async throws -> HTMLParsingEvents {
        guard let fileURL = Bundle.module.url(forResource: "sample1", withExtension: "html") else {
            #expect(Bool(false), "Failed to find sample1.html file.")
            throw Error.fileNoSuchFile
        }

        let (events, _) = try await URLSession.shared.xml(
            HTMLElement.self,
            for: fileURL
        )

        return events
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

        let paragraph = try await events.xmlElement { element, attributes in
            attributes["id"] == "mwGQ"
        }

        var text: String = ""

        for try await event in paragraph {
            if case .text(let string) = event {
                text += string
            }
        }

        let expectedText = "The artists associated with Der Blaue Reiter were important pioneers of modern art of the 20th century; they formed a loose network of relationships, but not an art group in the narrower sense like Die Brücke (The Bridge) in Dresden. The work of the affiliated artists is assigned to German Expressionism."

        #expect(text == expectedText)
    }
}
