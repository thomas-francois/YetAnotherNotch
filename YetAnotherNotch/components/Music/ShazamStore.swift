//
//  ShazamStore.swift
//  YetAnotherNotch
//

import AppKit
import ShazamKit
import SwiftUI

/// Identifies whatever music is audible, using ShazamKit.
///
/// `SHManagedSession` does its own audio capture, so there is no `AVAudioEngine` to wire up
/// here — but it does take the microphone for the duration, which is why a run cannot overlap
/// with live transcription.
///
/// The title and artist land on the clipboard as well as on screen: the notch is a glance, and
/// what you usually want next is to paste the name somewhere.
@MainActor
final class ShazamStore: ObservableObject {
    static let shared = ShazamStore()

    struct Match: Equatable {
        let title: String
        let artist: String

        var display: String { artist.isEmpty ? title : "\(title) — \(artist)" }
    }

    enum State: Equatable {
        case idle
        case listening
        case matched(Match)
        case noMatch
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private var session: SHManagedSession?
    private var clearTask: Task<Void, Never>?

    private init() {}

    var isListening: Bool { state == .listening }

    /// Result stays up for a few seconds and then clears itself, so the music tab does not keep
    /// showing a stale answer from ten minutes ago.
    private static let resultLifetime: Duration = .seconds(12)

    func identify() async {
        // A second tap while listening cancels, which is what a single button should do.
        if isListening { return cancel() }

        clearTask?.cancel()
        guard await MicrophoneAccess.isAuthorized() else {
            flash(.failed(MicrophoneAccess.deniedMessage))
            return
        }

        state = .listening
        let session = SHManagedSession()
        self.session = session

        switch await session.result() {
        case let .match(match):
            guard let item = match.mediaItems.first else { return flash(.noMatch) }
            let found = Match(title: item.title ?? "Unknown", artist: item.artist ?? "")
            copyToClipboard(found.display)
            flash(.matched(found))
        case .noMatch:
            flash(.noMatch)
        case let .error(error, _):
            // Cancelling produces an error too; that is a user action, not a failure to report.
            flash(isCancellation(error) ? .idle : .failed(error.localizedDescription))
        }

        self.session = nil
    }

    func cancel() {
        session?.cancel()
        session = nil
        clearTask?.cancel()
        state = .idle
    }

    /// Copies the match again. It is already on the clipboard from the moment it was found; this
    /// exists so tapping the capsule does the obvious thing after something else has been copied
    /// in between.
    func copyMatch() {
        guard case let .matched(match) = state else { return }
        copyToClipboard(match.display)
    }

    // MARK: - Private

    private func flash(_ newState: State) {
        state = newState
        guard newState != .idle else { return }
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: Self.resultLifetime)
            guard !Task.isCancelled else { return }
            self?.state = .idle
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func isCancellation(_ error: Error) -> Bool {
        (error as NSError).domain == SHErrorDomain
            && (error as NSError).code == SHError.Code.matchAttemptFailed.rawValue
            || error is CancellationError
    }
}
