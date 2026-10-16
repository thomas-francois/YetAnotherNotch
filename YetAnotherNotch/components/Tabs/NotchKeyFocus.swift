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
            .onAppear { coordinator.keyFocusScreenUUID = vm.screenUUID }
            .onDisappear {
                // Only release our own request; another display may have taken it since.
                if coordinator.keyFocusScreenUUID == vm.screenUUID {
                    coordinator.keyFocusScreenUUID = nil
                }
                coordinator.preventsAutoClose = false
            }
            .onChange(of: fieldFocused) { _, focused in
                coordinator.preventsAutoClose = focused
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
                // Our own window only: another display's notch window resigning is not a reason
                // to close this one. And only while we still hold the focus request: switching
                // to another tab releases it first, and the resign that release causes arrives
                // while this view is still fading out — closing then shut the notch on every
                // tab switch away from To-Do or Chat.
                guard let window = note.object as? YetAnotherNotchSkyLightWindow,
                      window.screen?.displayUUID == vm.screenUUID,
                      coordinator.keyFocusScreenUUID == vm.screenUUID,
                      vm.notchState == .open else { return }
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
