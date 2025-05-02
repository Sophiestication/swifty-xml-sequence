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

import PlaygroundSupport
import SwiftUI
import SwiftyXMLSequence

PlaygroundPage.current.needsIndefiniteExecution = true

Task {
    do {
        let (events, _) = try await URLSession.shared.xml(
            HTMLElement.self,
            for: URL(string: "https://en.wikipedia.org/api/rest_v1/page/html/Eero_Saarinen")!
        )

        let text = try await events
            .collect { element, attributes in
                return switch element {
                case .title, .h1, .h2, .h3, .h4, .h5, .h6, .p, .ul, .ol, .li:
                    true
                default:
                    false
                }
            }
            .filter { element, attributes in
                return switch element {
                case .style, .link:
                    false
                default:
                    true
                }
            }
            .filter { element, attributes in
                if attributes.contains(class: "reference") { return false }
                if attributes.contains(class: "navbox") { return false }
                if attributes.contains(class: "mw-editsection") { return false }
                if attributes.contains(class: "mw-cite-backlink") { return false }

                return true
            }
            .map(whitespace: { element, _ in
                element.whitespacePolicy
            })
            .map(linebreaks: { element, _ in
                return switch element {
                case .title, .h1, .h2, .h3, .h4, .h5, .h6, .p, .ul, .ol, .li:
                    "\n \n"
                default:
                    "\n"
                }
            })
            .collapse()
            .reduce(into: String()) { @Sendable partialResult, event in
                switch event {
                case .text(let string):
                    partialResult.append(string)
                    break
                default:
                    break
                }
            }

        let attributedString = AttributedString(text)

        struct PlaygroundView: View {
            let attributedString: AttributedString

            var body: some View {
                ScrollView {
                    Text(attributedString)
                        .fontDesign(.monospaced)
                        .padding()
                }
                .frame(width: 640.0)
            }
        }

        DispatchQueue.main.async {
            let view = PlaygroundView(attributedString: attributedString)
            PlaygroundPage.current.setLiveView(view)
        }
    } catch {
        print("\(error)")
    }
}
