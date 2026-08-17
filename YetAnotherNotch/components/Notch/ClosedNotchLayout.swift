//
//  ClosedNotchLayout.swift
//  YetAnotherNotch
//

import CoreGraphics

/// Geometry for the closed notch's activity bar.
///
/// Pure and dependency-free so it can be verified standalone, and shared by
/// `ClosedNotchActivity` and `ContentView` so the two cannot disagree about widths.
enum ClosedNotchLayout {
    /// Horizontal padding around the timer readout inside its slot.
    private static let readoutPadding: CGFloat = 14

    /// Measured widths of the readout string at 13pt SF Rounded Medium with monospaced
    /// digits, on which the slot widths below are based:
    ///
    ///     "00:00"    38.4pt
    ///     "1:00:00"  48.8pt
    ///     "10:00:00" 57.4pt
    static func timerReadoutWidth(forDisplayLength length: Int) -> CGFloat {
        let text: CGFloat
        switch length {
        case ...5:
            text = 38.4   // mm:ss
        case 6...7:
            text = 48.8   // h:mm:ss
        default:
            text = 57.4   // hh:mm:ss and beyond
        }
        return (text + readoutPadding).rounded(.up)
    }

    /// Width of the AI activity slot. A symbol only — there is no percentage to show, since
    /// YetAnotherNotch does not manage downloads — so this is constant and the pill cannot
    /// twitch while work is in progress.
    static let aiIndicatorWidth: CGFloat = 30

    /// The width used by **both** side slots.
    ///
    /// - Important: the two sides must be equal. The centre gap is what lines up with the
    ///   physical notch, and it only stays centred if the slots flanking it are the same
    ///   width. Asymmetric slots shift the gap sideways and push content behind the
    ///   hardware notch, where the display has no pixels to show it — the leading
    ///   readout gets visibly truncated.
    static func sideSlotWidth(
        timerReadoutWidth: CGFloat?,
        aiIndicatorWidth: CGFloat?,
        squareSlot: CGFloat,
        musicActive: Bool
    ) -> CGFloat {
        // Leading precedence: timer, then AI, then album art. A missed alarm cannot be
        // recovered; a generation can be, by reopening the tab.
        let leading = timerReadoutWidth ?? aiIndicatorWidth ?? (musicActive ? squareSlot : 0)
        let trailing = musicActive ? squareSlot : 0
        return max(leading, trailing)
    }

    /// Width of the whole closed pill, used for the chin hit area.
    static func pillWidth(cutoutWidth: CGFloat, sideSlotWidth: CGFloat) -> CGFloat {
        cutoutWidth + 2 * sideSlotWidth + 20
    }
}
