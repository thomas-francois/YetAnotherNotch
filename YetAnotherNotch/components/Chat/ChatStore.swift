//
//  ChatStore.swift
//  YetAnotherNotch
//

import AppKit
import SwiftUI

/// State for the Chat tab.
///
/// A singleton so the draft question and last answer survive the notch closing — combined
/// with remembered tab selection, re-hovering returns to Chat with everything intact.
@MainActor
final class ChatStore: ObservableObject {
    static let shared = ChatStore()

    @Published var question: String = ""
    @Published private(set) var response: String = ""
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    /// Overridable for previews and harnesses; `nil` means "resolve from the current model
    /// selection at submit time".
    private let overrideResponder: ChatResponder?

    init(responder: ChatResponder? = nil) {
        self.overrideResponder = responder
    }

    /// Resolved per submission rather than stored, so choosing a model in the AI tab takes
    /// effect on the next question without rebuilding this store.
    private var responder: ChatResponder {
        if let overrideResponder { return overrideResponder }
        let store = ModelStore.shared
        guard store.hasUsableSelection, let client = store.client else {
            return StubChatResponder()
        }
        return LlamaChatResponder(client: client, model: store.selectedModelID)
    }

    var canSubmit: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var hasResponse: Bool {
        !response.isEmpty
    }

    func submit() {
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty, !isSending else { return }

        // The question deliberately stays in the field: the point of this tab is to read
        // the answer alongside what was asked.
        isSending = true
        errorMessage = nil
        response = ""

        Task { [asked] in
            do {
                for try await delta in responder.replyStream(to: asked) {
                    // Appended as they arrive, so a slow first response shows progress
                    // rather than an empty box.
                    response += delta
                }
            } catch {
                errorMessage = error.localizedDescription
                // Only when a real server was used — a stub failure says nothing about
                // reachability.
                if ModelStore.shared.hasUsableSelection {
                    ModelStore.shared.markUnreachable(error.localizedDescription)
                }
            }
            isSending = false
        }
    }

    func copyResponse() {
        guard hasResponse else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(response, forType: .string)
    }

    func clear() {
        question = ""
        response = ""
        errorMessage = nil
    }
}
