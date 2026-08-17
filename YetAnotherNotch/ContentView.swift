//
//  ContentView.swift
//  YetAnotherNotch
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import Combine
import Defaults
import SwiftUI
import SwiftUIIntrospect

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: CustomViewModel

    @ObservedObject var coordinator = CustomViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var timer = UtilityTimerStore.shared
    @ObservedObject var aiShortcuts = PromptShortcutStore.shared
    @ObservedObject var aiChat = ChatStore.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false

    @State private var haptics: Bool = false

    @Namespace var albumArtNamespace

    // Shared interactive spring for movement/resizing to avoid conflicting animations.
    // Lives on CustomViewModel so ClosedNotchActivity's tap-to-open animates identically.
    private let animationSpring = CustomViewModel.openAnimation

    private var topCornerRadius: CGFloat {
        ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        )
    }

    /// Mirrors `ClosedNotchActivity.aiIsWorking`. Must stay equivalent to it: this decides both
    /// whether the activity bar renders at all and how wide the chin hit area is, so if the two
    /// disagree the indicator and the area you can click to reach it drift apart.
    private var aiIsWorking: Bool {
        ClosedNotchActivity.aiIsWorking(aiShortcuts, aiChat)
    }

    /// True when the closed notch has anything to show around the cutout — music, AI work in
    /// progress, or a timer that is running, paused, or waiting to be acknowledged.
    private var showsClosedActivity: Bool {
        vm.notchState == .closed
            && !vm.hideOnClosed
            && (ClosedNotchActivity.musicIsActive(musicManager, coordinator)
                || timer.isActive
                || aiIsWorking)
    }

    private var computedChinWidth: CGFloat {
        guard showsClosedActivity else { return vm.closedNotchSize.width }

        // Shares ClosedNotchLayout with ClosedNotchActivity so the chin hit area and the
        // visible pill cannot drift apart.
        let sideSlot = ClosedNotchLayout.sideSlotWidth(
            timerReadoutWidth: timer.isActive
                ? ClosedNotchLayout.timerReadoutWidth(
                    forDisplayLength: TimeFormatting.display(timer.value).count)
                : nil,
            aiIndicatorWidth: aiIsWorking ? ClosedNotchLayout.aiIndicatorWidth : nil,
            squareSlot: max(0, vm.effectiveClosedNotchHeight - 12),
            musicActive: ClosedNotchActivity.musicIsActive(musicManager, coordinator)
        )

        return ClosedNotchLayout.pillWidth(
            cutoutWidth: vm.closedNotchSize.width,
            sideSlotWidth: sideSlot
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                let mainLayout = NotchLayout()
                    .frame(alignment: .top)
                    .padding(
                        .horizontal,
                        vm.notchState == .open
                            ? Defaults[.cornerRadiusScaling]
                                ? (cornerRadiusInsets.opened.top) : (cornerRadiusInsets.opened.bottom)
                            : cornerRadiusInsets.closed.bottom
                    )
                    .padding([.horizontal, .bottom], vm.notchState == .open ? 12 : 0)
                    .background(.black)
                    .clipShape(currentNotchShape)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .shadow(
                        color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                            ? .black.opacity(0.7) : .clear, radius: Defaults[.cornerRadiusScaling] ? 6 : 4
                    )
                    .padding(
                        .bottom,
                        vm.effectiveClosedNotchHeight == 0 ? 10 : 0
                    )

                mainLayout
                    .frame(height: vm.notchState == .open ? vm.notchSize.height : nil)
                    .conditionalModifier(true) { view in
                        let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
                        let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)

                        return view
                            .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.notchState)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        doOpen()
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        if newState == .closed && isHovering {
                            withAnimation {
                                isHovering = false
                            }
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            DispatchQueue.main.async {
                                SettingsWindowController.shared.showWindow()
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                    }

                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .compositingGroup()
        .preferredColorScheme(.dark)
        .environmentObject(vm)
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                if showsClosedActivity {
                    ClosedNotchActivity(albumArtNamespace: albumArtNamespace)
                        .frame(alignment: .center)
                } else if vm.notchState == .open {
                    CustomHeader()
                        .frame(height: max(24, vm.effectiveClosedNotchHeight))
                } else {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: vm.closedNotchSize.width - 20, height: vm.effectiveClosedNotchHeight)
                }

                // Standard-style sneak peek: a line of text below the closed notch
                if coordinator.sneakPeekVisible
                    && Defaults[.sneakPeekStyles] == .standard
                    && vm.notchState == .closed
                    && !vm.hideOnClosed
                {
                    HStack(alignment: .center) {
                        Image(systemName: "music.note")
                        GeometryReader { geo in
                            MarqueeText(
                                .constant(musicManager.songTitle + " - " + musicManager.artistName),
                                textColor: Defaults[.playerColorTinting]
                                    ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6)
                                    : .gray,
                                minDuration: 1,
                                frameWidth: geo.size.width
                            )
                        }
                    }
                    .foregroundStyle(.gray)
                    .padding(.bottom, 10)
                }
            }
            .conditionalModifier(
                coordinator.sneakPeekVisible
                    && Defaults[.sneakPeekStyles] == .standard
                    && vm.notchState == .closed
                    && !vm.hideOnClosed
            ) { view in
                view.fixedSize()
            }
            .zIndex(2)

            if vm.notchState == .open {
                NotchTabContent(albumArtNamespace: albumArtNamespace)
                    .transition(
                        .scale(scale: 0.8, anchor: .top)
                            .combined(with: .opacity)
                            .animation(.smooth(duration: 0.35))
                    )
                    .zIndex(1)
                    .allowsHitTesting(vm.notchState == .open)
            }
        }
    }

    private func doOpen() {
        withAnimation(animationSpring) {
            vm.open()
        }
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()

        if hovering {
            withAnimation(animationSpring) {
                isHovering = true
            }

            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }

            guard vm.notchState == .closed,
                  !coordinator.sneakPeekVisible,
                  Defaults[.openNotchOnHover] else { return }

            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          !self.coordinator.sneakPeekVisible else { return }

                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    withAnimation(animationSpring) {
                        self.isHovering = false
                    }

                    // preventsAutoClose keeps the notch up while notch content has a
                    // modal panel open, e.g. the App Launcher's app picker.
                    if self.vm.notchState == .open && !self.coordinator.preventsAutoClose {
                        self.vm.close()
                    }
                }
            }
        }
    }
}

#Preview {
    let vm = CustomViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
