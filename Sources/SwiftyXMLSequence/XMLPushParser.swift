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

import Foundation
@preconcurrency import libxml2

final class XMLPushParser {
    private var parserContext: xmlParserCtxtPtr? = nil
    private let suggestedFilename: UnsafePointer<CChar>?

    private var yield: ((XMLParsingEvent) -> Void)

    init(for filename: String?, _ yield: (@escaping (XMLParsingEvent) -> Void)) {
        self.suggestedFilename = Self.suggestedFilename(for: filename)
        self.yield = yield
    }

    deinit {
        if let parserContext {
            xmlFreeParserCtxt(parserContext)
        }

        free(UnsafeMutablePointer(mutating: suggestedFilename))
    }

    func push(_ data: Data) throws {
        let parser = prepared(parserContext)

        try data.withUnsafeBytes { rawBufferPointer in
            if let buffer = rawBufferPointer.baseAddress?.assumingMemoryBound(to: Int8.self) {
                let errorCode = xmlParseChunk(parser, buffer, Int32(data.count), 0)
                try raiseErrorIfNeeded(for: errorCode, parser)
            }
        }
    }

    func finish() throws {
        let parser = prepared(parserContext)
        let errorCode = xmlParseChunk(parser, nil, 0, 1)

        try raiseErrorIfNeeded(for: errorCode, parser)
    }

    private func prepared(_ parser: xmlParserCtxtPtr?) -> xmlParserCtxtPtr {
        guard let preparedContext = self.parserContext else {
            let context = Unmanaged<XMLPushParser>
                .passUnretained(self)
                .toOpaque()
            var handler = Self.SAXHandler

            self.parserContext = xmlCreatePushParserCtxt(
                &handler,
                context,
                nil,
                0,
                self.suggestedFilename
            )

            let options =
                Int32(XML_PARSE_NOBLANKS.rawValue) |
                Int32(XML_PARSE_NONET.rawValue) |
                Int32(XML_PARSE_COMPACT.rawValue) |
                Int32(XML_PARSE_NOENT.rawValue)
            xmlCtxtUseOptions(self.parserContext, options)

            return self.parserContext!
        }

        return preparedContext
    }

    private func raiseErrorIfNeeded(for errorCode: Int32, _ parser: xmlParserCtxtPtr) throws {
        if errorCode != XML_ERR_NONE.rawValue {
            if let lastError = xmlCtxtGetLastError(parser) {
                throw XMLParsingError(from: lastError)
            }
        }
    }

    private static let SAXHandler: xmlSAXHandler = {
        var handler = xmlSAXHandler()

        handler.startDocument = startDocumentSAX
        handler.endDocument = endDocumentSAX
        
        handler.startElement = startElementSAX
        handler.endElement = endElementSAX

        handler.characters = charactersSAX

        return handler
    }()

    private static let startDocumentSAX: startDocumentSAXFunc = { context in
        guard let parser = parser(from: context) else { return }
        parser.yield(.beginDocument)
    }

    private static let endDocumentSAX: endDocumentSAXFunc = { context in
        guard let parser = parser(from: context) else { return }
        parser.yield(.endDocument)
    }

    private static let startElementSAX: startElementSAXFunc = { context, name, attributes in
        guard let parser = parser(from: context),
              let name = name else {
            return
        }

        let elementName = String(cString: name)
        var attributeDict = [String: String]()

        if let attributes = attributes {
            var i = 0

            while attributes[i] != nil {
                guard let attributeName = attributes[i],
                      let attributeValue = attributes[i + 1] else {
                    continue
                }

                attributeDict[String(cString: attributeName)]
                    = String(cString: attributeValue)
                i += 2
            }
        }

        parser.yield(.begin(element: elementName, attributes: attributeDict))
    }

    private static let endElementSAX: endElementSAXFunc = { context, name in
        guard let parser = parser(from: context),
              let name = name else {
            return
        }

        let elementName = String(cString: name)
        parser.yield(.end(element: elementName))
    }

    private static let charactersSAX: charactersSAXFunc = { context, buffer, bufferSize in
        guard let parser = parser(from: context),
              let buffer = buffer else {
            return
        }

        let data = Data(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer),
            count: Int(bufferSize),
            deallocator: .none
        )

        if let text = String(data: data, encoding: .utf8) {
            parser.yield(.text(text))
        }
    }

    private static func parser(from context: UnsafeMutableRawPointer?) -> XMLPushParser? {
        guard let context = context else {
            return nil
        }

        let parser = Unmanaged<XMLPushParser>
            .fromOpaque(context)
            .takeUnretainedValue()
        return parser
    }

    private static func suggestedFilename(for string: String?) -> UnsafePointer<CChar>? {
        guard let string else {
            return nil
        }

        let cString = strdup(string)
        return UnsafePointer(cString)
    }
}
