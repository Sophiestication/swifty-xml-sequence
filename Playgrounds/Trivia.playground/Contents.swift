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

enum Element: ElementRepresentable, Equatable {
    case trivia
    case question
    case answer(correct: Bool)
    case explaination(reference: URL?)
    case custom(String)

    init(element elementName: String, attributes: [String:String]) {
        switch elementName.lowercased() {
        case "trivia":
            self = .trivia
        case "question":
            self = .question
        case "answer":
            self = .answer(correct: bool(from: attributes))
        case "explanation":
            self = .explaination(reference: url(from: attributes))
        default:
            self = .custom(elementName)
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

Task {
    do {
        let (events, _) = try await URLSession.shared.xml(
            Element.self,
            for: Bundle.main.url(forResource: "trivia", withExtension: "xml")!
        )

        actor ElementStack {
            private var stack: [Element] = []

            func push(_ element: Element) { stack.append(element) }
            func pop() { stack.removeLast() }

            var style: AttributeContainer { stack.last?.style ?? AttributeContainer() }
        }

        let elementStack = ElementStack()

        let attributedString = try await events.map(whitespace: { element, attributes in
            return switch element {
            case .trivia, .custom(_):
                .block
            default:
                .preserve
            }
        })
        .collapse()
        .compactMap { (event) -> AttributedString? in
            switch event {
            case .begin(let element, let attributes):
                await elementStack.push(element)

                return switch element {
                case .answer(let correct):
                    correct ? AttributedString("✓ ") : nil
                case .explaination(_):
                    AttributedString("\n")
                default:
                    nil
                }

            case .end(let element):
                await elementStack.pop()

                return switch element {
                case .answer(_):
                    AttributedString("\n")
                case .question, .explaination(_):
                    AttributedString("\n\n")
                default:
                    nil
                }

            case .text(let string):
                return await AttributedString(string, attributes: elementStack.style)

            default:
                return nil
            }
        }.reduce(AttributedString()) { @Sendable result, attributedString in
            result + attributedString
        }

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
