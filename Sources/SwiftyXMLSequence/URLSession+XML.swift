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
    public struct AsyncXMLParsingEvents: AsyncSequence, Sendable {
        public typealias Element = XMLParsingEvent
        public typealias AsyncIterator = AsyncThrowingStream<Element, Error>.AsyncIterator

        typealias Stream = AsyncThrowingStream<Element, Error>
        private let stream: Stream

        init<T: AsyncSequence & Sendable>(
            _ bytes: T,
            _ response: URLResponse
        ) where T.Element == UInt8 {
            self.stream = Stream { continuation in
                Task { @Sendable in
                    let parser = XMLPushParser(for: response.suggestedFilename, { event in
                        continuation.yield(event)
                    })

                    do {
                        let bufferSize = 1024
                        var buffer = Data(capacity: bufferSize)

                        for try await byte in bytes {
                            buffer.append(byte)

                            if buffer.count == bufferSize {
                                try parser.push(buffer)
                                buffer.removeAll()
                            }
                        }

                        if !buffer.isEmpty {
                            try parser.push(buffer)
                        }

                        try parser.finish()
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }

        public func makeAsyncIterator() -> AsyncIterator {
            stream.makeAsyncIterator()
        }
    }

    public func xml(
        for url: URL,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> (AsyncXMLParsingEvents, URLResponse) {
        try await xml(
            for: URLRequest(url: url),
            delegate: delegate
        )
    }

    public func xml(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> (AsyncXMLParsingEvents, URLResponse) {
        let (bytes, response) = try await bytes(for: request, delegate: delegate)
        bytes.task.prefersIncrementalDelivery = true

        let events = AsyncXMLParsingEvents(bytes, response)

        return (events, response)
    }
}
