//
//  SSEChatParser.swift
//  YetAnotherNotch
//

import Foundation

/// Turns a server-sent-events byte stream from `/v1/chat/completions` into content deltas.
///
/// Stateful by necessity: `URLSession.bytes` respects no message framing, so a single JSON
/// object routinely arrives split across two chunks. Buffering until a newline is what
/// makes that safe — without it, roughly one delta in every long answer would be dropped
/// or corrupted.
///
/// Malformed frames are skipped rather than thrown. A model stream is not worth aborting
/// over one unparseable line, and the alternative is losing an answer that was otherwise
/// arriving fine.
struct SSEChatParser {
    private var buffer = ""
    private(set) var isFinished = false

    /// Feeds a chunk and returns whatever complete deltas it produced. An empty result is
    /// normal: it means the chunk did not finish a line.
    mutating func consume(_ chunk: String) -> [String] {
        buffer += chunk
        var deltas: [String] = []

        while let newline = buffer.firstIndex(of: "\n") {
            let line = String(buffer[buffer.startIndex..<newline])
                .trimmingCharacters(in: .whitespaces)
            buffer.removeSubrange(buffer.startIndex...newline)

            if Self.isTerminator(line) {
                isFinished = true
                continue
            }
            if let delta = Self.delta(fromLine: line) {
                deltas.append(delta)
            }
        }

        return deltas
    }

    static func isTerminator(_ line: String) -> Bool {
        line == "data: [DONE]" || line == "data:[DONE]"
    }

    /// `nil` for comments, non-`data` fields, unparseable JSON, and frames whose delta
    /// carries no text — all of which are ordinary traffic rather than errors.
    static func delta(fromLine line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }

        let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty, payload != "[DONE]" else { return nil }

        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty
        else { return nil }

        return content
    }
}
