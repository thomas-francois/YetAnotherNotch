//
//  ColorPickerWidgetView.swift
//  YetAnotherNotch
//

import SwiftUI

/// Eyedropper button plus the last picked colour, in the Utilities tab.
struct ColorPickerWidgetView: View {
    @ObservedObject var store = ColorPickerStore.shared

    @State private var justCopied = false

    var body: some View {
        VStack(spacing: 10) {
            Button {
                store.pickColor()
            } label: {
                Label("Pick Colour", systemImage: "eyedropper")
            }
            .buttonStyle(.borderedProminent)
            .tint(.effectiveAccent)
            .controlSize(.small)

            if let hex = store.lastHex {
                Button {
                    store.copyLastToClipboard()
                    flashCopied()
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(swatch(for: hex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                            }
                        Text(justCopied ? "Copied" : hex)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(justCopied ? .secondary : .primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to copy \(hex) again")
            } else {
                Text("No colour picked")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.smooth(duration: 0.2), value: justCopied)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Deliberately does not close the notch after sampling: the swatch and hex are the
        // confirmation of what landed on the clipboard, and closing immediately meant you
        // never saw them. It also lets you sample several colours in a row.
        //
        // Not a stuck-open risk: hover-exit already fired (suppressed by
        // preventsAutoClose), and ContentView.handleHover resets isHovering on the next
        // entry, so the next pass over the notch closes it as usual.
    }

    /// Built from the stored hex, so it shows the sRGB colour that was copied.
    private func swatch(for hex: String) -> Color {
        guard let rgb = HexColor.components(fromHex: hex) else { return .clear }
        return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }

    private func flashCopied() {
        justCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            justCopied = false
        }
    }
}
