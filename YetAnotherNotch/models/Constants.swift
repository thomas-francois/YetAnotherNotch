//
//  Constants.swift
//  YetAnotherNotch
//
//  Created by Richard Kunkli on 2024. 10. 17..
//

import SwiftUI
import Defaults

let bundleIdentifier = Bundle.main.bundleIdentifier!

let spacing: CGFloat = 16

enum HideNotchOption: String, Defaults.Serializable {
    case always
    case nowPlayingOnly
    case never
}

// Define notification names at file scope
extension Notification.Name {
    static let mediaControllerChanged = Notification.Name("mediaControllerChanged")
}

// Media controller types for selection in settings
enum MediaControllerType: String, CaseIterable, Identifiable, Defaults.Serializable {
    case nowPlaying = "Now Playing"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"

    var id: String { self.rawValue }
}

// Sneak peek styles for selection in settings
enum SneakPeekStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case standard = "Default"
    case inline = "Inline"

    var id: String { self.rawValue }
}

extension Defaults.Keys {
    // MARK: General
    static let menubarIcon = Key<Bool>("menubarIcon", default: true)
    static let showOnAllDisplays = Key<Bool>("showOnAllDisplays", default: false)
    static let automaticallySwitchDisplay = Key<Bool>("automaticallySwitchDisplay", default: true)

    // MARK: Behavior
    static let minimumHoverDuration = Key<TimeInterval>("minimumHoverDuration", default: 0.3)
    static let enableHaptics = Key<Bool>("enableHaptics", default: true)
    static let openNotchOnHover = Key<Bool>("openNotchOnHover", default: true)
    static let extendHoverArea = Key<Bool>("extendHoverArea", default: false)
    static let notchHeightMode = Key<WindowHeightMode>(
        "notchHeightMode",
        default: WindowHeightMode.matchRealNotchSize
    )
    static let nonNotchHeightMode = Key<WindowHeightMode>(
        "nonNotchHeightMode",
        default: WindowHeightMode.matchMenuBar
    )
    static let nonNotchHeight = Key<CGFloat>("nonNotchHeight", default: 32)
    static let notchHeight = Key<CGFloat>("notchHeight", default: 32)
    static let showOnLockScreen = Key<Bool>("showOnLockScreen", default: false)
    static let hideFromScreenRecording = Key<Bool>("hideFromScreenRecording", default: false)

    // MARK: Appearance
    static let settingsIconInNotch = Key<Bool>("settingsIconInNotch", default: true)
    static let lightingEffect = Key<Bool>("lightingEffect", default: true)
    static let enableShadow = Key<Bool>("enableShadow", default: true)
    static let cornerRadiusScaling = Key<Bool>("cornerRadiusScaling", default: true)
    static let hideTitleBar = Key<Bool>("hideTitleBar", default: true)

    // MARK: Media playback
    static let coloredSpectrogram = Key<Bool>("coloredSpectrogram", default: true)
    static let playerColorTinting = Key<Bool>("playerColorTinting", default: true)
    static let sliderColor = Key<SliderColorEnum>(
        "sliderUseAlbumArtColor",
        default: SliderColorEnum.white
    )
    static let enableSneakPeek = Key<Bool>("enableSneakPeek", default: false)
    static let sneakPeekStyles = Key<SneakPeekStyle>("sneakPeekStyles", default: .standard)
    static let waitInterval = Key<Double>("waitInterval", default: 3)
    static let enableLyrics = Key<Bool>("enableLyrics", default: false)
    static let musicControlSlots = Key<[MusicControlButton]>(
        "musicControlSlots",
        default: MusicControlButton.defaultLayout
    )
    static let musicControlSlotLimit = Key<Int>(
        "musicControlSlotLimit",
        default: MusicControlButton.defaultLayout.count
    )

    // MARK: Utilities
    /// Countdown length in minutes. Clamped by `UtilityTimerStore`.
    static let timerCountdownMinutes = Key<Int>("timerCountdownMinutes", default: 1)

    // MARK: App Launcher
    static let appLauncherSlots = Key<AppLauncherSlots>(
        "appLauncherSlots",
        default: AppLauncherSlots()
    )

    // MARK: Fullscreen Media Detection
    static let hideNotchOption = Key<HideNotchOption>("hideNotchOption", default: .nowPlayingOnly)

    // MARK: Media Controller
    static let mediaController = Key<MediaControllerType>("mediaController", default: defaultMediaController)

    // MARK: Accent color
    static let useCustomAccentColor = Key<Bool>("useCustomAccentColor", default: false)
    static let customAccentColorData = Key<Data?>("customAccentColorData", default: nil)

    // Helper to determine the default media controller based on NowPlaying deprecation status
    static var defaultMediaController: MediaControllerType {
        if MusicManager.shared.isNowPlayingDeprecated {
            return .appleMusic
        } else {
            return .nowPlaying
        }
    }

    static let didClearLegacyURLCacheV1 = Key<Bool>("didClearLegacyURLCache_v1", default: false)

    // MARK: AI
    /// Where the user's llama-server is. YetAnotherNotch never starts one — this is the only
    /// thing it needs to know about it.
    static let llamaServerURL = Key<String>(
        "llamaServerURL",
        default: LlamaServerAddress.defaultURLString
    )
    /// Empty means no model chosen: Chat falls back to the stub and shortcuts are disabled.
    static let llamaSelectedModel = Key<String>("llamaSelectedModel", default: "")
    static let promptShortcuts = Key<PromptShortcutSlots>(
        "promptShortcuts",
        default: PromptShortcutSlots.seeded
    )
    /// The command the AI tab offers to copy when no server is answering. Editable because
    /// every setup has a different model path and flags, and a command you can paste
    /// verbatim beats a generic example you have to translate.
    static let llamaLaunchCommand = Key<String>(
        "llamaLaunchCommand",
        default: "llama-server -m model.gguf"
    )
}
