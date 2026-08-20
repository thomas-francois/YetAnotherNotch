//
//  TodoWheelView.swift
//  YetAnotherNotch
//

import SwiftUI

/// A to-do list on the left, a wheel that picks one at random on the right.
///
/// Proof of concept. The tab is roughly 578 x 146 pt, so the wheel is small enough that segment
/// labels would be illegible — segments are colour only and the verdict is shown as text.
struct TodoWheelView: View {
    @ObservedObject private var store = TodoStore.shared

    @FocusState private var fieldFocused: Bool
    @FocusState private var editFocused: Bool
    @State private var draft = ""
    @State private var editingID: UUID?
    @State private var editDraft = ""

    var body: some View {
        HStack(spacing: 10) {
            list
            Divider().padding(.vertical, 6)
            wheelSide.frame(width: 132)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .notchKeyFocus(fieldFocused: fieldFocused || editFocused)
    }

    // MARK: - List

    private var list: some View {
        VStack(alignment: .leading, spacing: 5) {
            TextField(store.isLocked ? "Locked until the timer ends" : "Add a task…", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .focused($fieldFocused)
                .disabled(store.isLocked)
                .onSubmit {
                    store.add(draft)
                    draft = ""
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 7)
                .background { RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.08)) }

            if store.items.isEmpty {
                Text("Add a task, then spin.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                            row(item, index: index)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ item: TodoItem, index: Int) -> some View {
        let isPicked = store.pickedIndex == index && !store.isSpinning
        return HStack(spacing: 5) {
            Circle()
                .fill(Self.colour(for: index, of: store.items.count))
                .frame(width: 6, height: 6)

            if editingID == item.id {
                TextField("", text: $editDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($editFocused)
                    .onSubmit { commitEdit(item) }
                    // Clicking away commits too, rather than silently discarding what was typed.
                    .onChange(of: editFocused) { _, focused in
                        if !focused { commitEdit(item) }
                    }
            } else {
                Text(item.text)
                    .font(.system(size: 11))
                    .foregroundStyle(isPicked ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // Double-click to rename. No pencil button: the row is already tight, and
                    // gated on the lock for the same reason deleting is.
                    .onTapGesture(count: 2) { beginEdit(item) }
                    .help(store.isLocked ? item.text : "\(item.text) — double-click to rename")
            }

            Spacer(minLength: 0)

            // Shown from day zero: gating on days > 0 meant a task added today had no badge,
            // which read as the feature being missing.
            if let days = item.ageInDays {
                Text("\(days)d")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(days >= 7 ? Color.orange : Color.secondary)
                    .help(String(format: "Added %d day(s) ago — %.1fx more likely to be picked",
                                 days, store.weight(for: item)))
            }

            if !store.isLocked || isPicked {
                Button {
                    store.remove(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.tertiary)
                .help(isPicked ? "Done" : "Remove")
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(isPicked ? Color.effectiveAccent.opacity(0.22) : .clear)
        }
    }

    // MARK: - Wheel

    /// Wheel with the verdict beneath it. No prompt text: the wheel is visibly spinnable and
    /// visibly spinning, so a label saying so was only taking room from the list.
    private var wheelSide: some View {
        VStack(spacing: 4) {
            wheel

            // Height is reserved whether or not there is a caption. Letting the row appear and
            // disappear changed the stack's height, which nudged the wheel up and down.
            ZStack {
                if !store.isSpinning, let picked = store.picked {
                    Text(picked.text)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(height: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.2), value: store.pickedIndex)
        .overlay {
            if let celebration = store.celebration {
                // A fresh id remounts the view, which is what replays the burst.
                ConfettiView()
                    .id(celebration)
            }
        }
    }

    private static func countdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var wheel: some View {
        ZStack {
            if store.items.isEmpty {
                Circle().strokeBorder(.white.opacity(0.12), lineWidth: 6)
            } else {
                segments
                    .rotationEffect(.degrees(store.rotation))
                    .overlay { Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                    // Completion rather than a sleep, so the verdict appears exactly when the
                    // wheel stops rather than at a time that merely usually matches.
                    .animation(.easeOut(duration: 1.8), value: store.rotation)
            }

            // Pointer, fixed at the top while the wheel turns beneath it.
            Triangle()
                .fill(Color.effectiveAccent)
                .frame(width: 10, height: 8)
                .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                .offset(y: -56)

            // The hub doubles as Done. It sits where the segments meet, so it covers nothing,
            // and it is the natural place to press once the wheel has chosen.
            if !store.isSpinning, store.picked != nil {
                Button {
                    store.completePicked()
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                        if store.isLocked {
                            Text(Self.countdown(store.lockRemaining))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background {
                        Circle()
                            .fill(.black.opacity(0.82))
                            .overlay { Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Mark done")
            }
        }
        .frame(width: 104, height: 104)
        .contentShape(Circle())
        .onTapGesture { startSpin() }
        .help(helpText)
        .opacity(store.canSpin || store.isSpinning || store.isLocked ? 1 : 0.5)
    }

    private var segments: some View {
        Canvas { context, size in
            let count = store.items.count
            let rect = CGRect(origin: .zero, size: size)
            let radius = min(size.width, size.height) / 2
            let centre = CGPoint(x: rect.midX, y: rect.midY)
            // Straight from the store, so the slice under the pointer is the one that was drawn.
            let starts = store.starts
            let sweeps = store.sweeps
            guard starts.count == count, sweeps.count == count else { return }

            for index in 0..<count {
                var path = Path()
                path.move(to: centre)
                path.addArc(
                    center: centre,
                    radius: radius,
                    // -90 puts the first segment at the top, which is where the pointer sits.
                    startAngle: .degrees(-90 + starts[index]),
                    endAngle: .degrees(-90 + starts[index] + sweeps[index]),
                    clockwise: false
                )
                path.closeSubpath()
                context.fill(path, with: .color(Self.colour(for: index, of: count)))
                // Separators do double duty: they define the wedges, and on a single-task wheel
                // the radius line is the only thing that shows the disc is turning at all.
                context.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 1)
            }
        }
        .clipShape(Circle())
    }

    private var helpText: String {
        if store.isLocked { return "Get on with it — the wheel unlocks in \(Self.countdown(store.lockRemaining))" }
        if store.items.isEmpty { return "Add a task" }
        return "Spin"
    }

    private func beginEdit(_ item: TodoItem) {
        guard !store.isLocked else { return }
        editDraft = item.text
        editingID = item.id
        editFocused = true
    }

    private func commitEdit(_ item: TodoItem) {
        guard editingID == item.id else { return }
        store.rename(item, to: editDraft)
        editingID = nil
        editDraft = ""
    }

    private func startSpin() {
        guard store.canSpin else { return }
        store.spin()
        Task {
            try? await Task.sleep(for: .milliseconds(1850))
            store.finishSpin()
        }
    }

    /// Evenly spaced hues, so neighbouring segments never look alike.
    static func colour(for index: Int, of count: Int) -> Color {
        guard count > 0 else { return .gray }
        // Alternating brightness gives neighbouring wedges depth, which a flat rainbow lacks.
        return Color(
            hue: Double(index) / Double(count),
            saturation: 0.48,
            brightness: index.isMultiple(of: 2) ? 0.88 : 0.76
        )
    }
}

/// The wheel's pointer.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
