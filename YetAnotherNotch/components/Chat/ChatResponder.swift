//
//  ChatResponder.swift
//  YetAnotherNotch
//

import Foundation

/// Produces an answer to a question, a piece at a time.
///
/// A stream rather than a single `String` because the user's `llama-server` may need about
/// twenty seconds to load a model on the first request, and YetAnotherNotch no longer controls
/// its idle-sleep setting. Without incremental output that is indistinguishable from a hang.
protocol ChatResponder: Sendable {
    func replyStream(to question: String) -> AsyncThrowingStream<String, Error>
}

/// Placeholder used when no server is reachable or no model is selected.
///
/// Deliberately says so rather than inventing an answer, and echoes the question back so it
/// is obvious the plumbing carried it through.
struct StubChatResponder: ChatResponder {
    static let notice = "No language model is connected yet."

    /// Simulated latency, so the sending state is actually observable.
    var latency: Duration = .milliseconds(400)

    func replyStream(to question: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [latency] in
                try? await Task.sleep(for: latency)
                // Yielded in pieces so the streaming path is exercised by the stub too,
                // rather than only once a real model is wired up.
                for chunk in Self.chunks(for: question) {
                    continuation.yield(chunk)
                    try? await Task.sleep(for: .milliseconds(40))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Pure, so it can be asserted standalone.
    static func chunks(for question: String) -> [String] {
        stubText(for: question)
            .split(separator: " ", omittingEmptySubsequences: false)
            .map { $0 + " " }
    }

    /// Pure, so it can be asserted standalone.
    ///
    /// Padded over several lines on purpose: the response area needs enough text to
    /// exercise scrolling and the copy button.
    static func stubText(for question: String) -> String {
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        \(notice)

        You asked:
        \(asked.isEmpty ? "(nothing)" : asked)

        Start a llama-server and choose a model in the AI tab, and its answer will appear \
        here instead of this notice. The input, submit, streaming, scrolling and copy button \
        all work already, so they can be tried out against this text.

        The response area scrolls, and Copy puts the whole answer on the clipboard.
        """
    }
}
