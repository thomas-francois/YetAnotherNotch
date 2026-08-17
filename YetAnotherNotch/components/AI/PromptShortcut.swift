//
//  PromptShortcut.swift
//  YetAnotherNotch
//

import Foundation

/// A saved system prompt, run against the clipboard.
///
/// The prompt is the whole substance; name and icon exist only so the button is identifiable
/// at roughly 88 x 46 pt.
struct PromptShortcut: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var icon: String
    var systemPrompt: String

    init(id: UUID = UUID(), name: String, icon: String, systemPrompt: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
    }
}
