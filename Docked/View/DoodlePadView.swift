//
//  DoodlePadView.swift
//  Docked
//
//  Smooth freehand sketching on a `Canvas` + a zero-distance `DragGesture`.
//  Fills the whole content area; the tool bar floats along the bottom.
//  Strokes are stored normalised so a doodle survives layout changes.
//

import SwiftUI

struct DoodlePadView: View {
    @Environment(DoodleStore.self) private var store

    @State private var currentPoints: [CGPoint] = []
    @State private var colorHex = "F2B950"
    @State private var lineWidth: Double = 5

    private let palette = ["F2B950", "FF6B6B", "4ECDC4", "6C8EFF", "C792EA"]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let strokeCount = store.strokes.count

            ZStack(alignment: .bottom) {
                Canvas { ctx, canvasSize in
                    for stroke in store.strokes {
                        ctx.stroke(smoothPath(stroke.points, canvasSize),
                                   with: .color(Color(hex: stroke.colorHex)),
                                   style: style(stroke.width))
                    }
                    if currentPoints.count > 1 {
                        ctx.stroke(smoothPath(currentPoints, canvasSize),
                                   with: .color(Color(hex: colorHex)),
                                   style: style(lineWidth))
                    }
                }
                .id(strokeCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(drawGesture(in: size))

                toolbar
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            ForEach(palette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 22, height: 22)
                    .overlay { Circle().strokeBorder(.white.opacity(colorHex == hex ? 0.95 : 0), lineWidth: 2) }
                    .contentShape(Circle())
                    .onTapGesture { colorHex = hex }
            }
            Slider(value: $lineWidth, in: 2...22).frame(maxWidth: 90)
            Spacer(minLength: 0)
            Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(store.strokes.isEmpty)
            Button(role: .destructive) { store.clear() } label: { Image(systemName: "trash") }
                .disabled(store.strokes.isEmpty)
        }
        .font(.system(size: 15, weight: .semibold))
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func drawGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let nx = min(max(v.location.x / max(size.width, 1), 0), 1)
                let ny = min(max(v.location.y / max(size.height, 1), 0), 1)
                currentPoints.append(CGPoint(x: nx, y: ny))
            }
            .onEnded { _ in
                if currentPoints.count > 1 {
                    store.append(DoodleStroke(points: currentPoints, colorHex: colorHex, width: lineWidth))
                }
                currentPoints = []
            }
    }

    private func style(_ w: Double) -> StrokeStyle {
        StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
    }

    private func smoothPath(_ pts: [CGPoint], _ size: CGSize) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        func d(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * size.width, y: p.y * size.height) }
        path.move(to: d(first))
        if pts.count == 2 { path.addLine(to: d(pts[1])); return path }
        for i in 1..<pts.count {
            let prev = d(pts[i - 1]), curr = d(pts[i])
            path.addQuadCurve(to: CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2), control: prev)
        }
        return path
    }
}
