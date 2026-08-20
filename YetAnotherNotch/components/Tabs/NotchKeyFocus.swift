//
//  NotchKeyFocus.swift
//  YetAnotherNotch
//

import AppKit
import SwiftUI

/// Everything a tab with a text field has to do so the notch stays usable.
///
/// Three things, and leaving out any one of them breaks something:
///
/// - ask for key focus, because the notch window refuses it by default and a field would
///   otherwise take no keystrokes;
/// - hold `preventsAutoClose` only while the field actually has focus, so hover-exit does not
///   close the notch mid-sentence;
/// - close on the window resigning key, because a focused field keeps `preventsAutoClose` set
///   even after submitting, and without this the notch sits open forever.
///
/// That last one is the reason this exists as a modifier rather than being written out per tab:
/// the To-Do tab shipped without it and stuck open the moment a task was added.
private struct NotchKeyFocusModifier: ViewModifier {
    let fieldFocused: Bool

    @EnvironmentObject private var vm: CustomViewModel
    @ObservedObject private var coordinator = CustomViewCoordinator.shared

    func body(content: Content) -> some View {
        content
            .onAppear { coordinator.wantsKeyFocus = true }
            .onDisappear {
                coordinator.wantsKeyFocus = false
                coordinator.preventsAutoClose = false
            }
            .onChange(of: fieldFocused) { _, focused in
                coordinator.preventsAutoClose = focused
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
                guard note.object is YetAnotherNotchSkyLightWindow, vm.notchState == .open else { return }
                coordinator.preventsAutoClose = false
                vm.close()
            }
    }
}

extension View {
    /// Applies the notch's keyboard-focus handshake. Pass the tab's `@FocusState` value.
    func notchKeyFocus(fieldFocused: Bool) -> some View {
        modifier(NotchKeyFocusModifier(fieldFocused: fieldFocused))
    }
}
