//
//  DoodlePadView.swift
//  Docked
//
//  A smooth freehand sketch surface built on `Canvas` + a zero-distance
//  `DragGesture`. Strokes are stored normalised in `DoodleStore` so the
//  drawing survives layout changes and app restarts.
//

import SwiftUI

struct DoodlePadView: View {
    @Environment(DoodleStore.self) private var store

    /// Normalised points of the stroke currently under the finger.
    @State private var currentPoints: [CGPoint] = []
    @State private var colorHex = "F2B950"
    @State private var lineWidth: Double = 5

    private let palette = ["F2B950", "FF6B6B", "4ECDC4", "6C8EFF", "C792EA", "9AA0A6"]

    var body: some View {
        VStack(spacing: 10) {
            canvas
            controls
        }
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let size = geo.size

            // Reading strokes here (in `body`) keeps the Canvas redraw wired
            // to additions / undo / clear.
            let strokeCount = store.strokes.count

            ZStack {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.paper)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                            .strokeBorder(Theme.ink.opacity(0.08))
                    }

                Canvas { context, canvasSize in
                    for stroke in store.strokes {
                        context.stroke(
                            smoothPath(for: stroke.points, in: canvasSize),
                            with: .color(Color(hex: stroke.colorHex)),
                            style: style(stroke.width)
                        )
                    }
                    if currentPoints.count > 1 {
                        context.stroke(
                            smoothPath(for: currentPoints, in: canvasSize),
                            with: .color(Color(hex: colorHex)),
                            style: style(lineWidth)
                        )
                    }
                }
                .id(strokeCount)   // belt-and-braces redraw trigger
            }
            .contentShape(Rectangle())
            .gesture(drawGesture(in: size))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        }
    }

    private func drawGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let p = CGPoint(
                    x: (value.location.x / max(size.width, 1)).clamped(),
                    y: (value.location.y / max(size.height, 1)).clamped()
                )
                currentPoints.append(p)
            }
            .onEnded { _ in
                if currentPoints.count > 1 {
                    store.append(DoodleStroke(points: currentPoints,
                                              colorHex: colorHex,
                                              width: lineWidth))
                }
                currentPoints = []
            }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 12) {
            ForEach(palette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle().strokeBorder(
                            Color.primary.opacity(colorHex == hex ? 0.9 : 0),
                            lineWidth: 2
                        )
                    }
                    .contentShape(Circle())
                    .onTapGesture { colorHex = hex }
                    .accessibilityLabel("Ink colour")
            }

            Slider(value: $lineWidth, in: 2...22)
                .frame(maxWidth: 110)
                .accessibilityLabel("Brush size")

            Spacer(minLength: 0)

            Button {
                store.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(store.strokes.isEmpty)

            Button(role: .destructive) {
                store.clear()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(store.strokes.isEmpty)
        }
        .font(.system(size: 16, weight: .semibold))
        .padding(.horizontal, 2)
    }

    // MARK: Drawing helpers

    private func style(_ width: Double) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    /// Quadratic-smoothed path through normalised points, scaled to `size`.
    private func smoothPath(for points: [CGPoint], in size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        func denorm(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * size.width, y: p.y * size.height)
        }

        path.move(to: denorm(first))
        if points.count == 2 {
            path.addLine(to: denorm(points[1]))
            return path
        }
        for i in 1..<points.count {
            let prev = denorm(points[i - 1])
            let curr = denorm(points[i])
            let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
        }
        return path
    }
}

private extension CGFloat {
    /// Clamp to the unit interval so a fast flick past the edge can't store
    /// out-of-bounds normalised points.
    func clamped() -> CGFloat { min(max(self, 0), 1) }
}
