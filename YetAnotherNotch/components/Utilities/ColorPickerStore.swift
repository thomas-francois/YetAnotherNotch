//
//  ColorPickerStore.swift
//  YetAnotherNotch
//

import AppKit
import SwiftUI

/// Screen colour sampling, copying `#RRGGBB` to the clipboard.
///
/// Uses `NSColorSampler`, the system eyedropper, which samples out of process. That
/// matters: a picker built on screen capture would require the user to grant Screen
/// Recording permission, which this machine does not have.
@MainActor
final class ColorPickerStore: ObservableObject {
    static let shared = ColorPickerStore()

    /// The only stored result. Deliberately a `String` and not an `NSColor`: `NSColor`
    /// is not `Sendable`, so keeping it out of published state avoids hopping it out of
    /// the sampler's `@Sendable` callback — and the swatch drawn from this hex shows
    /// exactly what landed on the clipboard.
    @Published private(set) var lastHex: String?

    private init() {}

    /// Presents the system eyedropper.
    func pickColor() {
        // The loupe takes over the screen, so the notch loses hover. Same problem the
        // App Launcher's NSOpenPanel has.
        CustomViewCoordinator.shared.preventsAutoClose = true

        NSColorSampler().show { color in
            // Convert inside the callback so only a Sendable String crosses into the
            // MainActor hop.
            let hex = color.map { HexColor.hexString(from: $0) }
            Task { @MainActor in
                ColorPickerStore.shared.finishSession(hex: hex)
            }
        }
    }

    /// Re-copies the last picked colour, for clicking the swatch.
    func copyLastToClipboard() {
        guard let lastHex else { return }
        write(lastHex)
    }

    private func finishSession(hex: String?) {
        CustomViewCoordinator.shared.preventsAutoClose = false
        if let hex {
            lastHex = hex
            write(hex)
        }
    }

    private func write(_ hex: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hex, forType: .string)
    }
}
