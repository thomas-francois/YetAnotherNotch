//
//  DimmingOverlay.swift
//  YetAnotherNotch
//

import AppKit

/// A black window laid over one display to dim it, for monitors that refuse brightness over
/// the system API.
///
/// This is not real brightness: the backlight stays where it is and this only darkens what is
/// on top of it. Contrast suffers as it gets darker, and the dimming shows up in screenshots
/// of that display. It is the only option left for a sandboxed app, though — the alternative,
/// DDC over I2C, needs IOKit access the sandbox denies.
@MainActor
final class DimmingOverlay {
    /// Never fully opaque. At 1.0 the display would be a black rectangle with no way to see
    /// the control that got you there.
    static let maxAlpha: CGFloat = 0.8

    private var window: NSWindow?

    /// `alpha` 0 removes the overlay entirely rather than leaving an invisible window around.
    func apply(alpha: CGFloat, to screen: NSScreen) {
        let clamped = min(max(alpha, 0), Self.maxAlpha)
        guard clamped > 0.001 else { return remove() }

        let window = window ?? makeWindow()
        self.window = window
        window.setFrame(screen.frame, display: false)
        window.alphaValue = clamped
        window.orderFrontRegardless()
    }

    func remove() {
        window?.orderOut(nil)
        window = nil
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .black
        window.isOpaque = false
        window.hasShadow = false
        // Clicks, scrolls and keys must reach whatever is underneath: this is a filter, not a UI.
        window.ignoresMouseEvents = true
        // Above ordinary windows and fullscreen video, which is where dimming is wanted most.
        window.level = .screenSaver
        // Follows the user across spaces, and stays out of Mission Control and window cycling.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        return window
    }
}
