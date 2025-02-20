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

extension URLSession {
    public typealias AsyncXMLParsingEvents<Element> = AsyncThrowingStream <
        XMLParsingEvent<Element>,
        any Error
    > where Element: ElementRepresentable & Equatable & Sendable

    public func xml<Element>(
        _ elementType: Element.Type = XMLElement.self,
        for url: URL,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> (AsyncXMLParsingEvents<Element>, URLResponse) {
        try await xml(
            elementType,
            for: URLRequest(url: url),
            delegate: delegate
        )
    }

    public func xml<Element>(
        _ elementType: Element.Type = XMLElement.self,
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> (AsyncXMLParsingEvents<Element>, URLResponse) {
        var events: AsyncXMLParsingEvents<Element>? = nil
        let response = try await withCheckedThrowingContinuation { responseContinuation in
            events = AsyncXMLParsingEvents<Element> { dataContinuation in
                let task = self.dataTask(with: request)

                task.delegate = XMLParsingSessionDelegate<Element>(
                    with: responseContinuation,
                    dataContinuation: dataContinuation
                )

                task.resume()
            }
        }

        return (events!, response)
    }
}

private final class XMLParsingSessionDelegate<
    Element
>: NSObject, URLSessionDataDelegate, @unchecked Sendable
    where Element: ElementRepresentable & Equatable & Sendable
{
    typealias ResponseContinuation = CheckedContinuation <
        URLResponse,
        any Error
    >
    private var responseContinuation: ResponseContinuation?

    typealias DataContinuation = URLSession.AsyncXMLParsingEvents <
        Element
    >.Continuation
    private let dataContinuation: DataContinuation?

    private var response: URLResponse? = nil
    private var parser: XMLPushParser? = nil

    init(
        with responseContinuation: ResponseContinuation,
        dataContinuation: DataContinuation
    ) {
        self.responseContinuation = responseContinuation
        self.dataContinuation = dataContinuation
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse
    ) async -> URLSession.ResponseDisposition {
        self.response = response

        if let continuation = self.responseContinuation {
            continuation.resume(returning: response)
            self.responseContinuation = nil
        }

        return .allow
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        if parser == nil {
            parser = makePushParser()
        }

        do {
            try parser!.push(data)
        } catch {
            if let continuation = self.dataContinuation {
                continuation.finish(throwing: error)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        if let continuation = self.responseContinuation,
           let error {
            continuation.resume(throwing: error)
        }

        if let continuation = self.dataContinuation {
            if let error {
                continuation.finish(throwing: error)
            } else {
                do {
                    if let parser {
                        try parser.finish()
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func makePushParser() -> XMLPushParser {
        XMLPushParser(
            for: response?.suggestedFilename,

            startDocument: {
                self.dataContinuation?.yield(.beginDocument)
            }, endDocument: {
                self.dataContinuation?.yield(.endDocument)
            }, startElement: { elementName, attributes in
                let element = Element(
                    element: elementName,
                    attributes: attributes
                )
                self.dataContinuation?.yield(
                    .begin(element, attributes: attributes)
                )
            }, endElement: {
                self.dataContinuation?.yield(.endElement)
            }, characters: { string in
                self.dataContinuation?.yield(.text(string))
            }
        )
    }
}
