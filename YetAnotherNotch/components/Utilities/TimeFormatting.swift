//
//  TimeFormatting.swift
//  YetAnotherNotch
//

import Foundation

/// Formats a duration for the timer readout.
///
/// Pure and dependency-free so it can be verified standalone.
enum TimeFormatting {
    /// `mm:ss` below one hour, `h:mm:ss` from one hour up. Always zero-padded on the
    /// minutes and seconds so the readout doesn't jitter in width as digits change.
    ///
    /// Negative intervals clamp to zero — a countdown that overshoots its deadline
    /// between ticks must never render "-0:01".
    static func display(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
