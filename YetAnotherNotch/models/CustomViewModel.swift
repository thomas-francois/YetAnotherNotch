//
//  CustomViewModel.swift
//  YetAnotherNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Combine
import Defaults
import SwiftUI

class CustomViewModel: NSObject, ObservableObject {
    @ObservedObject var coordinator = CustomViewCoordinator.shared
    @ObservedObject var detector = FullscreenMediaDetector.shared

    let animationLibrary: CustomAnimations = .init()
    let animation: Animation?

    @Published private(set) var notchState: NotchState = .closed

    var cancellables: Set<AnyCancellable> = []

    @Published var hideOnClosed: Bool = true

    @Published var screenUUID: String?

    @Published var notchSize: CGSize = getClosedNotchSize()
    @Published var closedNotchSize: CGSize = getClosedNotchSize()

    deinit {
        destroy()
    }

    func destroy() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    init(screenUUID: String? = nil) {
        animation = animationLibrary.animation

        super.init()

        self.screenUUID = screenUUID
        notchSize = getClosedNotchSize(screenUUID: screenUUID)
        closedNotchSize = notchSize

        setupDetectorObserver()
    }

    private func setupDetectorObserver() {
        // Publisher for the user's fullscreen detection setting
        let enabledPublisher = Defaults
            .publisher(.hideNotchOption)
            .map(\.newValue)
            .map { $0 != .never }
            .removeDuplicates()

        // Publisher for the current screen UUID (non-nil, distinct)
        let screenPublisher = $screenUUID
            .compactMap { $0 }
            .removeDuplicates()

        // Publisher for fullscreen status dictionary
        let fullscreenStatusPublisher = detector.$fullscreenStatus
            .removeDuplicates()

        // Combine all three: screen UUID, fullscreen status, and enabled setting
        Publishers.CombineLatest3(screenPublisher, fullscreenStatusPublisher, enabledPublisher)
            .map { screenUUID, fullscreenStatus, enabled in
                let isFullscreen = fullscreenStatus[screenUUID] ?? false
                return enabled && isFullscreen
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldHide in
                withAnimation(.smooth) {
                    self?.hideOnClosed = shouldHide
                }
            }
            .store(in: &cancellables)
    }

    // Computed property for effective notch height
    var effectiveClosedNotchHeight: CGFloat {
        let currentScreen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let noNotchAndFullscreen = hideOnClosed && (currentScreen?.safeAreaInsets.top ?? 0 <= 0 || currentScreen == nil)
        return noNotchAndFullscreen ? 0 : closedNotchSize.height
    }

    var chinHeight: CGFloat {
        if !Defaults[.hideTitleBar] {
            return 0
        }

        guard let currentScreen = screenUUID.flatMap({ NSScreen.screen(withUUID: $0) }) else {
            return 0
        }

        if notchState == .open { return 0 }

        let menuBarHeight = currentScreen.frame.maxY - currentScreen.visibleFrame.maxY
        let currentHeight = effectiveClosedNotchHeight

        if currentHeight == 0 { return 0 }

        return max(0, menuBarHeight - currentHeight)
    }

    func isMouseHovering(position: NSPoint = NSEvent.mouseLocation) -> Bool {
        let screenFrame = getScreenFrame(screenUUID)
        if let frame = screenFrame {
            let baseY = frame.maxY - notchSize.height
            let baseX = frame.midX - notchSize.width / 2

            return position.y >= baseY && position.x >= baseX && position.x <= baseX + notchSize.width
        }

        return false
    }

    /// Animation used whenever the notch opens or closes. Shared so every entry point
    /// animates identically.
    static let openAnimation = Animation.interactiveSpring(
        response: 0.38,
        dampingFraction: 0.8,
        blendDuration: 0
    )

    func open() {
        self.notchSize = openNotchSize
        self.notchState = .open

        // Force music information update when notch is opened
        MusicManager.shared.forceUpdate()
    }

    /// Opens the notch directly onto `tab`, overriding the remembered selection.
    ///
    /// Used by closed-notch indicators that belong to a specific tab — tapping the timer
    /// readout must land on Utilities regardless of which tab was open last.
    func open(on tab: NotchTab) {
        coordinator.selectedTab = tab
        open()
    }

    func close() {
        self.notchSize = getClosedNotchSize(screenUUID: self.screenUUID)
        self.closedNotchSize = self.notchSize
        self.notchState = .closed
        self.coordinator.sneakPeekVisible = false
        // Deliberately does NOT reset selectedTab: the notch reopens on whichever tab it
        // was closed on. Session-scoped, since selectedTab isn't persisted, so a relaunch
        // starts on .music again.
    }
}
