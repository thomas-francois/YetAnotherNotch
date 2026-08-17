//
//  NotchTabContent.swift
//  YetAnotherNotch
//

import SwiftUI

/// Resolves the selected tab to its content.
///
/// This switch is the reason `NotchTab` is an enum rather than an array of models:
/// adding a case makes the switch non-exhaustive, so the compiler refuses to build a
/// tab that has no content. Each arm stays a one-line delegation, so a feature's own
/// code lives in its own file once it exists.
struct NotchTabContent: View {
    @ObservedObject var coordinator = CustomViewCoordinator.shared
    let albumArtNamespace: Namespace.ID

    var body: some View {
        switch coordinator.selectedTab {
        case .music:
            // Not wrapped in a transition: the album art uses matchedGeometryEffect with
            // the closed-notch live activity, and changing this view's identity would
            // break that animation.
            NotchHomeView(albumArtNamespace: albumArtNamespace)
        case .appLauncher:
            AppLauncherView()
                .transition(.opacity)
        case .utilities:
            UtilitiesView()
                .transition(.opacity)
        case .terminal:
            placeholder(.terminal)
        case .ai:
            AIView()
                .transition(.opacity)
        case .chat:
            ChatTabView()
                .transition(.opacity)
        case .transcription:
            TranscriptionView()
                .transition(.opacity)
        }
    }

    private func placeholder(_ tab: NotchTab) -> some View {
        NotchTabPlaceholder(tab: tab)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}
