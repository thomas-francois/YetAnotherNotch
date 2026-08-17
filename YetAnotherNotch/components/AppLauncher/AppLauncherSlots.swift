//
//  AppLauncherSlots.swift
//  YetAnotherNotch
//

import Defaults
import Foundation

/// The launcher's persisted contents: one bundle identifier per slot, `nil` for empty.
///
/// Positions are fixed. Removing slot 3 leaves a gap rather than shifting slot 4 left,
/// so muscle memory survives and reordering is always explicit.
///
/// Mutation logic here is pure — no SwiftUI, no `Defaults` reads — so it can be
/// verified standalone.
struct AppLauncherSlots: Codable, Equatable, Defaults.Serializable {
    /// Number of slots in the row. Changing this changes the launcher; stored data of a
    /// different length is normalized on decode rather than rejected.
    static let count = 8

    private(set) var bundleIdentifiers: [String?]

    init(bundleIdentifiers: [String?] = Array(repeating: nil, count: AppLauncherSlots.count)) {
        self.bundleIdentifiers = Self.normalized(bundleIdentifiers)
    }

    /// Tolerates a stored array whose length no longer matches `count`, so bumping
    /// `count` later cannot crash or drop data unpredictably.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.decodeIfPresent([String?].self, forKey: .bundleIdentifiers) ?? []
        self.bundleIdentifiers = Self.normalized(stored)
    }

    static func normalized(_ ids: [String?]) -> [String?] {
        if ids.count == count { return ids }
        if ids.count > count { return Array(ids.prefix(count)) }
        return ids + Array(repeating: nil, count: count - ids.count)
    }

    // MARK: - Reads

    var indices: Range<Int> { 0..<Self.count }

    func bundleIdentifier(at index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return bundleIdentifiers[index]
    }

    func isEmpty(at index: Int) -> Bool {
        bundleIdentifier(at: index) == nil
    }

    /// Left swap is unavailable for the first slot, and for an empty slot there is
    /// nothing to move.
    func canMoveLeft(_ index: Int) -> Bool {
        indices.contains(index) && index > 0 && !isEmpty(at: index)
    }

    func canMoveRight(_ index: Int) -> Bool {
        indices.contains(index) && index < Self.count - 1 && !isEmpty(at: index)
    }

    // MARK: - Mutations

    mutating func set(_ bundleIdentifier: String?, at index: Int) {
        guard indices.contains(index) else { return }
        bundleIdentifiers[index] = bundleIdentifier
    }

    mutating func remove(at index: Int) {
        set(nil, at: index)
    }

    /// Swaps with the neighbour, which keeps every other slot in place.
    mutating func moveLeft(_ index: Int) {
        guard canMoveLeft(index) else { return }
        bundleIdentifiers.swapAt(index, index - 1)
    }

    mutating func moveRight(_ index: Int) {
        guard canMoveRight(index) else { return }
        bundleIdentifiers.swapAt(index, index + 1)
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifiers
    }
}
