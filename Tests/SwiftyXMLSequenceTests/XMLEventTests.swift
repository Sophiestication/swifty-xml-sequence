//
// MIT License
//
// Copyright (c) 2023 Sophiestication Software, Inc.
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

import XCTest
@testable import SwiftyXMLSequence

final class XMLEventTests: XCTestCase {
    typealias XMLElement = SwiftyXMLSequence.XMLElement
    typealias ParsingEvent = XMLParsingEvent<XMLElement>

    var session: URLSession!
    var triviaFileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        session = URLSession(configuration: .default)

        guard let fileURL = Bundle.module.url(forResource: "trivia", withExtension: "xml") else {
            throw XCTSkip("Failed to find trivia.xml file. Skipping all tests.")
        }
        triviaFileURL = fileURL
    }

    func testParseTrivia() async {
        await tryAndFailIfNeeded {
            let (events, _) = try await session.xml(for: triviaFileURL)

            let nodes = try await parse(events)

            guard let document = nodes.first,
                  case .document(_) = document else {
                XCTFail("The parsed document has no child nodes.")
                return
            }
        }
    }

    func testParseAndCompareTrivia() async {
        await tryAndFailIfNeeded {
            let (events, _) = try await session.xml(for: triviaFileURL)
            let events2 = makeXMLParserStream(for: triviaFileURL)

            let equalSequences = await isEqual(events, events2)
            XCTAssertTrue(equalSequences)
        }
    }

    private func isEqual<S1: AsyncSequence, S2: AsyncSequence>(
        _ sequence1: S1,
        _ sequence2: S2
    ) async -> Bool
    where S1.Element == S2.Element, S1.Element: Equatable {
        var iterator1 = sequence1.makeAsyncIterator()
        var iterator2 = sequence2.makeAsyncIterator()

        while let element1 = try? await iterator1.next(),
              let element2 = try? await iterator2.next() {
            if element1 != element2 {
                return false
            }
        }

        let nextElement1 = try? await iterator1.next()
        let nextElement2 = try? await iterator2.next()

        if nextElement1 != nextElement2 {
            return false
        }

        return true
    }

    private enum Node {
        case document(children: [Node])
        case element(
            name: String,
            attributes: [String: String],
            children: [Node]
        )
        case text(String)
    }

    private func parse<S: AsyncSequence>(
        _ events: S
    ) async throws -> [Node] where S.Element == ParsingEvent {
        var children = [Node]()

        for try await event in events {
            switch event {
            case .beginDocument:
                let document = Node.document(
                    children: try await parse(events)
                )
                children.append(document)

                break

            case .begin(let element, let attributes):
                let element = Node.element(
                    name: element.name,
                    attributes: attributes,
                    children: try await parse(events)
                )
                children.append(element)

                break

            case .text(let string):
                let text = Node.text(string)
                children.append(text)

                break

            default:
                break
            }
        }

        return children
    }

    private func tryAndFailIfNeeded(_ action: () async throws -> Void) async {
        do {
            try await action()
        } catch let error as XMLParsingError {
            XCTFail("Line \(error.line); Column \(error.column): \(error.message)")
        } catch {
            XCTFail("Error occurred: \(error)")
        }
    }

    private func makeXMLParserStream(for url: URL) -> AsyncThrowingStream<ParsingEvent, Error> {
        return AsyncThrowingStream<XMLParsingEvent, Error> { continuation in
            let delegate = XMLParserDelegate({ event in
                continuation.yield(event)
            })

            guard let parser = XMLParser(contentsOf: url) else {
                continuation.finish()
                return
            }

            parser.delegate = delegate

            parser.parse()
            continuation.finish(throwing: parser.parserError)
        }
    }

    private class XMLParserDelegate: NSObject, Foundation.XMLParserDelegate {
        private let yield: (ParsingEvent) -> Void

        init(_ yield: (@escaping (ParsingEvent) -> Void)) {
            self.yield = yield
        }

        func parserDidStartDocument(_ parser: XMLParser) {
            yield(.beginDocument)
        }

        func parserDidEndDocument(_ parser: XMLParser) {
            yield(.endDocument)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            yield(.text(string))
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String : String]
        ) {
            let element = XMLElement(
                element: elementName,
                attributes: attributeDict
            )
            yield(.begin(element, attributes: attributeDict))
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            yield(.endElement)
        }
    }
}
