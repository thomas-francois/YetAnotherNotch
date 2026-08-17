//
//  PromptShortcutsView.swift
//  YetAnotherNotch
//

import SwiftUI

/// Two rows of three shortcut buttons.
///
/// Deliberately captionless: run state is carried by the buttons themselves — a spinner,
/// a checkmark, or an orange badge whose tooltip holds the reason — so a status line
/// underneath would only repeat them.
struct PromptShortcutsView: View {
    @ObservedObject var store = PromptShortcutStore.shared

    private static let columnCount = 3

    /// Rows of slot indices, so the grid can be laid out as nested stacks. `LazyVGrid` sizes
    /// rows to their content, which left a gap under the last row once the caption went; two
    /// `HStack`s inside a filling `VStack` share the height instead.
    private var rows: [[Int]] {
        let all = Array(store.slots.indices)
        return stride(from: 0, to: all.count, by: Self.columnCount).map { start in
            Array(all[start..<min(start + Self.columnCount, all.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.caption)
                Text("Clipboard")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { index in
                            PromptShortcutSlotView(index: index)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
