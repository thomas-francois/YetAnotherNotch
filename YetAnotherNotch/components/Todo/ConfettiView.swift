//
//  ConfettiView.swift
//  YetAnotherNotch
//

import SwiftUI

/// A one-shot confetti burst.
///
/// Deliberately dumb: each piece gets a fixed random trajectory at init and the whole thing is
/// driven by a single 0→1 progress value. No physics, no timers, nothing to leak — give it a new
/// `id` and it plays again.
struct ConfettiView: View {
    var pieceCount = 28

    @State private var progress: CGFloat = 0

    private struct Piece {
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let hue: Double
        let spin: Double
    }

    private let pieces: [Piece]

    init(pieceCount: Int = 28) {
        self.pieceCount = pieceCount
        pieces = (0..<pieceCount).map { _ in
            Piece(
                // Biased upward: confetti thrown sideways reads as an explosion, not a celebration.
                angle: Double.random(in: -150 ... -30),
                distance: CGFloat.random(in: 30...70),
                size: CGFloat.random(in: 3...6),
                hue: Double.random(in: 0...1),
                spin: Double.random(in: -220...220)
            )
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hue: piece.hue, saturation: 0.75, brightness: 0.95))
                    .frame(width: piece.size, height: piece.size * 1.6)
                    .rotationEffect(.degrees(piece.spin * progress))
                    .offset(
                        x: cos(piece.angle * .pi / 180) * piece.distance * progress,
                        // Gravity, roughly: rise then fall, so it does not look like a starburst.
                        y: sin(piece.angle * .pi / 180) * piece.distance * progress
                            + 46 * progress * progress
                    )
                    .opacity(progress > 0.75 ? Double((1 - progress) / 0.25) : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { progress = 1 }
        }
    }
}
