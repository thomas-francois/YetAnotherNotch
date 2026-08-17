//
//  AppLauncherView.swift
//  YetAnotherNotch
//

import SwiftUI

/// Contents of the App Launcher tab: one centered row of slots.
struct AppLauncherView: View {
    @ObservedObject var store = AppLauncherStore.shared

    /// 64pt icon in a 72pt slot, which is what 578 / 8 gives.
    private let iconSize: CGFloat = 64

    var body: some View {
        HStack(spacing: 0) {
            ForEach(store.slots.indices, id: \.self) { index in
                AppLauncherSlotView(index: index, iconSize: iconSize)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppLauncherView()
        .environmentObject(CustomViewModel())
        .frame(width: 578, height: 146)
        .background(.black)
}
