//
//  TranscriptionView.swift
//  YetAnotherNotch
//

import SwiftUI

/// The Transcription tab: start, stop, and read what was heard.
///
/// The Speech API this uses arrived in macOS 26, and the project's deployment target is 14, so
/// the panel is gated and older systems get told why rather than shown a dead button.
struct TranscriptionView: View {
    var body: some View {
        Group {
            if #available(macOS 26, *) {
                TranscriptionPanel()
            } else {
                unsupported
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var unsupported: some View {
        VStack(spacing: 6) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Transcription needs macOS 26")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("It uses the on-device recogniser added in that release.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@available(macOS 26, *)
private struct TranscriptionPanel: View {
    @ObservedObject var store = TranscriptionStore.shared

    @State private var justCopied = false

    var body: some View {
        VStack(spacing: 6) {
            controlRow
            transcriptArea
        }
        .animation(.smooth(duration: 0.2), value: justCopied)
        .animation(.smooth(duration: 0.2), value: store.isRecording)
    }

    // MARK: - Controls

    private var controlRow: some View {
        HStack(spacing: 8) {
            Button {
                Task { await store.toggle() }
            } label: {
                Label(
                    store.isRecording ? "Stop" : (store.isPreparing ? "Starting…" : "Start"),
                    systemImage: store.isRecording ? "stop.fill" : "mic.fill"
                )
                .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(store.isRecording ? .red : .effectiveAccent)
            .controlSize(.small)
            .disabled(store.isPreparing)

            if store.isRecording {
                // A steady dot rather than a spinner: recording is a state, not progress.
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
            } else if store.isPreparing {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer(minLength: 0)

            if store.hasTranscript {
                Button {
                    store.copyTranscript()
                    flashCopied()
                } label: {
                    Label(justCopied ? "Copied" : "Copy", systemImage: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.secondary)
                .help("Copy the transcript to the clipboard")

                Button {
                    store.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.secondary)
                .help("Clear the transcript")
            }
        }
    }

    // MARK: - Transcript

    private var transcriptArea: some View {
        ScrollView {
            Group {
                if let failure = store.failureMessage {
                    Text(failure)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if store.transcript.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(.tertiary)
                } else {
                    // Provisional text is dimmer, so a word that is about to be revised does
                    // not look as settled as one that will not.
                    Text(store.finalizedText)
                        .foregroundStyle(.secondary)
                    + Text(store.volatileText)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: 11))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var placeholderText: String {
        if store.isPreparing {
            return "Preparing… the first run installs the language, which can take a moment."
        }
        return store.isRecording ? "Listening…" : "Press Start and speak."
    }

    private func flashCopied() {
        justCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            justCopied = false
        }
    }
}
