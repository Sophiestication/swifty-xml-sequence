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

public enum HTMLElement: ElementRepresentable {
    case html, head, meta, title, link, style, script, body

    // Sectioning
    case div, span, section, article, aside, nav, header, footer, main

    // Text & Formatting
    case p, br, hr, figure, figcaption, blockquote, q, cite, code, pre
    case abbr, sup, sub, strong, b, i, u, small, mark, time, kbd, samp, `var`
    case ruby, rt, rp, bdi, bdo, wbr

    // Headings
    case h1, h2, h3, h4, h5, h6

    // Lists
    case ul, ol, li, dl, dt, dd

    // Tables
    case table, thead, tbody, tfoot, tr, th, td, caption, colgroup, col

    // Forms & Inputs
    case form, label, input, textarea, button, select, option, optgroup
    case fieldset, legend, datalist, output, progress, meter

    // Interactive Elements
    case details, summary, dialog

    // Media
    case audio, video, source, track, embed, object, param, iframe, canvas, picture, svg, img

    // Links
    case a

    // Custom
    case custom(String)

    private static let stringToElement: [String: HTMLElement] = [
        "html": .html,
        "head": .head,
        "meta": .meta,
        "title": .title,
        "link": .link,
        "style": .style,
        "script": .script,
        "body": .body,

        "div": .div,
        "span": .span,
        "section": .section,
        "article": .article,
        "aside": .aside,
        "nav": .nav,
        "header": .header,
        "footer": .footer,
        "main": .main,

        "p": .p,
        "br": .br,
        "hr": .hr,
        "figure": .figure,
        "figcaption": .figcaption,
        "blockquote": .blockquote,
        "q": .q,
        "cite": .cite,
        "code": .code,
        "pre": .pre,

        "abbr": .abbr,
        "sup": .sup,
        "sub": .sub,
        "strong": .strong,
        "b": .b,
        "i": .i,
        "u": .u,
        "small": .small,
        "mark": .mark,
        "time": .time,
        "kbd": .kbd,
        "samp": .samp,
        "var": .var,
        "ruby": .ruby,
        "rt": .rt,
        "rp": .rp,
        "bdi": .bdi,
        "bdo": .bdo,
        "wbr": .wbr,

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
        "dt": .dt,
        "dd": .dd,

        "table": .table,
        "thead": .thead,
        "tbody": .tbody,
        "tfoot": .tfoot,
        "tr": .tr,
        "th": .th,
        "td": .td,
        "caption": .caption,
        "colgroup": .colgroup,
        "col": .col,

        "form": .form,
        "label": .label,
        "input": .input,
        "textarea": .textarea,
        "button": .button,
        "select": .select,
        "option": .option,
        "optgroup": .optgroup,
        "fieldset": .fieldset,
        "legend": .legend,
        "datalist": .datalist,
        "output": .output,
        "progress": .progress,
        "meter": .meter,

        "details": .details,
        "summary": .summary,
        "dialog": .dialog,

        "audio": .audio,
        "video": .video,
        "source": .source,
        "track": .track,
        "embed": .embed,
        "object": .object,
        "param": .param,
        "iframe": .iframe,
        "canvas": .canvas,
        "picture": .picture,
        "svg": .svg,
        "img": .img,

        "a": .a,
    ]

    public init(element: String, attributes: Attributes) {
        let key = element.lowercased()
        self = HTMLElement.stringToElement[key] ?? .custom(element)
    }
}

extension HTMLElement: WhitespaceCollapsing {
    public var whitespacePolicy: WhitespacePolicy {
        return switch self {
        case .br, .wbr, .span, .a, .b, .i, .u, .strong, .small, .mark,
             .abbr, .cite, .q, .code, .sup, .sub, .time, .kbd, .samp, .var,
             .ruby, .rt, .rp, .bdi, .bdo, .img, .button, .label,
             .input, .select, .option, .optgroup,
             .output, .progress, .meter, .details, .summary:
            .inline

        case .pre, .textarea:
            .preserve

        default:
            .block
        }
    }
}
