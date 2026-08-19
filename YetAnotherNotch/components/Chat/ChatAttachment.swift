//
//  ChatAttachment.swift
//  YetAnotherNotch
//

import AppKit
import UniformTypeIdentifiers

/// An image dropped on the notch, waiting to be asked about.
///
/// Held as `Data` rather than `NSImage` so it stays `Sendable` and so the bytes that reach the
/// model are the bytes that were dropped, with no re-encoding round trip.
struct ChatAttachment: Equatable, Sendable {
    let data: Data
    /// MIME type for the data URL the vision API expects.
    let mimeType: String

    /// Guards against a 40 MB screenshot being base64-ed into a prompt. Vision models downscale
    /// anyway, so nothing is gained by sending more.
    static let maxBytes = 8 * 1024 * 1024

    /// `nil` when the bytes are not a decodable image, or are too large.
    init?(data: Data, mimeType: String) {
        guard !data.isEmpty, data.count <= Self.maxBytes, NSImage(data: data) != nil else {
            return nil
        }
        self.data = data
        self.mimeType = mimeType
    }

    /// What the OpenAI-style `image_url` field takes.
    var dataURL: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    var image: NSImage? { NSImage(data: data) }

    /// Maps a dropped file's extension to a MIME type, defaulting to PNG.
    static func mimeType(for url: URL) -> String {
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/png"
    }
}

extension ChatAttachment {
    /// Pulls an image out of a dropped item, whether it arrived as a file (Finder) or as raw
    /// image data (dragged from a browser or Preview).
    ///
    /// Async so the caller can do its UI work on the main actor instead of hopping out of
    /// `NSItemProvider`'s non-isolated completion handlers.
    static func load(from provider: NSItemProvider) async -> ChatAttachment? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = await withCheckedContinuation({ (continuation: CheckedContinuation<URL?, Never>) in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    continuation.resume(returning: url)
                }
            }) {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return ChatAttachment(data: data, mimeType: mimeType(for: url))
            }
            return nil
        }

        let data = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data else { return nil }
        // The bytes carry their own format; PNG is only the label on the data URL, and every
        // vision server sniffs the actual content anyway.
        return ChatAttachment(data: data, mimeType: "image/png")
    }
}
