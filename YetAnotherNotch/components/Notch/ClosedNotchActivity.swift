//
//  ClosedNotchActivity.swift
//  YetAnotherNotch
//

import Defaults
import SwiftUI

/// What the closed notch shows around the physical cutout.
///
/// Replaces the old `MusicLiveActivity`, which hardcoded album-art-left /
/// spectrum-right. Three composable positions instead, so a new always-visible
/// indicator is an added case rather than another branch of an if/else chain:
///
///     [ leading ] [ notch cutout ] [ trailing ]
///
/// Leading precedence is timer over AI over album art: a running timer is time-critical and
/// transient, AI work is transient but recoverable by reopening the tab, and album art is
/// decorative and one hover away.
struct ClosedNotchActivity: View {
    @EnvironmentObject var vm: CustomViewModel
    @ObservedObject var coordinator = CustomViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var timer = UtilityTimerStore.shared
    @ObservedObject var shortcuts = PromptShortcutStore.shared
    @ObservedObject var chat = ChatStore.shared

    let albumArtNamespace: Namespace.ID

    /// Music is worth showing in the closed notch.
    static func musicIsActive(_ musicManager: MusicManager, _ coordinator: CustomViewCoordinator) -> Bool {
        (musicManager.isPlaying || !musicManager.isPlayerIdle) && coordinator.musicLiveActivityEnabled
    }

    private var showsMusic: Bool {
        Self.musicIsActive(musicManager, coordinator)
    }

    /// AI work worth showing from outside the notch: a clipboard shortcut running, or a chat
    /// answer still streaming.
    ///
    /// Static, and shared with `ContentView`'s chin, for exactly the reason `musicIsActive`
    /// is: both must agree on whether the leading slot is occupied, or the chin hit area and
    /// the visible pill drift apart. `sideSlotWidth` deliberately has no default argument so
    /// neither call site can silently pass `nil` — a second hand-written copy of this
    /// condition would reintroduce the same drift by another route.
    @MainActor
    static func aiIsWorking(_ shortcuts: PromptShortcutStore, _ chat: ChatStore) -> Bool {
        shortcuts.runningIndex != nil || chat.isSending
    }

    private var aiIsWorking: Bool {
        Self.aiIsWorking(shortcuts, chat)
    }

    private var squareSlot: CGFloat {
        max(0, vm.effectiveClosedNotchHeight - 12)
    }

    /// Both side slots use this same width, which is what keeps the centre gap aligned
    /// with the physical notch. See `ClosedNotchLayout.sideSlotWidth`.
    private var sideSlot: CGFloat {
        ClosedNotchLayout.sideSlotWidth(
            timerReadoutWidth: timer.isActive
                ? ClosedNotchLayout.timerReadoutWidth(
                    forDisplayLength: TimeFormatting.display(timer.value).count)
                : nil,
            aiIndicatorWidth: aiIsWorking ? ClosedNotchLayout.aiIndicatorWidth : nil,
            squareSlot: squareSlot,
            musicActive: showsMusic
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            leading

            // Spans the physical notch. Widens when the inline sneak peek is showing.
            Rectangle()
                .fill(.black)
                .overlay(inlineSneakPeek)
                .frame(
                    width: (coordinator.inlineExpansionVisible && Defaults[.sneakPeekStyles] == .inline)
                        ? 380
                        : vm.closedNotchSize.width + -cornerRadiusInsets.closed.top
                )

            trailing
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }

    // MARK: - Leading

    @ViewBuilder
    private var leading: some View {
        if timer.isActive {
            Text(TimeFormatting.display(timer.value))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timerTint)
                .frame(width: sideSlot, height: squareSlot)
                .contentShape(Rectangle())
                // Tapping the readout opens the notch on the tab the timer lives in,
                // rather than the default .music. A finished countdown is also
                // acknowledged, so the tap both silences the alarm and lands you on the
                // widget to start another.
                .onTapGesture {
                    if timer.state == .finished {
                        timer.dismissAlarm()
                    }
                    withAnimation(CustomViewModel.openAnimation) {
                        // The To-Do wheel starts this same countdown, so the readout has to open
                        // whichever tab owns it. Landing in Utilities mid-task was misleading.
                        vm.open(on: TodoStore.shared.ownsMirroredCountdown ? .todo : .utilities)
                    }
                }
        } else if aiIsWorking {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: sideSlot, height: squareSlot)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(CustomViewModel.openAnimation) {
                        vm.open(on: .ai)
                    }
                }
        } else if showsMusic {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .clipped()
                .clipShape(
                    RoundedRectangle(cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed)
                )
                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                .frame(width: squareSlot, height: squareSlot)
                .frame(width: sideSlot, height: squareSlot)
        } else {
            Color.clear.frame(width: sideSlot, height: squareSlot)
        }
    }

    private var timerTint: Color {
        switch timer.state {
        case .finished:
            return .red
        case .paused:
            return .gray
        default:
            return .white
        }
    }

    // MARK: - Trailing

    @ViewBuilder
    private var trailing: some View {
        if showsMusic {
            Rectangle()
                .fill(
                    Defaults[.coloredSpectrogram]
                        ? Color(nsColor: musicManager.avgColor).gradient
                        : Color.gray.gradient
                )
                .frame(width: 50, alignment: .center)
                .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                .mask {
                    AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                        .frame(width: 16, height: 12)
                }
                .frame(width: squareSlot, height: squareSlot, alignment: .center)
                .frame(width: sideSlot, height: squareSlot)
        } else {
            Color.clear.frame(width: sideSlot, height: squareSlot)
        }
    }

    // MARK: - Inline sneak peek

    @ViewBuilder
    private var inlineSneakPeek: some View {
        HStack(alignment: .top) {
            if coordinator.inlineExpansionVisible && showsMusic {
                MarqueeText(
                    .constant(musicManager.songTitle),
                    textColor: Defaults[.coloredSpectrogram]
                        ? Color(nsColor: musicManager.avgColor) : Color.gray,
                    minDuration: 0.4,
                    frameWidth: 100
                )
                Spacer(minLength: vm.closedNotchSize.width)
                Text(musicManager.artistName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(
                        Defaults[.coloredSpectrogram]
                            ? Color(nsColor: musicManager.avgColor) : Color.gray
                    )
            }
        }
    }
}
