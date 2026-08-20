//
//  MusicControlButton.swift
//  YetAnotherNotch
//
//  Created by Alexander on 2025-11-16.
//

import Defaults

enum MusicControlButton: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    case shuffle
    case previous
    case playPause
    case next
    case repeatMode
    case volume
    case favorite
    case goBackward
    case goForward
    case identify
    case none

    var id: String { rawValue }

    /// Empty slots are skipped at render time rather than drawn as spacers, so the row centres
    /// itself whatever this contains. Its length also seeds `musicControlSlotLimit`.
    static let defaultLayout: [MusicControlButton] = [
        .identify,
        .previous,
        .playPause,
        .next,
        .none,
        .none,
        .none
    ]

    static let minSlotCount: Int = 3
    static let maxSlotCount: Int = 7

    static let pickerOptions: [MusicControlButton] = [
        .shuffle,
        .previous,
        .playPause,
        .next,
        .repeatMode,
        .favorite,
        .volume,
        .goBackward,
        .goForward,
        .identify
    ]

    var label: String {
        switch self {
        case .shuffle:
            return "Shuffle"
        case .previous:
            return "Previous"
        case .playPause:
            return "Play/Pause"
        case .next:
            return "Next"
        case .repeatMode:
            return "Repeat"
        case .volume:
            return "Volume"
        case .favorite:
            return "Favorite"
        case .goBackward:
            return "Backward 15s"
        case .goForward:
            return "Forward 15s"
        case .identify:
            return "Identify Song"
        case .none:
            return "Empty slot"
        }
    }

    var iconName: String {
        switch self {
        case .shuffle:
            return "shuffle"
        case .previous:
            return "backward.fill"
        case .playPause:
            return "playpause"
        case .next:
            return "forward.fill"
        case .repeatMode:
            return "repeat"
        case .volume:
            return "speaker.wave.2.fill"
        case .favorite:
            return "heart"
        case .goBackward:
            return "gobackward.15"
        case .goForward:
            return "goforward.15"
        case .identify:
            // Apple's own ShazamKit symbol, which doubles as the attribution the framework asks
            // results to carry.
            return "shazam.logo"
        case .none:
            return ""
        }
    }

    var prefersLargeScale: Bool {
        self == .playPause
    }
}
