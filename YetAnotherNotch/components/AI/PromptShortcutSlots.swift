//
//  PromptShortcutSlots.swift
//  YetAnotherNotch
//

import Defaults
import Foundation

/// The shortcut grid's persisted contents: one shortcut per slot, `nil` for empty.
///
/// Positions are fixed, exactly as in `AppLauncherSlots`. Removing slot 3 leaves a gap rather
/// than shifting slot 4 left, so muscle memory survives and reordering is always explicit.
/// Matching the launcher also means both grids behave the same way.
///
/// Mutation logic is pure — no SwiftUI, no `Defaults` reads — so it can be verified
/// standalone.
struct PromptShortcutSlots: Codable, Equatable, Defaults.Serializable {
    /// Six rather than eight: each slot needs a readable text label in roughly 278 pt of
    /// width, which allows two rows of three.
    static let count = 6

    private(set) var shortcuts: [PromptShortcut?]

    init(shortcuts: [PromptShortcut?] = Array(repeating: nil, count: PromptShortcutSlots.count)) {
        self.shortcuts = Self.normalized(shortcuts)
    }

    /// Tolerates a stored array whose length no longer matches `count`, so changing `count`
    /// later cannot crash or drop data unpredictably.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.decodeIfPresent([PromptShortcut?].self, forKey: .shortcuts) ?? []
        self.shortcuts = Self.normalized(stored)
    }

    static func normalized(_ values: [PromptShortcut?]) -> [PromptShortcut?] {
        if values.count == count { return values }
        if values.count > count { return Array(values.prefix(count)) }
        return values + Array(repeating: nil, count: count - values.count)
    }

    /// The three uses this feature exists for, so the grid is useful before the user writes
    /// anything. Each prompt insists on output-only, because the reply goes straight to the
    /// clipboard and a preamble would be pasted along with it.
    static var seeded: PromptShortcutSlots {
        PromptShortcutSlots(shortcuts: [
            PromptShortcut(
                name: "Fix",
                icon: "text.badge.checkmark",
                systemPrompt: """
                Correct spelling, grammar and punctuation in the user's text. Preserve the \
                original meaning, tone and formatting. Output only the corrected text, with \
                no commentary, preamble or quotation marks.
                """
            ),
            PromptShortcut(
                name: "Rewrite",
                icon: "arrow.triangle.2.circlepath",
                systemPrompt: """
                Rewrite the user's text to be clearer and more concise while keeping its \
                meaning and register. Output only the rewritten text, with no commentary, \
                preamble or quotation marks.
                """
            ),
            PromptShortcut(
                name: "Format",
                icon: "list.bullet.rectangle",
                systemPrompt: """
                Reformat the user's text into clean, readable structure using paragraphs and \
                lists where they help. Do not add or remove information. Output only the \
                reformatted text, with no commentary or preamble.
                """
            ),
            nil, nil, nil,
        ])
    }

    // MARK: - Reads

    var indices: Range<Int> { 0..<Self.count }

    func shortcut(at index: Int) -> PromptShortcut? {
        guard indices.contains(index) else { return nil }
        return shortcuts[index]
    }

    func isEmpty(at index: Int) -> Bool {
        shortcut(at: index) == nil
    }

    func canMoveLeft(_ index: Int) -> Bool {
        indices.contains(index) && index > 0 && !isEmpty(at: index)
    }

    func canMoveRight(_ index: Int) -> Bool {
        indices.contains(index) && index < Self.count - 1 && !isEmpty(at: index)
    }

    // MARK: - Mutations

    mutating func set(_ shortcut: PromptShortcut?, at index: Int) {
        guard indices.contains(index) else { return }
        shortcuts[index] = shortcut
    }

    mutating func remove(at index: Int) {
        set(nil, at: index)
    }

    mutating func moveLeft(_ index: Int) {
        guard canMoveLeft(index) else { return }
        shortcuts.swapAt(index, index - 1)
    }

    mutating func moveRight(_ index: Int) {
        guard canMoveRight(index) else { return }
        shortcuts.swapAt(index, index + 1)
    }

    private enum CodingKeys: String, CodingKey {
        case shortcuts
    }
}
