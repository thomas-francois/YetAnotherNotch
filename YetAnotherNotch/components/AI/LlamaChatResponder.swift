//
//  LlamaChatResponder.swift
//  YetAnotherNotch
//

import Foundation

/// Answers Chat questions with the model selected in the AI tab.
///
/// Captures the model id at creation rather than reading the selection mid-stream, so
/// changing models cannot swap the model out from under an answer already arriving.
struct LlamaChatResponder: ChatResponder {
    let client: LlamaClient
    let model: String

    /// No system prompt: the Chat tab is a plain question box, and an invented persona would
    /// change answers for reasons the user never asked for.
    func replyStream(to question: String, imageDataURL: String?) -> AsyncThrowingStream<String, Error> {
        client.streamCompletion(
            model: model, systemPrompt: nil, userText: question, imageDataURL: imageDataURL
        )
    }
}
