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

@dynamicMemberLookup
public struct Attributes: Equatable, Sendable, Collection {
    fileprivate let storage: [String:String]

    public typealias Element = (key: String, value: String)
    public typealias Index = [String:String].Index

    public init(_ dictionary: [String:String]) {
        self.storage = dictionary
    }

    public subscript(dynamicMember key: String) -> String? {
        return self[key]
    }

    public subscript(key: String) -> String? {
        return storage.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
    }

    public var startIndex: Index { storage.startIndex }
    public var endIndex: Index { storage.endIndex }

    public func index(after i: Index) -> Index {
        storage.index(after: i)
    }

    public subscript(position: Index) -> Element {
        storage[position]
    }
}

extension Attributes: Identifiable {
    public typealias ID = String?
    public var id: ID { storage["id"] }
}

extension Attributes {
    public var `class`: some Collection<Substring> {
        (storage["class"] ?? String()).matches(of: /\S+/).lazy.map(\.output) // 🕶️
    }
}

public extension Dictionary
    where Key == String,
          Value == String
{
    init(_ attributes: Attributes) {
        self = attributes.storage
    }
}
