//
//  HexColor.swift
//  YetAnotherNotch
//

import AppKit

/// Converts a colour to a `#RRGGBB` string.
///
/// Pure and dependency-free so it can be verified standalone.
enum HexColor {
    /// - Important: `NSColorSampler` hands back colours in the *display's* colour space.
    ///   Reading `.redComponent` straight off such a colour yields the wrong digits on a
    ///   wide-gamut display, so the colour is converted to sRGB first. `.deviceRGB` is
    ///   the fallback for the rare colour that cannot be represented in sRGB.
    static func hexString(from color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB)
            ?? color.usingColorSpace(.deviceRGB)

        guard let rgb else { return "#000000" }

        return String(
            format: "#%02X%02X%02X",
            channel(rgb.redComponent),
            channel(rgb.greenComponent),
            channel(rgb.blueComponent)
        )
    }

    /// Rounds rather than truncates: truncating turns 0.5 grey (127.5) into 7F when 80 is
    /// the nearer value, and the error is visible when pasting into a design tool.
    private static func channel(_ component: CGFloat) -> Int {
        let scaled = (component * 255).rounded()
        return min(255, max(0, Int(scaled)))
    }

    /// Parses `#RRGGBB` back into sRGB components in 0...1.
    ///
    /// Used to draw the swatch from the stored hex rather than from the original
    /// `NSColor`. That keeps `NSColor` — which is not `Sendable` — out of the store's
    /// published state, and means the swatch shows exactly the colour that was copied
    /// rather than the wider-gamut original.
    static func components(fromHex hex: String) -> (red: Double, green: Double, blue: Double)? {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else { return nil }

        return (
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
