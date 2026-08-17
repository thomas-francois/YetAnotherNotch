//
//  ModelSelectorView.swift
//  YetAnotherNotch
//

import AppKit
import Defaults
import SwiftUI

/// Which model answers, and whether the server is there at all.
///
/// Sized for the left half of a 578 x 146 pt tab, so controls are `.small`. The server URL
/// is edited in Settings; this view only reports it.
struct ModelSelectorView: View {
    @ObservedObject var store = ModelStore.shared

    @Default(.llamaLaunchCommand) private var launchCommand

    @State private var justCopiedCommand = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            switch store.reachability {
            case .unknown, .checking:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
            case .unreachable:
                notRunning
            case .reachable:
                reachable
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await store.refresh() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "cpu")
                .font(.caption)
            Text("Model")
                .font(.headline)
            Spacer()
            if store.isReachable, let model = store.selectedModel {
                HStack(spacing: 4) {
                    Circle()
                        .fill(model.isReady ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(model.isReady ? "Ready" : "Busy")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Reachable

    @ViewBuilder
    private var reachable: some View {
        if store.models.isEmpty {
            Text("The server is running but reports no models.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Picker("", selection: $store.selectedModelID) {
                Text("None").tag("")
                ForEach(store.models) { model in
                    Text(LlamaServerAddress.displayName(forModelID: model.id)).tag(model.id)
                }
            }
            .labelsHidden()
            .controlSize(.small)

            Text(store.serverURLString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Not running

    /// YetAnotherNotch cannot start the server, so this state has to teach rather than just
    /// report a failure. It is the first thing a new user sees.
    private var notRunning: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("No llama-server at \(store.serverURLString)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Start one, then Retry:")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Text(launchCommand)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.08)))

                // A copy button rather than selectable text: selecting inside the notch
                // means click-dragging in a window that closes when it loses focus.
                Button {
                    copyLaunchCommand()
                } label: {
                    Image(systemName: justCopiedCommand ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(justCopiedCommand ? Color.green : Color.secondary)
                .help(justCopiedCommand ? "Copied" : "Copy the launch command")
            }
            .animation(.smooth(duration: 0.2), value: justCopiedCommand)

            HStack(spacing: 6) {
                Button("Retry") {
                    Task { await store.refresh() }
                }
                .controlSize(.small)

                Button("Settings") {
                    SettingsWindowController.shared.showWindow()
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
            }
        }
    }

    private func copyLaunchCommand() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(launchCommand, forType: .string)
        justCopiedCommand = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            justCopiedCommand = false
        }
    }
}
