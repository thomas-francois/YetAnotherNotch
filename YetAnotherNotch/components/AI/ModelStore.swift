//
//  ModelStore.swift
//  YetAnotherNotch
//

import Defaults
import SwiftUI

/// Whether the user's `llama-server` is reachable, what models it offers, and which one is
/// selected.
///
/// YetAnotherNotch does not start, stop or manage the server — it only asks. A singleton so the
/// answer survives the notch closing and is shared by the AI and Chat tabs.
@MainActor
final class ModelStore: ObservableObject {
    static let shared = ModelStore()

    enum Reachability: Equatable {
        case unknown
        case checking
        case reachable
        case unreachable(String)
    }

    @Published private(set) var reachability: Reachability = .unknown
    @Published private(set) var models: [LlamaModel] = []

    /// Persisted, so the choice survives a relaunch.
    @Published var selectedModelID: String {
        didSet {
            guard selectedModelID != oldValue else { return }
            Defaults[.llamaSelectedModel] = selectedModelID
        }
    }

    private init() {
        selectedModelID = Defaults[.llamaSelectedModel]
    }

    // MARK: - Configuration

    var serverURLString: String { Defaults[.llamaServerURL] }

    /// `nil` when the configured text is not a usable address at all.
    var client: LlamaClient? {
        LlamaServerAddress.url(from: serverURLString).map { LlamaClient(baseURL: $0) }
    }

    // MARK: - Reads

    var isReachable: Bool { reachability == .reachable }

    var selectedModel: LlamaModel? {
        models.first { $0.id == selectedModelID }
    }

    /// Everything a request needs: a reachable server, a selected model that is still
    /// listed, and that model not being mid-download.
    /// Whether the selected model can be sent images. False with no selection, so the drop
    /// target stays closed rather than accepting something nothing can read.
    var selectionSupportsVision: Bool {
        isReachable && selectedModel?.supportsVision == true
    }

    var hasUsableSelection: Bool {
        isReachable && (selectedModel?.isReady ?? false)
    }


    // MARK: - Refresh

    /// Called when the AI or Chat tab appears, and by an explicit Retry.
    ///
    /// There is no background polling: the server's state changes only when the user starts
    /// or stops it, so polling would spend battery to learn nothing.
    func refresh() async {
        guard let client else {
            models = []
            reachability = .unreachable("“\(serverURLString)” is not a valid server address.")
            return
        }

        reachability = .checking
        do {
            let listed = try await client.listModels()
            models = listed
            reachability = .reachable

            // A selection that is no longer offered is dropped rather than left dangling —
            // the user may have restarted their server with a different model.
            if !selectedModelID.isEmpty, !listed.contains(where: { $0.id == selectedModelID }) {
                selectedModelID = ""
            }
            // A plain single-model server offers exactly one thing; making the user pick it
            // from a list of one is pure friction.
            if selectedModelID.isEmpty, listed.count == 1, listed[0].isReady {
                selectedModelID = listed[0].id
            }
        } catch {
            models = []
            reachability = .unreachable(error.localizedDescription)
        }
    }

    /// Called when a request fails mid-session, so a server that has gone away is noticed
    /// at the point of use rather than being retried forever.
    func markUnreachable(_ message: String) {
        models = []
        reachability = .unreachable(message)
    }
}
