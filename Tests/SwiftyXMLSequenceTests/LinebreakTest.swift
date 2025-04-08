//
//  WhitespaceCollapseTest 2.swift
//  SwiftyXMLSequence
//
//  Created by Sophiestication Software on 4/8/25.
//


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

struct LinebreakTest {
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

    @Test func testLinebreakMapping() async throws {
        let events = try await makeEvents(HTMLElement.self, for: "whitespace-collapse")

        let whitespaceEvents = try await events
            .map(whitespace: { element, attributes in
                element.whitespacePolicy
            })
            .mapLinebreaks()

        let formatter = ParsingEventDebugFormatter()
        let debugDescription = try await formatter.format(whitespaceEvents)

        let expectedText = "[block [remove:↩︎····] [block [remove:↩︎········] [block block] [remove:↩︎····] block] [remove:↩︎····] [block [remove:↩︎↩︎↩︎········] [block [remove:·] [Art] [collapse:····] [Deco] [remove:····] [↩︎] block] [inline [Art Deco got its name after the] [remove:····] [↩︎] [block [remove:··] [1925] [remove:···] [↩︎] block] [remove:···] [Exposition] [collapse:·] [inline [remove:·] [internationale] [collapse:······] inline] [remove:·] [des arts décoratifs et industriels modernes] [collapse:↩︎↩︎↩︎········] [(International Exhibition of Modern Decorative and Industrial Arts) held in Paris. Art Deco has its origins in bold geometric forms of the Vienna Secession and Cubism.] [collapse:↩︎↩︎···········] inline] [remove:↩︎↩︎········] [inline [remove:↩︎········] [From its outset, it was influenced] [collapse:····] [by the bright colors of Fauvism and of the Ballets] [collapse:······] [Russes, and the exoticized styles of art from] [collapse:↩︎↩︎·············] [China, Japan, India, Persia, ancient Egypt, and Maya.] inline] [remove:↩︎↩︎↩︎····] block] [remove:↩︎] block]"

        #expect(debugDescription == expectedText)
    }
}
