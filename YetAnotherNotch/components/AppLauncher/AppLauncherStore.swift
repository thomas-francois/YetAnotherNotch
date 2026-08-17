//
//  AppLauncherStore.swift
//  YetAnotherNotch
//

import AppKit
import Defaults
import SwiftUI
import UniformTypeIdentifiers

/// Owns the launcher's data and the two side-effecting operations: presenting the app
/// picker and launching an app.
///
/// Deliberately knows nothing about the notch's open/closed state — the view decides
/// when to close. That keeps notch lifecycle in one place.
@MainActor
final class AppLauncherStore: ObservableObject {
    static let shared = AppLauncherStore()

    @Published private(set) var slots: AppLauncherSlots
    /// Set briefly when a launch fails, so the slot can show it went wrong.
    @Published private(set) var failedSlot: Int?

    /// Resolving through LaunchServices on every SwiftUI re-render would be wasteful,
    /// so resolved apps are cached by bundle identifier.
    private var resolved: [String: LaunchableApp] = [:]
    private var failureResetTask: Task<Void, Never>?

    private init() {
        slots = Defaults[.appLauncherSlots]
    }

    // MARK: - Reads

    func app(at index: Int) -> LaunchableApp? {
        guard let bundleIdentifier = slots.bundleIdentifier(at: index) else { return nil }
        if let cached = resolved[bundleIdentifier] { return cached }
        guard let app = LaunchableApp(bundleIdentifier: bundleIdentifier) else { return nil }
        resolved[bundleIdentifier] = app
        return app
    }

    /// A slot that holds an identifier which no longer resolves to an installed app.
    func isUnavailable(at index: Int) -> Bool {
        !slots.isEmpty(at: index) && app(at: index) == nil
    }

    // MARK: - Mutations

    func remove(at index: Int) {
        var updated = slots
        updated.remove(at: index)
        persist(updated)
    }

    func moveLeft(_ index: Int) {
        var updated = slots
        updated.moveLeft(index)
        persist(updated)
    }

    func moveRight(_ index: Int) {
        var updated = slots
        updated.moveRight(index)
        persist(updated)
    }

    private func persist(_ updated: AppLauncherSlots) {
        slots = updated
        Defaults[.appLauncherSlots] = updated
    }

    // MARK: - Picker

    /// Presents the application picker for `index` and stores the choice.
    ///
    /// Synchronous: it returns once the panel has been dismissed, which lets the caller
    /// decide what the notch should do next.
    func chooseApp(for index: Int) {
        let coordinator = CustomViewCoordinator.shared
        coordinator.preventsAutoClose = true
        defer { coordinator.preventsAutoClose = false }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        // Without this an .app is navigated into rather than selected.
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an application"
        panel.prompt = "Add"

        // The app is LSUIElement, so it must come forward for the panel to be usable.
        // Same dance as SettingsWindowController.showWindow().
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let response = panel.runModal()
        NSApp.setActivationPolicy(previousPolicy)

        guard response == .OK, let url = panel.url else { return }
        guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else {
            NSLog("AppLauncher: \(url.lastPathComponent) has no bundle identifier; ignoring")
            return
        }

        var updated = slots
        updated.set(bundleIdentifier, at: index)
        persist(updated)
    }

    // MARK: - Launch

    /// Launches the app in `index`, calling `onSuccess` only if it actually started.
    ///
    /// The caller closes the notch from `onSuccess`, so a failed launch leaves the notch
    /// open and visibly marked rather than collapsing as though it worked.
    func launch(at index: Int, onSuccess: @escaping () -> Void) {
        guard let app = app(at: index) else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        // The async form keeps `onSuccess` inside a MainActor-isolated Task, so the
        // closure never crosses into a @Sendable context.
        Task { @MainActor [weak self] in
            do {
                _ = try await NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)
                onSuccess()
            } catch {
                NSLog("AppLauncher: failed to launch \(app.bundleIdentifier): \(error.localizedDescription)")
                self?.flagFailure(at: index)
            }
        }
    }

    func revealInFinder(at index: Int) {
        guard let app = app(at: index) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([app.url])
    }

    private func flagFailure(at index: Int) {
        failedSlot = index
        failureResetTask?.cancel()
        failureResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.failedSlot = nil }
        }
    }
}
