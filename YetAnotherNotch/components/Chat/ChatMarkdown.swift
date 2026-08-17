//
//  ChatMarkdown.swift
//  YetAnotherNotch
//

import Foundation

/// The little of Markdown a local model actually emits: headings, bullet and numbered
/// lists, and — left to `AttributedString` — inline emphasis.
///
/// Deliberately not a full parser. Tables, block quotes, footnotes, nested lists and fenced
/// code blocks do not appear often enough in answers to a plain question to justify the code,
/// and anything unrecognised is kept as the literal text the model sent rather than swallowed.
///
/// Line-based on purpose, because the response streams in: every delta reparses the whole
/// string, so the cost has to stay linear and no rule may depend on text that has not arrived
/// yet. A half-written `**bold` is simply not bold yet.
///
/// Pure and Foundation-only, so it can be asserted standalone.
enum ChatMarkdown {
    enum Block: Equatable {
        /// `#`, `##`, `###`. Deeper headings clamp to 3 rather than being dropped — a model
        /// that opens with `####` still means "heading".
        case heading(level: Int, text: String)
        case bullet(text: String)
        /// The label is kept verbatim (`1.`, `2)`) so the model's own numbering shows,
        /// rather than being renumbered into something it did not say.
        case numbered(label: String, text: String)
        case paragraph(text: String)
        /// Kept rather than discarded, so the gap the model put between two paragraphs
        /// survives into the readout.
        case blank
    }

    static let maxHeadingLevel = 3

    static func blocks(from markdown: String) -> [Block] {
        markdown
            .components(separatedBy: "\n")
            .map(block(fromLine:))
    }

    static func block(fromLine rawLine: String) -> Block {
        // Trailing whitespace and a stray CR from \r\n would otherwise end up inside the text.
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return .blank }

        if let heading = heading(from: line) { return heading }
        if let bullet = bullet(from: line) { return bullet }
        if let numbered = numbered(from: line) { return numbered }
        return .paragraph(text: line)
    }

    // MARK: - Line kinds

    private static func heading(from line: String) -> Block? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty else { return nil }

        let rest = line.dropFirst(hashes.count)
        // A space is required, so `#hashtag` stays prose rather than becoming a heading.
        guard rest.first == " " else { return nil }

        let text = rest.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        return .heading(level: min(hashes.count, maxHeadingLevel), text: text)
    }

    private static func bullet(from line: String) -> Block? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            let text = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return .bullet(text: text)
        }
        return nil
    }

    private static func numbered(from line: String) -> Block? {
        let digits = line.prefix(while: \.isNumber)
        // Bounded so a long number cannot be mistaken for a list label.
        guard !digits.isEmpty, digits.count <= 3 else { return nil }

        let afterDigits = line.dropFirst(digits.count)
        guard let separator = afterDigits.first, separator == "." || separator == ")" else {
            return nil
        }

        let rest = afterDigits.dropFirst()
        guard rest.first == " " else { return nil }

        let text = rest.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        return .numbered(label: "\(digits)\(separator)", text: text)
    }
}
