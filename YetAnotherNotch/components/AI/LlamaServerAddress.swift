//
//  LlamaServerAddress.swift
//  YetAnotherNotch
//

import Foundation

/// Turning what the user typed into a usable server URL, and a model id into something
/// readable.
///
/// Pure and Foundation-only, so both can be asserted standalone instead of hiding inside a
/// view.
enum LlamaServerAddress {
    /// llama.cpp's own default port, so a server started with no arguments is found
    /// without the user configuring anything.
    static let defaultURLString = "http://127.0.0.1:8080"

    /// `nil` when the text cannot be a server address, which the UI reports rather than
    /// silently falling back to the default — a typo the user cannot see is worse than an
    /// error they can.
    ///
    /// Accepts a bare `host:port`, because that is what people type. Strips trailing
    /// slashes so `appendingPathComponent` cannot produce `//v1/models`.
    static func url(from raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return nil }

        if !text.contains("://") {
            text = "http://" + text
        }
        while text.hasSuffix("/") {
            text.removeLast()
        }

        guard let url = URL(string: text),
              let host = url.host,
              !host.isEmpty
        else { return nil }

        return url
    }

    /// Router ids are Hugging Face paths (`owner/repo:QUANT`); plain-mode ids are absolute
    /// file paths. The trailing component is the distinguishing part of both, and the whole
    /// id is far too long for a 288 pt picker.
    static func displayName(forModelID id: String) -> String {
        guard let slash = id.lastIndex(of: "/") else { return id }
        let tail = String(id[id.index(after: slash)...])
        // A trailing slash would leave nothing to show, so fall back to the whole id.
        return tail.isEmpty ? id : tail
    }
}
