//
//  PromptShortcutStore.swift
//  YetAnotherNotch
//

import AppKit
import Defaults
import SwiftUI

/// Saved prompts, and the one side effect that matters: run a prompt against the clipboard
/// and put the answer back.
///
/// A singleton so a run survives the notch closing — a first request can take about twenty
/// seconds while the user's server loads a model, far longer than the notch stays open.
@MainActor
final class PromptShortcutStore: ObservableObject {
    static let shared = PromptShortcutStore()

    @Published private(set) var slots: PromptShortcutSlots

    /// Only one run at a time. A second reply racing the first to the clipboard would make
    /// the result unpredictable.
    @Published private(set) var runningIndex: Int?

    /// Drives the checkmark. The answer itself is deliberately not shown: the clipboard is
    /// the product, and a result panel would not fit the tab.
    @Published private(set) var succeededIndex: Int?

    @Published private(set) var failure: FailureState?

    struct FailureState: Equatable {
        let index: Int
        let message: String
    }

    private var flashTask: Task<Void, Never>?

    private init() {
        slots = Defaults[.promptShortcuts]
    }


    // MARK: - Running

    func run(at index: Int) async {
        guard runningIndex == nil,
              let shortcut = slots.shortcut(at: index)
        else { return }

        let modelStore = ModelStore.shared
        guard modelStore.hasUsableSelection, let client = modelStore.client else {
            flashFailure(index, "No model available. Check the AI tab.")
            return
        }

        let pasteboard = NSPasteboard.general
        guard let input = pasteboard.string(forType: .string),
              !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            flashFailure(index, "Clipboard is empty. Copy some text first.")
            return
        }

        runningIndex = index
        failure = nil
        succeededIndex = nil

        do {
            let reply = try await client.complete(
                model: modelStore.selectedModelID,
                systemPrompt: shortcut.systemPrompt,
                userText: input
            )
            let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            runningIndex = nil

            guard !trimmed.isEmpty else {
                // Writing an empty string would silently destroy the input.
                flashFailure(index, "The model returned nothing. Clipboard left alone.")
                return
            }
            write(trimmed)
            flashSuccess(index)
        } catch {
            // The clipboard is deliberately untouched on failure, so a failed run can never
            // destroy what the user copied.
            runningIndex = nil
            flashFailure(index, error.localizedDescription)
            modelStore.markUnreachable(error.localizedDescription)
        }
    }

    private func write(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func flashSuccess(_ index: Int) {
        succeededIndex = index
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            self?.succeededIndex = nil
        }
    }

    private func flashFailure(_ index: Int, _ message: String) {
        failure = FailureState(index: index, message: message)
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.failure = nil
        }
    }

    // MARK: - Mutations

    func set(_ shortcut: PromptShortcut?, at index: Int) {
        var updated = slots
        updated.set(shortcut, at: index)
        persist(updated)
    }

    func remove(at index: Int) {
        var updated = slots
        updated.remove(at: index)
        persist(updated)
    }

    func moveLeft(_ index: Int) {
        var updated = slots
        updated.moveLeft(index)
        persist(updated)
    }

    func moveRight(_ index: Int) {
        var updated = slots
        updated.moveRight(index)
        persist(updated)
    }

    private func persist(_ updated: PromptShortcutSlots) {
        slots = updated
        Defaults[.promptShortcuts] = updated
    }
}
