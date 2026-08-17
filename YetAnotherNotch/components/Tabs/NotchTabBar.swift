//
//  NotchTabBar.swift
//  YetAnotherNotch
//

import Defaults
import SwiftUI

/// The open notch's header row: tabs split around the physical notch cutout, with the
/// settings gear pinned after the right-hand group.
///
/// The hardware notch is used as the bar's divider rather than something to avoid, which
/// is what buys enough width for up to 10 tabs without making the notch any taller.
struct NotchTabBar: View {
    @ObservedObject var coordinator = CustomViewCoordinator.shared

    /// Width of the physical notch cutout the bar wraps around. Varies by Mac model and
    /// with the user's notch-height setting, so it is always passed in at runtime.
    let cutoutWidth: CGFloat
    /// Whether the cutout is filled black, which is only correct on a display that has a
    /// real notch. On external displays it stays clear.
    let fillsCutout: Bool

    // One namespace per side. A single shared namespace would slide the selection capsule
    // across the cutout, so it would appear to fly through the hardware notch. Keeping
    // them separate slides within a side and cross-fades when switching sides.
    @Namespace private var leftNamespace
    @Namespace private var rightNamespace

    private var showsGear: Bool { Defaults[.settingsIconInNotch] }

    private var itemWidth: CGFloat {
        NotchTabLayout.itemWidth(
            count: NotchTab.allCases.count,
            usableWidth: NotchTabLayout.usableWidth(
                openNotchWidth: openNotchSize.width,
                cornerInset: Defaults[.cornerRadiusScaling]
                    ? cornerRadiusInsets.opened.top
                    : cornerRadiusInsets.opened.bottom
            ),
            cutoutWidth: cutoutWidth,
            reservesGear: showsGear
        )
    }

    var body: some View {
        let all = NotchTab.allCases
        let split = NotchTabLayout.split(count: all.count)

        HStack(spacing: 0) {
            group(Array(all.prefix(split.left)), namespace: leftNamespace)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(fillsCutout ? .black : .clear)
                .frame(width: cutoutWidth)
                .mask { NotchShape() }

            HStack(spacing: 6) {
                group(Array(all.suffix(split.right)), namespace: rightNamespace)
                if showsGear {
                    settingsButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func group(_ tabs: [NotchTab], namespace: Namespace.ID) -> some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                NotchTabButton(
                    tab: tab,
                    isSelected: coordinator.selectedTab == tab,
                    width: itemWidth,
                    namespace: namespace
                ) {
                    withAnimation(.smooth(duration: 0.25)) {
                        coordinator.selectedTab = tab
                    }
                }
            }
        }
    }

    private var settingsButton: some View {
        Button {
            DispatchQueue.main.async {
                SettingsWindowController.shared.showWindow()
            }
        } label: {
            Capsule()
                .fill(.black)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: "gear")
                        .foregroundColor(.white)
                        .imageScale(.medium)
                }
        }
        .buttonStyle(PlainButtonStyle())
        .help("Settings")
        .accessibilityLabel("Settings")
    }
}
