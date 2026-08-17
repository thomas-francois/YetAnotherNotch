//
//  NotchTabLayout.swift
//  YetAnotherNotch
//

import CoreGraphics

/// Geometry for the tab bar that wraps the physical notch cutout.
///
/// Deliberately free of SwiftUI, `Defaults`, and the `sizing/matters.swift` globals:
/// every input is passed in, so this can be verified standalone without launching
/// the app. Callers supply the runtime values.
enum NotchTabLayout {
    /// Floor on a tab's slot width. Below this the click target gets unreliable.
    static let minItemWidth: CGFloat = 24
    /// Ceiling on a tab's slot width, so a 3-tab bar doesn't render huge buttons.
    static let maxItemWidth: CGFloat = 36
    /// Space the settings gear takes in the right region: its 30pt capsule plus a 6pt gap.
    static let gearReserve: CGFloat = 36
    /// Height of a tab button's capsule, sized to fit inside the header strip.
    static let itemHeight: CGFloat = 26

    /// Width the header row actually gets, inside the open notch's horizontal padding.
    ///
    /// - Parameters:
    ///   - openNotchWidth: `openNotchSize.width`.
    ///   - cornerInset: `cornerRadiusInsets.opened.top` when corner-radius scaling is
    ///     on, otherwise `cornerRadiusInsets.opened.bottom`.
    ///   - contentPadding: the additional padding `ContentView` applies when open.
    static func usableWidth(
        openNotchWidth: CGFloat,
        cornerInset: CGFloat,
        contentPadding: CGFloat = 12
    ) -> CGFloat {
        openNotchWidth - 2 * (cornerInset + contentPadding)
    }

    /// Divides tabs around the cutout. The remainder goes left, which is the roomier
    /// side because the right region also carries the settings gear.
    static func split(count: Int) -> (left: Int, right: Int) {
        let left = (count + 1) / 2 // ceil(count / 2)
        return (left, count - left)
    }

    /// Slot width per tab, identical on both sides so the split bar reads as one bar.
    ///
    /// This is the *full* slot width including spacing — the per-side `HStack` uses
    /// `spacing: 0` and each button occupies exactly this width, with visual gaps coming
    /// from the capsule being inset inside its slot. That keeps the arithmetic exact.
    static func itemWidth(
        count: Int,
        usableWidth: CGFloat,
        cutoutWidth: CGFloat,
        reservesGear: Bool
    ) -> CGFloat {
        guard count > 0 else { return maxItemWidth }

        let side = max(0, (usableWidth - cutoutWidth) / 2)
        let leftRegion = side
        let rightRegion = max(0, side - (reservesGear ? gearReserve : 0))
        let (leftCount, rightCount) = split(count: count)

        var candidate = leftCount > 0 ? leftRegion / CGFloat(leftCount) : maxItemWidth
        if rightCount > 0 {
            candidate = min(candidate, rightRegion / CGFloat(rightCount))
        }

        return min(max(candidate, minItemWidth), maxItemWidth)
    }
}
