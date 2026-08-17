//
//  NotchTab.swift
//  YetAnotherNotch
//

import Foundation

/// Every tab in the open notch. Declaration order is display order.
///
/// To add a tab: add a case here, give it an `icon` and a `title`, then handle it in
/// `NotchTabContent`. The compiler requires that third step — a new case makes the
/// switch in `NotchTabContent` non-exhaustive, so a tab cannot ship without content.
///
/// To remove a tab, delete its case; the compiler points at the orphaned arm.
/// To reorder, move the case.
///
/// The layout supports 3 to 10 cases. See `NotchTabLayout` for how width is divided.
enum NotchTab: String, CaseIterable, Identifiable {
    case music
    case appLauncher
    case utilities
    case terminal
    case ai
    case chat
    case transcription

    var id: String { rawValue }

    /// SF Symbol shown in the tab bar. The icon is the tab's only on-screen identifier,
    /// so it needs to read clearly at 16pt.
    var icon: String {
        switch self {
        case .music:
            return "music.note"
        case .appLauncher:
            return "square.grid.2x2"
        case .utilities:
            return "wrench.and.screwdriver"
        case .terminal:
            return "terminal"
        case .ai:
            return "sparkles"
        case .chat:
            return "bubble.left.and.bubble.right"
        case .transcription:
            return "waveform"
        }
    }

    /// Used by the placeholder and as the button's accessibility label.
    var title: String {
        switch self {
        case .music:
            return "Music"
        case .appLauncher:
            return "App Launcher"
        case .utilities:
            return "Utilities"
        case .terminal:
            return "Terminal"
        case .ai:
            return "AI"
        case .chat:
            return "Chat"
        case .transcription:
            return "Transcription"
        }
    }
}
