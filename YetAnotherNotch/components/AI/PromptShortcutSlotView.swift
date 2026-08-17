//
//  PromptShortcutSlotView.swift
//  YetAnotherNotch
//

import SwiftUI

/// One shortcut button: icon, label, and the run state.
///
/// Roughly 88 x 46 pt, so the icon carries most of the recognition and the label gets one
/// line.
struct PromptShortcutSlotView: View {
    let index: Int

    @ObservedObject var store = PromptShortcutStore.shared
    @ObservedObject var models = ModelStore.shared

    private var shortcut: PromptShortcut? { store.slots.shortcut(at: index) }
    private var isRunning: Bool { store.runningIndex == index }
    private var didSucceed: Bool { store.succeededIndex == index }
    private var failureMessage: String? {
        store.failure?.index == index ? store.failure?.message : nil
    }

    var body: some View {
        Button {
            guard shortcut != nil else {
                SettingsWindowController.shared.showWindow()
                return
            }
            Task { await store.run(at: index) }
        } label: {
            VStack(spacing: 3) {
                icon
                Text(shortcut?.name ?? "Add")
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .foregroundStyle(shortcut == nil ? .tertiary : .secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(shortcut == nil ? 0.04 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderTint, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .help(helpText)
        .animation(.smooth(duration: 0.2), value: didSucceed)
        .animation(.smooth(duration: 0.2), value: isRunning)
    }

    @ViewBuilder
    private var icon: some View {
        if isRunning {
            ProgressView().controlSize(.small)
        } else if didSucceed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
        } else if failureMessage != nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: shortcut?.icon ?? "plus")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(shortcut == nil ? .tertiary : .primary)
        }
    }

    private var borderTint: Color {
        if didSucceed { return .green.opacity(0.6) }
        if failureMessage != nil { return .orange.opacity(0.6) }
        return .white.opacity(0.12)
    }

    /// An empty slot stays enabled: tapping it is how the editor is reached. A filled slot
    /// needs a usable model, and nothing runs while another shortcut is mid-flight.
    private var isDisabled: Bool {
        guard shortcut != nil else { return false }
        return !models.hasUsableSelection || (store.runningIndex != nil && !isRunning)
    }

    private var helpText: String {
        if let failureMessage { return failureMessage }
        guard let shortcut else { return "Add a shortcut in Settings" }
        if !models.hasUsableSelection { return "No model available — check the AI tab" }
        return "Run \"\(shortcut.name)\" on the clipboard"
    }
}
