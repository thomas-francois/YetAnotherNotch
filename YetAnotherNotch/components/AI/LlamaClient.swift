//
//  LlamaClient.swift
//  YetAnotherNotch
//

import Foundation

/// Read-only HTTP client for the user's `llama-server`, in either mode it runs in: plain
/// single-model, where the id is a file path, or router, where it is a models-dir entry.
///
/// Knows nothing about `Defaults`, AppKit or SwiftUI, so it can be driven from a
/// standalone harness against a real server.
struct LlamaClient: Sendable {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Convenience for the common case of a localhost router.
    init(port: Int) {
        self.init(baseURL: URL(string: "http://127.0.0.1:\(port)")!)
    }

    enum ClientError: LocalizedError, Equatable {
        case notLlamaServer
        case http(status: Int, body: String)
        case malformedResponse

        var errorDescription: String? {
            switch self {
            case .notLlamaServer:
                return "Something is listening there, but it does not look like llama-server."
            case let .http(status, body):
                return "Server returned \(status): \(body.isEmpty ? "no details" : body)"
            case .malformedResponse:
                return "The server's response could not be read."
            }
        }
    }



    // MARK: - Models

    func listModels() async throws -> [LlamaModel] {
        let (data, response) = try await session.data(for: request("/v1/models"))
        try Self.checkStatus(response, data: data)
        guard let decoded = try? JSONDecoder().decode(LlamaModelListResponse.self, from: data) else {
            throw ClientError.notLlamaServer
        }
        return decoded.models
    }

    // MARK: - Completions

    /// Non-streaming, for prompt shortcuts: the answer goes to the clipboard, so there is
    /// nothing to show progressively.
    func complete(model: String, systemPrompt: String?, userText: String) async throws -> String {
        let request = try completionRequest(
            model: model, systemPrompt: systemPrompt, userText: userText, stream: false
        )
        let (data, response) = try await session.data(for: request)
        try Self.checkStatus(response, data: data)

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else { throw ClientError.malformedResponse }

        return content
    }

    /// Streaming, for the Chat tab. A cold model load takes about twenty seconds, during
    /// which a non-streaming call is indistinguishable from a hang.
    func streamCompletion(
        model: String,
        systemPrompt: String?,
        userText: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try completionRequest(
                        model: model, systemPrompt: systemPrompt, userText: userText, stream: true
                    )
                    let (bytes, response) = try await session.bytes(for: request)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        throw ClientError.http(status: http.statusCode, body: "")
                    }

                    var parser = SSEChatParser()
                    for try await line in bytes.lines {
                        // `bytes.lines` strips the newline the parser splits on.
                        for delta in parser.consume(line + "\n") {
                            continuation.yield(delta)
                        }
                        if parser.isFinished { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func completionRequest(
        model: String,
        systemPrompt: String?,
        userText: String,
        stream: Bool
    ) throws -> URLRequest {
        var messages: [[String: String]] = []
        if let systemPrompt, !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": userText])

        var request = self.request("/v1/chat/completions")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": messages,
            "stream": stream,
            // Zero so a shortcut run twice on the same clipboard gives the same answer.
            "temperature": 0,
        ])
        return request
    }

    // MARK: - Plumbing

    private func request(_ path: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        // A cold model load takes ~20s, so the default 60s is cutting it fine for a large
        // model on a busy machine.
        request.timeoutInterval = 300
        return request
    }

    private static func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ClientError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
    }
}
