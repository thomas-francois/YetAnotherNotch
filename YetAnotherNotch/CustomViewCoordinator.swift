//
//  CustomViewCoordinator.swift
//  YetAnotherNotch
//
//  Created by Alexander on 2024-11-20.
//

import AppKit
import Combine
import Defaults
import SwiftUI

@MainActor
class CustomViewCoordinator: ObservableObject {
    static let shared = CustomViewCoordinator()

    @AppStorage("musicLiveActivityEnabled") var musicLiveActivityEnabled: Bool = true

    /// Which tab the open notch is showing, and the tab it will reopen on.
    ///
    /// `close()` leaves this alone, so the notch returns to whatever you last used. Not
    /// persisted, which makes that memory session-scoped: a relaunch starts on `.music`.
    @Published var selectedTab: NotchTab = .music

    /// Set while a modal panel owned by notch content is on screen (currently the App
    /// Launcher's app picker). Guards only the hover-exit close in `ContentView`, never
    /// `CustomViewModel.close()` — explicit closes must still work.
    @Published var preventsAutoClose: Bool = false

    /// Set by notch content that needs keyboard input (currently only the Chat tab).
    /// `YetAnotherNotchSkyLightWindow` observes this to allow key status, which it otherwise
    /// refuses so clicks never pull focus from the app underneath.
    @Published var wantsKeyFocus: Bool = false

    // MARK: - Display selection

    /// Legacy name-based storage, kept only to migrate old installs to UUIDs.
    @AppStorage("preferred_screen_name") private var legacyPreferredScreenName: String?

    @AppStorage("preferred_screen_uuid") var preferredScreenUUID: String? {
        didSet {
            if let uuid = preferredScreenUUID {
                selectedScreenUUID = uuid
            }
            NotificationCenter.default.post(name: Notification.Name.selectedScreenChanged, object: nil)
        }
    }

    @Published var selectedScreenUUID: String = NSScreen.main?.displayUUID ?? ""

    private init() {
        // Migrate name-based display preference to UUID-based storage.
        if preferredScreenUUID == nil, let legacyName = legacyPreferredScreenName {
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                preferredScreenUUID = uuid
                NSLog("✅ Migrated display preference from name '\(legacyName)' to UUID '\(uuid)'")
            } else {
                preferredScreenUUID = NSScreen.main?.displayUUID
                NSLog("⚠️ Could not find display named '\(legacyName)', falling back to main screen")
            }
            legacyPreferredScreenName = nil
        } else if preferredScreenUUID == nil {
            preferredScreenUUID = NSScreen.main?.displayUUID
        }

        selectedScreenUUID = preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""
    }

    // MARK: - Sneak peek
    //
    // Two mutually exclusive presentations of "the track just changed", picked by
    // Defaults[.sneakPeekStyles]:
    //   .standard — a line of text slides out below the closed notch
    //   .inline   — the closed notch itself widens to hold title and artist

    private var sneakPeekDuration: TimeInterval = 1.5
    private var sneakPeekTask: Task<Void, Never>?
    private var inlineExpansionTask: Task<Void, Never>?

    @Published var sneakPeekVisible: Bool = false {
        didSet {
            if sneakPeekVisible {
                scheduleSneakPeekHide(after: sneakPeekDuration)
            } else {
                sneakPeekTask?.cancel()
            }
        }
    }

    @Published var inlineExpansionVisible: Bool = false {
        didSet {
            if inlineExpansionVisible {
                inlineExpansionTask?.cancel()
                inlineExpansionTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    guard let self, !Task.isCancelled else { return }
                    self.toggleInlineExpansion(status: false)
                }
            } else {
                inlineExpansionTask?.cancel()
            }
        }
    }

    func toggleSneakPeek(status: Bool, duration: TimeInterval = 1.5) {
        sneakPeekDuration = duration
        Task { @MainActor in
            withAnimation(.smooth) {
                self.sneakPeekVisible = status
            }
        }
    }

    func toggleInlineExpansion(status: Bool) {
        Task { @MainActor in
            withAnimation(.smooth) {
                self.inlineExpansionVisible = status
            }
        }
    }

    private func scheduleSneakPeekHide(after duration: TimeInterval) {
        sneakPeekTask?.cancel()
        sneakPeekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    self.toggleSneakPeek(status: false)
                    self.sneakPeekDuration = 1.5
                }
            }
        }
    }
}
