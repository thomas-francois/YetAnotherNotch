//
//  CustomHeader.swift
//  YetAnotherNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

/// Header strip of the open notch. Supplies `NotchTabBar` with the screen-dependent
/// values it needs and handles the closed-state fade.
struct CustomHeader: View {
    @EnvironmentObject var vm: CustomViewModel
    @ObservedObject var coordinator = CustomViewCoordinator.shared

    /// True only on a display that actually has a notch, where the cutout must be filled
    /// black to blend with the hardware.
    private var displayHasNotch: Bool {
        (NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0) > 0
    }

    var body: some View {
        NotchTabBar(
            cutoutWidth: vm.closedNotchSize.width,
            fillsCutout: displayHasNotch
        )
        .font(.system(.headline, design: .rounded))
        .foregroundColor(.gray)
        .opacity(vm.notchState == .closed ? 0 : 1)
        .blur(radius: vm.notchState == .closed ? 20 : 0)
        .zIndex(2)
        .environmentObject(vm)
    }
}

#Preview {
    CustomHeader().environmentObject(CustomViewModel())
}
