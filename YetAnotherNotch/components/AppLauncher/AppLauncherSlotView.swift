//
//  AppLauncherSlotView.swift
//  YetAnotherNotch
//

import SwiftUI

/// One launcher slot, in one of three states: empty, filled, or unavailable.
struct AppLauncherSlotView: View {
    @ObservedObject var store = AppLauncherStore.shared
    @EnvironmentObject var vm: CustomViewModel

    let index: Int
    let iconSize: CGFloat

    private var app: LaunchableApp? { store.app(at: index) }
    private var isUnavailable: Bool { store.isUnavailable(at: index) }
    private var hasFailed: Bool { store.failedSlot == index }

    var body: some View {
        VStack(spacing: 4) {
            Button(action: primaryAction) {
                iconArea
                    .frame(width: iconSize, height: iconSize)
                    .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PlainButtonStyle())

            Text(label)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(app == nil ? .tertiary : .secondary)
        }
        .overlay {
            if hasFailed {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.red, lineWidth: 2)
                    .frame(width: iconSize, height: iconSize)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.2), value: hasFailed)
        .contextMenu { contextMenu }
        .help(helpText)
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconArea: some View {
        if let app {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if isUnavailable {
            // Stored app is gone. Show it dimmed rather than blanking the slot, so the
            // slot's history stays visible.
            Image(nsImage: NSWorkspace.shared.icon(for: .applicationBundle))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(0.3)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
                .foregroundStyle(.tertiary)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: iconSize * 0.3, weight: .light))
                        .foregroundStyle(.tertiary)
                }
        }
    }

    private var label: String {
        if let app { return app.name }
        if isUnavailable { return "Unavailable" }
        return "Add app"
    }

    private var helpText: String {
        if let app { return "Launch \(app.name)" }
        if isUnavailable { return "This app is no longer installed. Click to replace it." }
        return "Click to choose an application"
    }

    // MARK: - Actions

    private func primaryAction() {
        if app != nil {
            // Close only once the launch has actually succeeded.
            store.launch(at: index) {
                vm.close()
            }
        } else {
            // Empty or unavailable: both want the picker. For unavailable, replacing is
            // the only useful thing to do.
            pickApp()
        }
    }

    /// `chooseApp` returns after the modal panel closes. By then the pointer is usually
    /// no longer over the notch, and no further hover event will arrive to close it — so
    /// check explicitly rather than leaving the notch stuck open.
    private func pickApp() {
        store.chooseApp(for: index)
        if !vm.isMouseHovering() {
            vm.close()
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if !store.slots.isEmpty(at: index) {
            Button("Replace App…") { pickApp() }
            Button("Remove App") { store.remove(at: index) }

            if app != nil {
                Divider()
                Button("Move Left") { store.moveLeft(index) }
                    .disabled(!store.slots.canMoveLeft(index))
                Button("Move Right") { store.moveRight(index) }
                    .disabled(!store.slots.canMoveRight(index))
                Divider()
                Button("Reveal in Finder") { store.revealInFinder(at: index) }
            }
        }
    }
}
