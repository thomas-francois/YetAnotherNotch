//
//  ChatTabView.swift
//  YetAnotherNotch
//

import SwiftUI

/// Contents of the Chat tab: ask a question, read the answer, copy it.
struct ChatTabView: View {
    @ObservedObject var store = ChatStore.shared
    @ObservedObject var models = ModelStore.shared
    @ObservedObject var coordinator = CustomViewCoordinator.shared
    @EnvironmentObject var vm: CustomViewModel

    @FocusState private var fieldFocused: Bool
    @State private var justCopied = false

    var body: some View {
        content
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            // The notch window refuses key status by default, so a text field would get no
            // keystrokes. Scoped to this tab — see YetAnotherNotchSkyLightWindow.
            coordinator.wantsKeyFocus = true
            fieldFocused = true
            Task { await ModelStore.shared.refresh() }
        }
        .onDisappear {
            coordinator.wantsKeyFocus = false
            coordinator.preventsAutoClose = false
        }
        // Held only while the field actually has focus. The reverted Terminal tab held it
        // for as long as its tab was selected, which is what left the notch sitting open.
        .onChange(of: fieldFocused) { _, focused in
            coordinator.preventsAutoClose = focused
        }
        // Clicking into another app closes the notch, so it can never get stuck open.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            guard note.object is YetAnotherNotchSkyLightWindow, vm.notchState == .open else { return }
            coordinator.preventsAutoClose = false
            vm.close()
        }
    }

    // MARK: - Connected or not

    /// `.unknown` and `.checking` keep the normal UI rather than flashing the
    /// not-connected notice, because `refresh()` runs on appear and would otherwise make
    /// every visit start with a wrong answer for a moment.
    @ViewBuilder
    private var content: some View {
        switch models.reachability {
        case .unreachable:
            notConnected
        case .unknown, .checking, .reachable:
            VStack(spacing: 6) {
                inputRow
                actionRow
                responseArea
            }
        }
    }

    /// Chat cannot work without the user's server, and YetAnotherNotch cannot start it — so this
    /// says what to do and hands over to the tab that explains how, rather than offering an
    /// input box that could only fail.
    private var notConnected: some View {
        VStack(spacing: 6) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)

            Text("Activate the server")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Go to the AI tab") {
                coordinator.selectedTab = .ai
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Input

    private var inputRow: some View {
        TextField("Ask a question…", text: $store.question, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...3)
            .font(.system(size: 12))
            .focused($fieldFocused)
            .disabled(store.isSending)
            .onSubmit { store.submit() }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.08))
            }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button("Submit") { store.submit() }
                .buttonStyle(.borderedProminent)
                .tint(.effectiveAccent)
                .controlSize(.small)
                .disabled(!store.canSubmit)

            if store.isSending {
                ProgressView()
                    .controlSize(.small)
            }

            // Which model is about to answer, next to the button that asks it. The full id
            // is a file path or a Hugging Face path, so only the tail is shown; the tooltip
            // has the whole thing.
            if let model = models.selectedModel {
                Text(LlamaServerAddress.displayName(forModelID: model.id))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(model.id)
            }

            Spacer(minLength: 0)

            if store.hasResponse {
                Button {
                    store.copyResponse()
                    flashCopied()
                } label: {
                    Label(justCopied ? "Copied" : "Copy", systemImage: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.secondary)
                .help("Copy the response to the clipboard")
            }
        }
        .animation(.smooth(duration: 0.2), value: justCopied)
    }

    // MARK: - Response

    private var responseArea: some View {
        ScrollView {
            Group {
                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                } else if store.response.isEmpty {
                    Text(store.isSending ? "Thinking…" : "The answer will appear here.")
                        .foregroundStyle(.tertiary)
                } else {
                    // Models format answers even when not asked to, so the markers are worth
                    // rendering rather than showing raw.
                    ChatMarkdownText(markdown: store.response)
                }
            }
            .font(.system(size: 11))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func flashCopied() {
        justCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            justCopied = false
        }
    }
}

#Preview {
    ChatTabView()
        .environmentObject(CustomViewModel())
        .frame(width: 578, height: 146)
        .background(.black)
}
