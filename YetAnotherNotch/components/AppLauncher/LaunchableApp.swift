//
//  LaunchableApp.swift
//  YetAnotherNotch
//

import AppKit

/// An application resolved from a bundle identifier.
///
/// A bundle identifier is the only thing the launcher stores. Resolution goes through
/// LaunchServices, which works from inside the sandbox and — unlike a stored path —
/// keeps working when the app is moved, renamed, or self-updates.
///
/// Returns `nil` when the identifier no longer resolves (app uninstalled, or not
/// registered with LaunchServices). Callers render that as the Unavailable state.
struct LaunchableApp {
    let bundleIdentifier: String
    let url: URL
    let name: String
    let icon: NSImage

    init?(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        self.bundleIdentifier = bundleIdentifier
        self.url = url
        self.name = Self.displayName(for: url)
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }

    /// The app's own declared display name, preferring localized values.
    ///
    /// `FileManager.displayName(atPath:)` is not usable on its own: it appends ".app"
    /// whenever the user has "show all filename extensions" enabled in Finder, which
    /// would put a stray extension on every launcher label.
    private static func displayName(for url: URL) -> String {
        let bundle = Bundle(url: url)
        let candidates = [
            bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.infoDictionary?["CFBundleDisplayName"] as? String,
            bundle?.localizedInfoDictionary?["CFBundleName"] as? String,
            bundle?.infoDictionary?["CFBundleName"] as? String,
            FileManager.default.displayName(atPath: url.path),
        ]

        let name = candidates
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? url.deletingPathExtension().lastPathComponent

        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
