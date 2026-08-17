//
//  AIView.swift
//  YetAnotherNotch
//

import SwiftUI

/// The AI tab: model on the left, clipboard shortcuts on the right.
///
/// Split rather than stacked because the tab is wide and short — roughly 578 x 146 pt — and
/// both halves need the full height.
struct AIView: View {
    var body: some View {
        HStack(spacing: 12) {
            ModelSelectorView()
                .frame(width: 288)

            Divider()

            PromptShortcutsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AIView()
        .frame(width: 578, height: 146)
        .background(.black)
}
