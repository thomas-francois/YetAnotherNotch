//
//  TimerWidgetView.swift
//  YetAnotherNotch
//

import SwiftUI

/// Stopwatch / countdown controls in the Utilities tab.
struct TimerWidgetView: View {
    @ObservedObject var store = UtilityTimerStore.shared

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: modeBinding) {
                ForEach(UtilityTimerStore.Mode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)

            Text(TimeFormatting.display(store.value))
                .font(.system(size: 34, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(store.state == .finished ? .red : .primary)

            if store.mode == .countdown && store.state == .idle {
                Stepper(value: minutesBinding, in: UtilityTimerStore.minimumMinutes...UtilityTimerStore.maximumMinutes) {
                    Text("\(store.countdownMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 120)
            }

            HStack(spacing: 10) {
                Button(primaryLabel) {
                    if store.state == .finished {
                        store.dismissAlarm()
                    } else {
                        store.toggle()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.effectiveAccent)

                Button("Reset") { store.reset() }
                    .disabled(store.state == .idle)
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var primaryLabel: String {
        switch store.state {
        case .idle:
            return "Start"
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        case .finished:
            return "Dismiss"
        }
    }

    private var modeBinding: Binding<UtilityTimerStore.Mode> {
        Binding(
            get: { store.mode },
            set: { store.setMode($0) }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { store.countdownMinutes },
            set: { store.countdownMinutes = $0 }
        )
    }
}
