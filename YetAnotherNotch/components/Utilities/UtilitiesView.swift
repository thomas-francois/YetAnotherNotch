//
//  UtilitiesView.swift
//  YetAnotherNotch
//

import SwiftUI

/// Contents of the Utilities tab: the timer, the colour picker, and — only while an external
/// display is attached — its brightness.
///
/// Widgets are separate views with their own stores, so adding one is additive. The brightness
/// widget's visibility is decided here rather than inside itself, so the condition and the
/// layout that depends on it stay together.
struct UtilitiesView: View {
    @ObservedObject var displays = ExternalDisplayStore.shared

    var body: some View {
        HStack(spacing: 0) {
            TimerWidgetView()
                .frame(maxWidth: .infinity)

            Divider()
                .padding(.vertical, 8)

            ColorPickerWidgetView()
                .frame(width: 210)

            if displays.isConnected {
                Divider()
                    .padding(.vertical, 8)

                BrightnessWidgetView()
                    .frame(width: 74)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.2), value: displays.isConnected)
    }
}

#Preview {
    UtilitiesView()
        .environmentObject(CustomViewModel())
        .frame(width: 578, height: 146)
        .background(.black)
}
