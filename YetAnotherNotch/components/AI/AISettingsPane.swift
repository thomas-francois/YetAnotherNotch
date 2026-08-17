//
//  AISettingsPane.swift
//  YetAnotherNotch
//

import Defaults
import SwiftUI

/// AI settings. For now: where the user's llama-server is.
///
/// There is nothing here about downloading, deleting or sleeping models — YetAnotherNotch does
/// not manage the server, so those are the user's business.
struct AISettingsPane: View {
    @ObservedObject var store = ModelStore.shared

    @Default(.llamaServerURL) var serverURL

    @Default(.llamaLaunchCommand) var launchCommand

    @ObservedObject private var shortcuts = PromptShortcutStore.shared
    @State private var editingIndex: Int?
    @State private var draftName = ""
    @State private var draftIcon = "wand.and.stars"
    @State private var draftPrompt = ""

    var body: some View {
        Form {
            Section {
                TextField("Server URL", text: $serverURL)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    statusLabel
                    Spacer()
                    Button("Test connection") {
                        Task { await store.refresh() }
                    }
                }

                if LlamaServerAddress.url(from: serverURL) == nil {
                    Label("That is not a usable address.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("""
                YetAnotherNotch does not start llama-server — run it yourself and point this at \
                it. The default matches llama.cpp's own default port, so a server started \
                with no arguments needs no configuration here.

                A bare `127.0.0.1:8080` works; the scheme is added for you.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)

                TextField("Launch command", text: $launchCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Text("""
                Shown with a copy button in the AI tab whenever no server is answering. Put \
                your own command here — the model path and flags you actually use — so it can \
                be pasted straight into a terminal instead of edited every time.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("Server")
            }

            Section {
                Text("""
                Asking llama.cpp for a model by its Hugging Face id (`owner/repo:QUANT`) \
                makes it contact Hugging Face and download a newer revision if one exists. \
                If you want to stay offline, start your server with `--offline`, or pass the \
                model as a file path with `-m`.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("A note on downloads")
            }

            Section {
                ForEach(shortcuts.slots.indices, id: \.self) { index in
                    if let shortcut = shortcuts.slots.shortcut(at: index) {
                        HStack {
                            Image(systemName: shortcut.icon)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(shortcut.name)
                                Text(shortcut.systemPrompt)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Button {
                                shortcuts.moveLeft(index)
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!shortcuts.slots.canMoveLeft(index))

                            Button {
                                shortcuts.moveRight(index)
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!shortcuts.slots.canMoveRight(index))

                            Button("Edit") { beginEditing(index) }
                                .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                shortcuts.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        HStack {
                            Text("Slot \(index + 1)")
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button("Add") { beginEditing(index) }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text("Clipboard shortcuts")
            } footer: {
                Text("""
                Clicking a shortcut in the AI tab sends your clipboard to the model with its \
                prompt, then replaces the clipboard with the reply. Positions are fixed, so \
                removing one leaves a gap rather than shifting the others.
                """)
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: .init(
            get: { editingIndex != nil },
            set: { if !$0 { editingIndex = nil } }
        )) {
            editorSheet
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch store.reachability {
        case .reachable:
            Label("\(store.models.count) model(s) available", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .checking:
            Label("Checking…", systemImage: "ellipsis.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .unreachable(message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(2)
        case .unknown:
            Label("Not checked yet", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var editorSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editingIndex.map { "Shortcut \($0 + 1)" } ?? "Shortcut")
                .font(.headline)

            HStack {
                TextField("Name", text: $draftName)
                    .frame(width: 160)
                TextField("SF Symbol", text: $draftIcon)
                    .frame(width: 160)
                Image(systemName: draftIcon.isEmpty ? "questionmark" : draftIcon)
            }

            Text("System prompt")
                .font(.subheadline)
            TextEditor(text: $draftPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(width: 460, height: 150)
                .border(.separator)

            Text("""
            Tell the model to output only the transformed text. Anything else it says gets \
            pasted along with the result.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { editingIndex = nil }
                Button("Save") { saveEditing() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draftName.isEmpty || draftPrompt.isEmpty)
            }
        }
        .padding(20)
    }

    private func beginEditing(_ index: Int) {
        let existing = shortcuts.slots.shortcut(at: index)
        draftName = existing?.name ?? ""
        draftIcon = existing?.icon ?? "wand.and.stars"
        draftPrompt = existing?.systemPrompt ?? ""
        editingIndex = index
    }

    private func saveEditing() {
        guard let index = editingIndex else { return }
        // Keeping the existing id means an edit updates the shortcut rather than replacing
        // it, which matters if anything ever keys off the id.
        let id = shortcuts.slots.shortcut(at: index)?.id ?? UUID()
        shortcuts.set(
            PromptShortcut(
                id: id,
                name: draftName,
                icon: draftIcon.isEmpty ? "wand.and.stars" : draftIcon,
                systemPrompt: draftPrompt
            ),
            at: index
        )
        editingIndex = nil
    }
}
