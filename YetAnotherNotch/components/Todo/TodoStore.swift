//
//  TodoStore.swift
//  YetAnotherNotch
//

import Defaults
import SwiftUI

struct TodoItem: Codable, Equatable, Identifiable, Defaults.Serializable {
    var id: UUID
    var text: String
    /// Optional on purpose: items saved before this existed decode to nil rather than being
    /// dropped, and they show no age instead of a made-up one.
    var createdAt: Date?

    init(id: UUID = UUID(), text: String, createdAt: Date? = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }

    /// Whole days since it was added. `nil` when unknown.
    var ageInDays: Int? {
        guard let createdAt else { return nil }
        return Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day
    }
}

/// The list, and the wheel's verdict.
///
/// The winner is chosen up front and the wheel is then animated to land on it, rather than
/// reading an angle when the spin stops. Deriving the result from the animation would make the
/// randomness a property of frame timing, which is both harder to reason about and easy to get
/// subtly biased.
@MainActor
final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    @Published private(set) var items: [TodoItem] = Defaults[.todoItems]

    /// Index into `items`, set the moment a spin starts.
    @Published private(set) var pickedIndex: Int?

    @Published private(set) var isSpinning = false

    /// Cumulative degrees. Only ever increases, so the wheel always turns the same way and
    /// SwiftUI animates the delta rather than snapping back through zero.
    @Published private(set) var rotation: Double = 0

    /// Seconds left before the wheel may be spun again. Zero means unlocked.
    @Published private(set) var lockRemaining: TimeInterval = 0

    /// Set briefly when the picked task is completed, so the view can fire confetti, then
    /// cleared. An id rather than a Bool so two completions in a row are distinguishable, and
    /// transient because leaving it set replayed the burst every time the tab was re-shown:
    /// switching tabs remounts the view, and a fresh mount animates again regardless of its id.
    @Published private(set) var celebration: UUID?

    private var lockTask: Task<Void, Never>?
    private var celebrationTask: Task<Void, Never>?

    private init() {}

    var picked: TodoItem? {
        guard let pickedIndex, items.indices.contains(pickedIndex) else { return nil }
        return items[pickedIndex]
    }

    // MARK: - Weighting

    /// Age at which a task reaches its maximum advantage.
    static let maxAgeDays = 14.0
    /// How much more likely the oldest task is than a brand new one.
    static let maxWeight = 3.0

    /// Ramps linearly from 1x on the day it is added to 3x at a fortnight, then stops. An
    /// unknown creation date counts as new rather than as ancient.
    func weight(for item: TodoItem) -> Double {
        let days = Double(item.ageInDays ?? 0)
        return 1 + (Self.maxWeight - 1) * min(days / Self.maxAgeDays, 1)
    }

    var weights: [Double] { items.map(weight(for:)) }

    /// Degrees each segment occupies, in list order.
    ///
    /// The wheel is drawn from this and the spin lands using it, so what you see and what gets
    /// picked cannot drift apart — a wheel with equal slices that picked unequally would be a
    /// lie the user could spot.
    var sweeps: [Double] {
        let weights = self.weights
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }
        return weights.map { 360 * $0 / total }
    }

    /// Where each segment begins, clockwise from the top.
    var starts: [Double] {
        var running = 0.0
        var result: [Double] = []
        for sweep in sweeps {
            result.append(running)
            running += sweep
        }
        return result
    }

    /// One task is enough. A single-item wheel always picks the same thing, but landing the
    /// pointer on the last task and clearing it is the satisfying part.
    var canSpin: Bool { !items.isEmpty && !isSpinning && lockRemaining <= 0 }

    var isLocked: Bool { lockRemaining > 0 }

    // MARK: - List

    /// Blocked while the box is running: editing the list mid-task is how you talk yourself out
    /// of the task.
    func add(_ text: String) {
        guard !isLocked else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(text: trimmed))
        persist()
    }

    func remove(_ item: TodoItem) {
        // Removing the task the wheel chose counts as doing it: celebrate, and let the wheel
        // spin again immediately. Deleting any other row is just tidying up.
        let wasPicked = picked?.id == item.id

        // The list is frozen while the box runs, with one exception: finishing the task it
        // chose. Otherwise the escape hatch is just deleting the thing you were asked to do.
        guard !isLocked || wasPicked else { return }

        items.removeAll { $0.id == item.id }
        pickedIndex = nil
        persist()

        if wasPicked {
            celebrate()
            // Compared before releasing, since releaseLock() zeroes lockRemaining.
            clearMirroredCountdown()
            releaseLock()
        }
    }

    /// Fires the confetti and clears the flag once the burst has had time to play.
    private func celebrate() {
        celebrationTask?.cancel()
        celebration = UUID()
        celebrationTask = Task { [weak self] in
            // Slightly longer than the animation, so it is never cut short.
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self?.celebration = nil
        }
    }

    /// Whether the Utilities countdown currently on screen is this box.
    ///
    /// Matching on the remaining value is the ownership test: ours and the wheel's were started
    /// from the same instant, so they track together. If the user stopped ours and started their
    /// own, the values will not agree and theirs is left alone. The closed notch uses this to
    /// decide which tab to open when the readout is tapped.
    var ownsMirroredCountdown: Bool {
        let timer = UtilityTimerStore.shared
        guard isLocked, timer.mode == .countdown, timer.state == .running else { return false }
        return abs(timer.value - lockRemaining) < 2
    }

    /// Resets the Utilities countdown, but only when it is still showing this box.
    private func clearMirroredCountdown() {
        guard ownsMirroredCountdown else { return }
        UtilityTimerStore.shared.reset()
    }


    /// Renames in place, keeping `id` and `createdAt`. Deleting and re-adding would reset the
    /// age, so a typo would quietly forgive a task its whole history.
    func rename(_ item: TodoItem, to text: String) {
        guard !isLocked else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].text = trimmed
        persist()
    }

    /// Marks the picked task done. Routed through `remove` so completion keeps firing the
    /// confetti and lifting the lock in one place.
    func completePicked() {
        guard let item = picked else { return }
        remove(item)
    }

    // MARK: - Spin

    private static let turns: Double = 4

    /// Two minutes. Short enough that starting feels cheap, long enough that re-rolling until an
    /// easy task appears stops being an option.
    static let lockDuration: TimeInterval = 120

    func spin() {
        guard canSpin else { return }
        let winner = weightedIndex()
        pickedIndex = winner
        isSpinning = true

        // Land the winner's centre under the pointer at the top, after a few whole turns.
        let centre = starts[winner] + sweeps[winner] / 2
        let current = rotation.truncatingRemainder(dividingBy: 360)
        rotation += Self.turns * 360 + (360 - centre) - current

        startLock()
    }

    /// Picks proportionally to weight: one uniform draw across the total, then walk the
    /// cumulative sum. Same distribution the wheel draws.
    private func weightedIndex() -> Int {
        let weights = self.weights
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        let target = Double.random(in: 0..<total)
        var running = 0.0
        for (index, weight) in weights.enumerated() {
            running += weight
            if target < running { return index }
        }
        return weights.count - 1
    }

    // MARK: - Lock

    private func startLock() {
        // Mirror the box on the Utilities countdown so it shows in the closed notch. Only when
        // that timer is idle: clobbering a timer the user started themselves would lose real
        // state, and the wheel stays locked either way.
        let timer = UtilityTimerStore.shared
        if !timer.isActive {
            timer.startCountdown(seconds: Self.lockDuration)
        }

        lockTask?.cancel()
        lockRemaining = Self.lockDuration
        let deadline = Date().addingTimeInterval(Self.lockDuration)

        // Driven off a deadline rather than by decrementing: a dropped tick or a sleeping Mac
        // would otherwise leave the wheel locked for longer than two minutes.
        lockTask = Task { [weak self] in
            while !Task.isCancelled {
                let left = deadline.timeIntervalSinceNow
                guard left > 0 else { break }
                self?.lockRemaining = left
                try? await Task.sleep(for: .milliseconds(250))
            }
            self?.lockRemaining = 0
        }
    }

    func releaseLock() {
        lockTask?.cancel()
        lockTask = nil
        lockRemaining = 0
    }

    func finishSpin() {
        isSpinning = false
    }

    private func persist() {
        Defaults[.todoItems] = items
    }
}
