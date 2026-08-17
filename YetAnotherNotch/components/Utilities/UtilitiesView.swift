//
//  UtilitiesView.swift
//  YetAnotherNotch
//

import SwiftUI

/// Contents of the Utilities tab: the timer and the colour picker, side by side.
///
/// Widgets are separate views with their own stores, so adding a third is additive.
struct UtilitiesView: View {
    var body: some View {
        HStack(spacing: 0) {
            TimerWidgetView()
                .frame(maxWidth: .infinity)

            Divider()
                .padding(.vertical, 8)

            ColorPickerWidgetView()
                .frame(width: 210)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    UtilitiesView()
        .environmentObject(CustomViewModel())
        .frame(width: 578, height: 146)
        .background(.black)
}
