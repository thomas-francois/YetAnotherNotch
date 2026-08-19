//
//  BrightnessWidgetView.swift
//  YetAnotherNotch
//

import AppKit
import SwiftUI

/// External-display brightness, shown in the Utilities tab only while one is attached.
///
/// `UtilitiesView` decides whether to show this; it does not check again here, so the layout
/// and the condition stay in one place.
struct BrightnessWidgetView: View {
    @ObservedObject var store = ExternalDisplayStore.shared

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "sun.max")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            // Bound through the store's setter rather than a published var with a didSet:
            // reading the display's own brightness would otherwise write it straight back.
            VerticalSlider(
                value: Binding(
                    get: { Double(store.brightness) },
                    set: { store.setBrightness(Float($0)) }
                )
            )
            .frame(maxHeight: .infinity)

            Image(systemName: "sun.min")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Text("\(Int((store.brightness * 100).rounded()))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Which mechanism is running lives in the tooltip rather than on screen: it matters when
        // the dimming behaves oddly (capped, hurts contrast, shows in screenshots) and is noise
        // the rest of the time.
        .help(helpText)
    }

    private var helpText: String {
        guard let display = store.display else { return "External display brightness" }
        switch display.mechanism {
        case .system:
            return "\(display.name) — backlight brightness"
        case .overlay:
            return "\(display.name) — dimmed with an overlay, because this display refuses the system brightness API"
        }
    }
}

/// `NSSlider` in its vertical form. SwiftUI's `Slider` is horizontal only on macOS, and rotating
/// one leaves its hit-testing in the old orientation.
private struct VerticalSlider: NSViewRepresentable {
    @Binding var value: Double

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: value,
            minValue: 0,
            maxValue: 1,
            target: context.coordinator,
            action: #selector(Coordinator.changed(_:))
        )
        slider.isVertical = true
        slider.controlSize = .small
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        context.coordinator.value = $value
        // Only write back when it actually differs, so dragging is not fought by the update.
        if abs(nsView.doubleValue - value) > 0.001 {
            nsView.doubleValue = value
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

    final class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) { self.value = value }

        @objc func changed(_ sender: NSSlider) { value.wrappedValue = sender.doubleValue }
    }
}
