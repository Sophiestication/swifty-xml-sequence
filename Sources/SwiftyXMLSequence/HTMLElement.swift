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

public enum HTMLElement:
    Equatable,
    Sendable,
    ElementRepresentable
{
    case html,

         head, meta, title, link, style, script,

         body, div, span, section, p, br,
         figure, img, figcaption,
         a, abbr, cite, q, blockquote, code,
         sup, sub, strong, b, i, u, small,
         h1, h2, h3, h4, h5, h6,
         ul, ol, li, dl, dd,
         table, tbody, th, tr, td, caption,

         custom(String)

    private static let stringToElement: [String: HTMLElement] = [
        "html": .html,
        "head": .head,
        "title": .title,
        "meta": .meta,
        "link": .link,
        "script": .script,
        "style": .style,
        "body": .body,
        "div": .div,
        "span": .span,
        "section": .section,
        "figure": .figure,
        "img": .img,
        "figcaption": .figcaption,
        "a": .a,
        "abbr": .abbr,
        "cite": .cite,
        "q": .q,
        "blockquote": .blockquote,
        "code": .code,
        "p": .p,
        "br": .br,
        "sup": .sup,
        "sub": .sub,
        "strong": .strong,
        "b": .b,
        "i": .i,
        "u": .u,
        "small": .small,
        "h1": .h1,
        "h2": .h2,
        "h3": .h3,
        "h4": .h4,
        "h5": .h5,
        "h6": .h6,
        "ul": .ul,
        "ol": .ol,
        "li": .li,
        "dl": .dl,
        "dd": .dd,
        "table": .table,
        "tbody": .tbody,
        "tr": .tr,
        "td": .td,
        "th": .th,
        "caption": .caption
    ]

    public init(element: String, attributes: Attributes) {
        let key = element.lowercased()
        self = HTMLElement.stringToElement[key] ?? .custom(element)
    }
}
