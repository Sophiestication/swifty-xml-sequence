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

import Foundation

extension URLSession {
    public typealias AsyncXMLParsingEvents<Element> = AsyncThrowingStream<
        ParsingEvent<Element>,
        any Error
    > where Element: ElementRepresentable

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

                task.delegate = ParsingSessionDelegate<Element>(
                    with: responseContinuation,
                    dataContinuation: dataContinuation,
                    delegate: delegate
                )

                task.resume()
            }
        }

        return (events!, response)
    }
}

private final class ParsingSessionDelegate<
    Element
>: NSObject, URLSessionDataDelegate, @unchecked Sendable
    where Element: ElementRepresentable
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

    private let delegate: URLSessionTaskDelegate?

    private var response: URLResponse? = nil
    private var parser: PushParser? = nil

    private var elementStack: [Element] = []

    init(
        with responseContinuation: ResponseContinuation,
        dataContinuation: DataContinuation,
        delegate: URLSessionTaskDelegate? = nil
    ) {
        self.responseContinuation = responseContinuation
        self.dataContinuation = dataContinuation
        self.delegate = delegate
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        self.response = response

        if let continuation = self.responseContinuation {
            continuation.resume(returning: response)
            self.responseContinuation = nil
        }

        if let dataDelegate = delegate as? URLSessionDataDelegate,
           dataDelegate.responds(to:#selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:))) {
            dataDelegate.urlSession?(
                session,
                dataTask: dataTask,
                didReceive: response,
                completionHandler: completionHandler
            )
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        if let dataDelegate = delegate as? URLSessionDataDelegate {
            dataDelegate.urlSession?(session, dataTask: dataTask, didReceive: data)
        }

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

        delegate?.urlSession?(session, task: task, didCompleteWithError: error)
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || delegate?.responds(to: aSelector) == true
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        delegate
    }

    private func makePushParser() -> PushParser {
        PushParser(
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

                self.elementStack.append(element)

                self.dataContinuation?.yield(
                    .begin(element, attributes: attributes)
                )
            }, endElement: {
                guard let element = self.elementStack.popLast() else {
                    return // we rely on libxml2 always calling with matching start/end events
                }

                self.dataContinuation?.yield(.end(element))
            }, characters: { string in
                self.dataContinuation?.yield(.text(string))
            }
        )
    }
}
