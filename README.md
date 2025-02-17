# swifty-xml-sequence

swifty-xml-sequence is a lightweight, incremental XML parser built as a Swift wrapper around the libxml2 SAX parser. It is designed for efficient, streaming XML parsing, making it well-suited for very large XML documents from files or network sources.

## Features

- **Incremental Parsing**: Parses XML data as it is streamed, reducing memory overhead.
- **Built on libxml2 SAX Parser**: Uses a fast, low-level parsing engine.
- **Swift Concurrency**: Designed for structured concurrency using `AsyncSequence`.
- **Memory Efficient**: Handles large XML files without loading everything into memory.
- **URLSession Integration**: Simplifies parsing XML from network sources.

---

## Installation

### Swift Package Manager (SPM)

To integrate `swifty-xml-sequence` into your project, add the package dependency in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sophiestication/swifty-xml-sequence.git", .upToNextMajor(from: "1.0.0"))
]
```

## Example

For a usage example, check out the Trivia Playground or XMLEventTests contained within the Swift package.
