//
//  NotchTabButton.swift
//  YetAnotherNotch
//

import SwiftUI

/// One icon in the tab bar.
///
/// Occupies exactly `width` so `NotchTabLayout`'s arithmetic holds; the visual gap
/// between neighbours comes from insetting the selection capsule.
struct NotchTabButton: View {
    let tab: NotchTab
    let isSelected: Bool
    let width: CGFloat
    /// Namespace for the sliding selection capsule. One per side — see `NotchTabBar`.
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tab.icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: width, height: NotchTabLayout.itemHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundStyle(isSelected ? .white : .gray)
        .background {
            if isSelected {
                Capsule()
                    .fill(Color(nsColor: .secondarySystemFill))
                    .padding(.horizontal, 3)
                    .matchedGeometryEffect(id: "notchTabCapsule", in: namespace)
            }
        }
        .help(tab.title)
        .accessibilityLabel(tab.title)
    }
}
