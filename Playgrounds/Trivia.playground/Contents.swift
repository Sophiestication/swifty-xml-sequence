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

import PlaygroundSupport
import SwiftUI
import SwiftyXMLSequence

PlaygroundPage.current.needsIndefiniteExecution = true

func bool(from attributes: [String:String]) -> Bool {
    guard let string = attributes["correct"] else {
        return false
    }

    guard let value = Bool(string) else {
        return false
    }

    return value
}

func url(from attributes: [String:String]) -> URL? {
    guard let string = attributes["reference"] else {
        return nil
    }

    return URL(string: string)
}

enum Element {
    case trivia
    case question
    case answer(correct: Bool)
    case explaination(reference: URL?)
    case custom(String)

    init(from string: String, _ attributes: [String:String]) {
        switch string.lowercased() {
        case "trivia":
            self = .trivia
        case "question":
            self = .question
        case "answer":
            self = .answer(correct: bool(from: attributes))
        case "explanation":
            self = .explaination(reference: url(from: attributes))
        default:
            self = .custom(string)
        }
    }
}

extension Element {
    var style: AttributeContainer {
        var container = AttributeContainer()

        switch self {
        case .question:
            container.font = .system(size: 18.0).bold()

        case .answer(let correct):
            container.font = .system(size: 17.0)

        case .explaination(let reference):
            container.font = .system(size: 17.0).italic()

        default:
            AttributeContainer()
        }

        return container
    }
}

enum Node {
    case begin(element: Element)
    case end

    case text(String)
}

Task {
    do {
        let (events, _) = try await URLSession.shared.xml(
            for: Bundle.main.url(forResource: "trivia", withExtension: "xml")!
        )

        let nodes = events.compactMap { event -> Node? in
            return switch event {
            case .begin(let string, let attributes):
                Node.begin(
                    element: Element(from: string, attributes)
                )

            case .end(let string):
                .end

            case .text(let string):
                .text(string)

            default:
                nil
            }
        }

        struct State {
            var attributedString = AttributedString()
            var elementStack: [Element] = []
        }

        func shouldIgnoreText(for element: Element) -> Bool {
            switch element {
            case .question, .answer(_), .explaination(_):
                return false
            default:
                return true
            }
        }

        func shouldPrependLinebreak(for element: Element) -> Bool {
            switch element {
            case .explaination(_):
                return true
            default:
                return false
            }
        }

        func shouldAppendLinebreak(for element: Element) -> Bool {
            switch element {
            case .trivia, .question, .explaination(_):
                return true
            default:
                return false
            }
        }

        var initialState = State()

        let resultState = try await nodes.reduce(into: initialState) { result, node in
            switch node {
            case .begin(let element):
                result.elementStack.append(element)

            case .end:
                if let currentElement = result.elementStack.last {
                    if shouldAppendLinebreak(for: currentElement) {
                        result.attributedString.append(AttributedString("\n"))
                    }
                }

                _ = result.elementStack.popLast()

            case .text(let string):
                if let currentElement = result.elementStack.last {
                    if shouldIgnoreText(for: currentElement) == false {
                        if shouldPrependLinebreak(for: currentElement) {
                            result.attributedString.append(AttributedString("\n"))
                        }

                        if case .answer(let correct) = currentElement,
                           correct == true {
                            result.attributedString.append(
                                AttributedString("✓ ", attributes: currentElement.style)
                            )
                        }

                        result.attributedString.append(
                            AttributedString(string, attributes: currentElement.style)
                        )
                        result.attributedString.append(AttributedString("\n"))
                    }
                }
            }
        }

        let attributedString = resultState.attributedString

        struct PlaygroundView: View {
            let attributedString: AttributedString

            var body: some View {
                ScrollView {
                    Text(attributedString)
                        .padding()
                }
                .frame(width: 320.0)
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
