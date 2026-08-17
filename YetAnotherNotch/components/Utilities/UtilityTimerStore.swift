//
//  UtilityTimerStore.swift
//  YetAnotherNotch
//

import AppKit
import Defaults
import SwiftUI

/// The stopwatch / countdown engine behind the Utilities tab and the closed-notch readout.
///
/// A singleton because it must keep running while the notch is closed and the Utilities
/// tab is off-screen — it cannot live in view state.
@MainActor
final class UtilityTimerStore: ObservableObject {
    static let shared = UtilityTimerStore()

    enum Mode: String, CaseIterable, Identifiable {
        case stopwatch
        case countdown

        var id: String { rawValue }

        var title: String {
            switch self {
            case .stopwatch:
                return "Stopwatch"
            case .countdown:
                return "Countdown"
            }
        }
    }

    enum RunState {
        case idle
        case running
        case paused
        /// Countdown reached zero and is waiting to be acknowledged.
        case finished
    }

    /// Bounds on the countdown length. 1 minute is the default the user asked for.
    static let minimumMinutes = 1
    static let maximumMinutes = 180

    @Published private(set) var mode: Mode = .stopwatch
    @Published private(set) var state: RunState = .idle
    /// Elapsed time in stopwatch mode, remaining time in countdown mode.
    @Published private(set) var value: TimeInterval = 0

    /// Whether the closed notch should show a readout. A paused or finished timer still
    /// counts — losing the display on pause would be worse than useless.
    var isActive: Bool {
        state != .idle
    }

    var countdownMinutes: Int {
        get { Defaults[.timerCountdownMinutes] }
        set {
            let clamped = min(Self.maximumMinutes, max(Self.minimumMinutes, newValue))
            Defaults[.timerCountdownMinutes] = clamped
            // Retarget an idle countdown so the readout previews the new length.
            if state == .idle, mode == .countdown {
                value = TimeInterval(clamped * 60)
            }
        }
    }

    // Date anchors rather than a decrementing counter: ticker jitter then cannot
    // accumulate into drift, and a missed tick self-corrects on the next one.
    private var stopwatchStart: Date?
    private var stopwatchAccumulated: TimeInterval = 0
    private var countdownEnd: Date?

    private var ticker: Task<Void, Never>?
    private var alarmTask: Task<Void, Never>?

    private init() {
        value = 0
    }

    // MARK: - Mode

    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        reset()
        mode = newMode
        value = newMode == .countdown ? TimeInterval(countdownMinutes * 60) : 0
    }

    // MARK: - Controls

    func start() {
        switch state {
        case .running:
            return
        case .finished:
            reset()
            start()
        case .idle, .paused:
            switch mode {
            case .stopwatch:
                stopwatchStart = Date()
            case .countdown:
                // Resume from what's left when paused; otherwise a fresh full duration.
                let remaining = state == .paused ? value : TimeInterval(countdownMinutes * 60)
                countdownEnd = Date().addingTimeInterval(remaining)
            }
            state = .running
            startTicker()
        }
    }

    func pause() {
        guard state == .running else { return }
        // Fold progress into the anchors so resuming continues from here.
        refreshValue()
        if mode == .stopwatch {
            stopwatchAccumulated = value
            stopwatchStart = nil
        } else {
            countdownEnd = nil
        }
        state = .paused
        stopTicker()
    }

    func toggle() {
        state == .running ? pause() : start()
    }

    func reset() {
        stopTicker()
        alarmTask?.cancel()
        alarmTask = nil
        stopwatchStart = nil
        stopwatchAccumulated = 0
        countdownEnd = nil
        state = .idle
        value = mode == .countdown ? TimeInterval(countdownMinutes * 60) : 0
    }

    /// Acknowledges a finished countdown. Called when the notch readout is clicked.
    func dismissAlarm() {
        guard state == .finished else { return }
        reset()
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        // 0.2s rather than 1s so pressing Start updates the readout immediately instead
        // of appearing to hang for up to a second.
        // Created from a @MainActor method, so the Task inherits MainActor isolation and
        // tick() needs no explicit hop.
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard state == .running else { return }
        refreshValue()

        if mode == .countdown, value <= 0 {
            value = 0
            state = .finished
            stopTicker()
            countdownEnd = nil
            ringAlarm()
        }
    }

    private func refreshValue() {
        switch mode {
        case .stopwatch:
            let live = stopwatchStart.map { Date().timeIntervalSince($0) } ?? 0
            value = stopwatchAccumulated + live
        case .countdown:
            guard let countdownEnd else { return }
            value = max(0, countdownEnd.timeIntervalSinceNow)
        }
    }

    // MARK: - Alarm

    /// Three chimes rather than one: a single chime is easy to miss, and the persistent
    /// `finished` tint on the readout is what actually makes the timer reliable.
    private func ringAlarm() {
        alarmTask?.cancel()
        alarmTask = Task { [weak self] in
            for index in 0..<3 {
                guard !Task.isCancelled else { return }
                NSSound(named: NSSound.Name("Glass"))?.play()
                if index < 2 {
                    try? await Task.sleep(for: .milliseconds(800))
                }
            }
            self?.alarmTask = nil
        }
    }
}
