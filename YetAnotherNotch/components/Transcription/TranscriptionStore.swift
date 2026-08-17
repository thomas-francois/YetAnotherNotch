//
//  TranscriptionStore.swift
//  YetAnotherNotch
//

import AVFoundation
import AppKit
import Speech
import SwiftUI

/// Live speech-to-text through macOS's own on-device recogniser.
///
/// YetAnotherNotch bundles no model and downloads none: the OS owns the recogniser, and a
/// locale's assets are installed on first use through `AssetInventory`. Nothing leaves the
/// machine — `SpeechTranscriber` runs on device.
///
/// A singleton because the notch closes as soon as the pointer leaves it, and dictation that
/// stopped when that happened would be useless.
///
/// Requires macOS 26. The whole type is gated rather than the call sites, so nothing here has
/// to be written twice for an older fallback that this fork does not need.
@available(macOS 26, *)
@MainActor
final class TranscriptionStore: ObservableObject {
    static let shared = TranscriptionStore()

    enum State: Equatable {
        case idle
        /// Asking for the microphone, and installing the locale's assets if macOS has not
        /// already. The first run can take a while; later ones are immediate.
        case preparing
        case recording
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    /// Text the recogniser has committed to. Kept apart from `volatileText` so a revision
    /// can never rewrite something the user has already read.
    @Published private(set) var finalizedText = ""

    /// The tail still being revised, shown dimmer so it reads as provisional.
    @Published private(set) var volatileText = ""

    private var engine: AVAudioEngine?
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var converter: BufferConverter?

    private init() {}

    // MARK: - Reads

    var isRecording: Bool { state == .recording }
    var isPreparing: Bool { state == .preparing }

    var transcript: String { finalizedText + volatileText }
    var hasTranscript: Bool { !transcript.isEmpty }

    var failureMessage: String? {
        if case let .failed(message) = state { return message }
        return nil
    }

    // MARK: - Control

    func toggle() async {
        if isRecording || isPreparing {
            await stop()
        } else {
            await start()
        }
    }

    func start() async {
        guard !isRecording, !isPreparing else { return }
        state = .preparing

        guard await Self.microphoneIsAuthorized() else {
            state = .failed("YetAnotherNotch needs the microphone. Enable it in System Settings › Privacy & Security › Microphone.")
            return
        }

        guard let locale = await Self.usableLocale() else {
            state = .failed("No transcription language is available on this Mac.")
            return
        }

        do {
            // .progressiveTranscription because the point is watching words appear; the
            // batch presets only report once the utterance is over.
            let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            self.transcriber = transcriber

            // macOS installs the assets. YetAnotherNotch neither ships nor fetches a model.
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }

            guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: [transcriber]
            ) else {
                await teardown()
                state = .failed("No audio format on this Mac is compatible with transcription.")
                return
            }

            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            inputContinuation = continuation

            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer

            // Started before the engine, so no buffer is produced with nothing to read it.
            try await analyzer.start(inputSequence: stream)

            resultsTask = Task { [weak self] in
                await self?.consumeResults(from: transcriber)
            }

            try startEngine(convertingTo: analyzerFormat, yieldingTo: continuation)
            state = .recording
        } catch {
            await teardown()
            state = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        guard isRecording || isPreparing else { return }

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        inputContinuation?.finish()

        // Flushes whatever was mid-utterance into a final result, so the last few words are
        // not dropped just because the user stopped talking and clicked at once.
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await resultsTask?.value

        // Anything still provisional is the user's text too — keep it rather than discard it.
        if !volatileText.isEmpty {
            finalizedText += volatileText
            volatileText = ""
        }

        await teardown()
        state = .idle
    }

    func clear() {
        finalizedText = ""
        volatileText = ""
        if case .failed = state { state = .idle }
    }

    func copyTranscript() {
        guard hasTranscript else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
    }

    // MARK: - Results

    private func consumeResults(from transcriber: SpeechTranscriber) async {
        do {
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if result.isFinal {
                    finalizedText += text
                    volatileText = ""
                } else {
                    volatileText = text
                }
            }
        } catch {
            // A mid-session failure leaves the transcript alone: what was heard was heard.
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Audio

    private func startEngine(
        convertingTo analyzerFormat: AVAudioFormat,
        yieldingTo continuation: AsyncStream<AnalyzerInput>.Continuation
    ) throws {
        let engine = AVAudioEngine()
        self.engine = engine

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard let converter = BufferConverter(from: inputFormat, to: analyzerFormat) else {
            throw TranscriptionError.unconvertibleAudio
        }
        self.converter = converter

        // The tap runs on a real-time audio thread, so it captures only Sendable values and
        // touches no state on this actor: convert, hand off, return.
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard let converted = converter.convert(buffer) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }

        engine.prepare()
        try engine.start()
    }

    private func teardown() async {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil

        inputContinuation?.finish()
        inputContinuation = nil

        resultsTask?.cancel()
        resultsTask = nil

        analyzer = nil
        transcriber = nil
        converter = nil
    }

    // MARK: - Capabilities

    private static func microphoneIsAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    /// The user's own language when the recogniser supports it, otherwise anything it does —
    /// a transcript in the wrong language beats a tab that refuses to start.
    private static func usableLocale() async -> Locale? {
        if let match = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) {
            return match
        }
        return await SpeechTranscriber.supportedLocales.first
    }
}

@available(macOS 26, *)
enum TranscriptionError: LocalizedError {
    case unconvertibleAudio

    var errorDescription: String? {
        switch self {
        case .unconvertibleAudio:
            "This Mac's microphone format cannot be converted for transcription."
        }
    }
}

/// Resamples microphone buffers into the analyzer's format.
///
/// `@unchecked Sendable` because `AVAudioConverter` is not `Sendable` and the audio tap is its
/// only caller, serially. `AnalyzerInputConverter` would have removed the need for this
/// entirely, but it is macOS 27 and up.
private final class BufferConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init?(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return nil
        }
        self.converter = converter
        self.outputFormat = outputFormat
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // Headroom on the frame count: the analyzer's sample rate is usually lower than the
        // microphone's, but a resampler can still emit slightly more than the ratio suggests.
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, output.frameLength > 0 else { return nil }
        return output
    }
}
