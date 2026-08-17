//
//  NotchTabPlaceholder.swift
//  YetAnotherNotch
//

import SwiftUI

/// Shared empty state for tabs whose feature is not built yet.
///
/// Shows the tab's own icon and title so an unbuilt tab reads as deliberate rather
/// than as a rendering failure.
struct NotchTabPlaceholder: View {
    let tab: NotchTab

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: tab.icon)
                .font(.system(size: 30, weight: .light))
            Text(tab.title)
                .font(.headline)
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NotchTabPlaceholder(tab: .terminal)
        .frame(width: 578, height: 146)
        .background(.black)
}
