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

final class XMLEventSessionTests: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var receivedDidCompleteWithError = false
    private var receivedDidReceiveResponse = false
    private var receivedDidReceiveData = false

    @Test func testURLSessionDelegate() async throws {
        let filename = "sample1"

        guard let fileURL = Bundle.module.url(forResource: filename, withExtension: "html") else {
            #expect(Bool(false), "Failed to find \(filename).html file.")
            return
        }

        let (events, response) = try await URLSession.shared.xml(
            HTMLElement.self,
            for: fileURL,
            delegate: self
        )

        let title = try await events.collect { element, attributes in
            return switch element {
            case .title: true
            default: false
            }
        }
        .reduce(into: String()) { partialResult, event in
            switch event {
            case .text(let string):
                partialResult.append(string)
                break
            default:
                break
            }
        }

        #expect(receivedDidCompleteWithError)
        #expect(receivedDidReceiveResponse)
        #expect(receivedDidReceiveData)

        #expect(title == "Der Blaue Reiter")

        #expect(response.suggestedFilename! == "\(filename).html")
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        receivedDidCompleteWithError = true
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        receivedDidReceiveResponse = true
        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        receivedDidReceiveData = true
    }
}
