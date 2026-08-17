//
//  ChatMarkdownText.swift
//  YetAnotherNotch
//

import SwiftUI

/// Renders what `ChatMarkdown` recognised, at the size the response area uses.
///
/// Block structure comes from `ChatMarkdown`; inline emphasis is left to `AttributedString`,
/// parsed `.inlineOnlyPreservingWhitespace` because the markers that open a block have
/// already been stripped and a second block pass would fight the first.
struct ChatMarkdownText: View {
    let markdown: String

    /// The response area's base size; headings step up from here.
    var baseSize: CGFloat = 11

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(ChatMarkdown.blocks(from: markdown).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: ChatMarkdown.Block) -> some View {
        switch block {
        case let .heading(level, text):
            Text(inline(text))
                .font(.system(size: headingSize(level), weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .bullet(text):
            // firstTextBaseline so a wrapped bullet lines up under its own text, not under
            // the marker.
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("•")
                    .font(.system(size: baseSize))
                    .foregroundStyle(.tertiary)
                Text(inline(text))
                    .font(.system(size: baseSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case let .numbered(label, text):
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(label)
                    .font(.system(size: baseSize))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Text(inline(text))
                    .font(.system(size: baseSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case let .paragraph(text):
            Text(inline(text))
                .font(.system(size: baseSize))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .blank:
            // Smaller than a full line: the notch is 146 pt tall and a model's blank lines
            // are generous.
            Spacer().frame(height: 3)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: baseSize + 3
        case 2: baseSize + 2
        default: baseSize + 1
        }
    }

    /// Bold, italic and inline code. Falls back to the literal text, so a malformed or
    /// half-streamed marker shows as the characters the model actually sent.
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

#Preview {
    ChatMarkdownText(markdown: """
    # Heading one
    Some **bold** and *italic* prose with `code`.

    ## Heading two
    - first bullet
    - second bullet with **emphasis**

    1. numbered one
    2. numbered two
    """)
    .padding()
    .frame(width: 380)
    .background(.black)
}
