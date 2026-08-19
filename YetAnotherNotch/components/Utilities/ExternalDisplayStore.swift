//
//  ExternalDisplayStore.swift
//  YetAnotherNotch
//

import AppKit
import CoreGraphics
import SwiftUI

/// The first external display, and its backlight brightness.
///
/// Brightness goes through `DisplayServices`, a private framework, because there is no public
/// API for it. Loading it is the same trick `NowPlayingController` already uses for
/// `MediaRemote`, and it works from inside the sandbox for the same reason: reading a system
/// framework is allowed.
///
/// `DisplayServicesCanChangeBrightness` is the honest gate. Plenty of third-party monitors only
/// accept brightness over DDC/I2C, which a sandboxed app cannot reach, and for those this
/// reports `false` so the widget can say so instead of showing a slider that does nothing.
@MainActor
final class ExternalDisplayStore: ObservableObject {
    static let shared = ExternalDisplayStore()

    /// How brightness reaches a given display.
    enum Mechanism: Equatable {
        /// Real backlight control through `DisplayServices`.
        case system
        /// A black window over the display, for monitors that refuse the system API. Dims what
        /// is drawn rather than the backlight — see `DimmingOverlay`.
        case overlay
    }

    struct Display: Equatable {
        let id: CGDirectDisplayID
        let name: String
        let mechanism: Mechanism
    }

    /// `nil` when only the built-in screen is attached, which is what hides the widget.
    @Published private(set) var display: Display?

    /// 0...1. Meaningless when `display` is nil or cannot take brightness.
    @Published private(set) var brightness: Float = 0

    private var observer: Any?
    private let overlay = DimmingOverlay()

    private init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // `queue: .main` guarantees the isolation; the closure's type cannot say so.
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - Reads

    var isConnected: Bool { display != nil }

    // MARK: - Refresh

    /// Called on init and whenever the screen layout changes, which is how plugging a monitor
    /// in or out makes the widget appear or disappear.
    func refresh() {
        guard let id = Self.firstExternalDisplayID() else {
            // Unplugging must take the overlay with it, or a black window is left orphaned on
            // whatever display inherits that frame.
            overlay.remove()
            display = nil
            return
        }

        let canSet = Self.canChangeBrightness?(id) ?? false
        let mechanism: Mechanism = canSet ? .system : .overlay
        let previous = display

        display = Display(id: id, name: Self.name(for: id), mechanism: mechanism)

        switch mechanism {
        case .system:
            brightness = Self.readBrightness(id) ?? 0
        case .overlay:
            // The overlay cannot be read back, so a fresh display starts undimmed. A display
            // that is merely being re-reported (resolution change, wake) keeps its level.
            if previous?.id != id { brightness = 1 }
            applyOverlay()
        }
    }

    // MARK: - Writes

    func setBrightness(_ value: Float) {
        guard let display else { return }
        let clamped = min(max(value, 0), 1)

        switch display.mechanism {
        case .system:
            guard let set = Self.setBrightnessFn, set(display.id, clamped) == 0 else { return }
            brightness = clamped
        case .overlay:
            brightness = clamped
            applyOverlay()
        }
    }

    /// Brightness 1 means no overlay; 0 means as dark as `DimmingOverlay` allows.
    private func applyOverlay() {
        guard let display, display.mechanism == .overlay, let screen = Self.screen(for: display.id)
        else { return overlay.remove() }
        overlay.apply(alpha: DimmingOverlay.maxAlpha * CGFloat(1 - brightness), to: screen)
    }

    // MARK: - Displays

    /// The first non-built-in display.
    ///
    /// ponytail: first-match only. Two external monitors would show one slider controlling
    /// whichever CoreGraphics lists first; make it a picker if that ever matters.
    private static func firstExternalDisplayID() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        return ids.first { CGDisplayIsBuiltin($0) == 0 }
    }

    private static func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
                .uint32Value == id
        }
    }

    private static func name(for id: CGDirectDisplayID) -> String {
        screen(for: id)?.localizedName ?? "External Display"
    }

    // MARK: - DisplayServices

    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanFn = @convention(c) (CGDirectDisplayID) -> Bool

    /// Resolved once. `nil` throughout if the framework or a symbol ever moves, which leaves
    /// `canSetBrightness` false and the widget honest rather than crashing.
    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    private static let getBrightnessFn: GetFn? = symbol("DisplayServicesGetBrightness")
    private static let setBrightnessFn: SetFn? = symbol("DisplayServicesSetBrightness")
    private static let canChangeBrightness: CanFn? = symbol("DisplayServicesCanChangeBrightness")

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private static func readBrightness(_ id: CGDirectDisplayID) -> Float? {
        guard let get = getBrightnessFn else { return nil }
        var value: Float = 0
        guard get(id, &value) == 0 else { return nil }
        return value
    }
}
