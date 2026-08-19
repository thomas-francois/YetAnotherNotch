//
//  LlamaModel.swift
//  YetAnotherNotch
//

import Foundation

/// One model as the router lists it.
///
/// The router reports models from both `--models-dir` and its download cache, which is why
/// `source` is kept: it is the only way to tell where a model came from.
struct LlamaModel: Identifiable, Equatable, Sendable {
    /// Values observed from a real router. `unknown` exists so a status added by a future
    /// llama.cpp does not decode as an error.
    enum Status: String, Sendable {
        case unloaded
        case downloading
        case loaded
        case sleeping
        case unknown

        init(rawValue: String) {
            switch rawValue {
            case "unloaded": self = .unloaded
            case "downloading": self = .downloading
            case "loaded": self = .loaded
            case "sleeping": self = .sleeping
            default: self = .unknown
            }
        }
    }

    let id: String
    let status: Status
    let source: String?

    /// Whether this model can be sent images.
    ///
    /// Comes from the server, not from the model's name: a vision-capable model still runs
    /// text-only unless llama-server was given its `--mmproj` projector, and only the server
    /// knows whether that happened.
    let supportsVision: Bool

    /// Usable right now. A sleeping model counts: it wakes in about two seconds against
    /// twenty for a cold load.
    ///
    /// `.unknown` counts too, and that is load-bearing rather than lenient. A plain
    /// single-model `llama-server` omits `status` from `/v1/models` entirely, so every model
    /// it lists decodes to `.unknown`. Treating that as "not ready" would disable the tab
    /// against the commonest server people run.
    var isReady: Bool {
        status != .downloading
    }

}

/// The shape of `GET /v1/models`.
struct LlamaModelListResponse: Decodable {
    let data: [Entry]

    /// llama-server answers this endpoint twice over: `data` is the OpenAI-compatible list and
    /// carries `id` and `status`, while `models` is the Ollama-style list and is the only one
    /// carrying `capabilities`. Neither alone is enough, so both are decoded and joined on the
    /// path, which both use verbatim.
    let capabilityEntries: [CapabilityEntry]?

    enum CodingKeys: String, CodingKey {
        case data
        case capabilityEntries = "models"
    }

    struct Entry: Decodable {
        let id: String
        let source: String?
        let status: StatusBox?

        struct StatusBox: Decodable {
            let value: String?
        }
    }

    struct CapabilityEntry: Decodable {
        let model: String?
        let capabilities: [String]?
    }

    var models: [LlamaModel] {
        let vision = Set(
            (capabilityEntries ?? [])
                .filter { $0.capabilities?.contains("multimodal") == true }
                .compactMap(\.model)
        )
        return data.map {
            LlamaModel(
                id: $0.id,
                status: LlamaModel.Status(rawValue: $0.status?.value ?? ""),
                source: $0.source,
                supportsVision: vision.contains($0.id)
            )
        }
    }
}
