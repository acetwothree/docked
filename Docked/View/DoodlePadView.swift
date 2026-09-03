//
//  DoodlePadView.swift
//  Docked
//
//  Smooth freehand sketching on a `Canvas` + a zero-distance `DragGesture`.
//  Fills the whole content area; the tool bar floats along the bottom.
//  Strokes are stored normalised so a doodle survives layout changes.
//  The share button renders the strokes to a PNG (Save to Photos / Files).
//

import SwiftUI
import UIKit

struct DoodlePadView: View {
    @Environment(DoodleStore.self) private var store

    @State private var currentPoints: [CGPoint] = []
    @State private var colorHex = "F2B950"
    @State private var lineWidth: Double = 5
    @State private var exportImage: Image?

    private let palette = ["F2B950", "FF6B6B", "4ECDC4", "6C8EFF", "C792EA"]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let strokeCount = store.strokes.count

            ZStack(alignment: .bottom) {
                DoodleCanvas(strokes: store.strokes, live: liveStroke)
                    .id(strokeCount)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(drawGesture(in: size))

                toolbar
            }
            .onAppear { refreshExport() }
            .onChange(of: strokeCount) { _, _ in refreshExport() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            ForEach(palette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 26, height: 26)
                    .overlay { Circle().strokeBorder(.white.opacity(colorHex == hex ? 0.95 : 0), lineWidth: 2.5) }
                    .contentShape(Circle())
                    .onTapGesture { colorHex = hex }
            }
            Slider(value: $lineWidth, in: 2...22)
                .frame(maxWidth: 64)
            Spacer(minLength: 2)

            if let exportImage {
                ShareLink(item: exportImage,
                          preview: SharePreview("Doodle", image: exportImage)) {
                    Image(systemName: "square.and.arrow.up").frame(width: 38, height: 38).contentShape(Rectangle())
                }
            } else {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 38, height: 38)
                    .foregroundStyle(.tertiary)
            }

            Button { store.undo() } label: {
                Image(systemName: "arrow.uturn.backward").frame(width: 38, height: 38).contentShape(Rectangle())
            }
            .disabled(store.strokes.isEmpty)
            Button(role: .destructive) { store.clear() } label: {
                Image(systemName: "trash").frame(width: 38, height: 38).contentShape(Rectangle())
            }
            .disabled(store.strokes.isEmpty)
        }
        .font(.system(size: 16, weight: .semibold))
        .padding(.leading, 14).padding(.trailing, 16).padding(.vertical, 6)
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

    private var liveStroke: DoodleCanvas.Live? {
        guard currentPoints.count > 1 else { return nil }
        return DoodleCanvas.Live(points: currentPoints, colorHex: colorHex, width: lineWidth)
    }

    @MainActor private func refreshExport() {
        guard !store.strokes.isEmpty else { exportImage = nil; return }
        let renderer = ImageRenderer(
            content: DoodleCanvas(strokes: store.strokes, live: nil)
                .frame(width: 1400, height: 1400)
                .background(Color.white)
        )
        renderer.scale = 1
        if let ui = renderer.uiImage {
            exportImage = Image(uiImage: ui)
        }
    }
}

/// The strokes, drawn. Shared by the live pad and the PNG export so what you
/// save is exactly what you see.
struct DoodleCanvas: View {
    struct Live { var points: [CGPoint]; var colorHex: String; var width: Double }

    var strokes: [DoodleStroke]
    var live: Live?

    var body: some View {
        Canvas { ctx, size in
            for stroke in strokes {
                ctx.stroke(Self.smoothPath(stroke.points, size),
                           with: .color(Color(hex: stroke.colorHex)),
                           style: Self.style(stroke.width))
            }
            if let live, live.points.count > 1 {
                ctx.stroke(Self.smoothPath(live.points, size),
                           with: .color(Color(hex: live.colorHex)),
                           style: Self.style(live.width))
            }
        }
    }

    static func style(_ w: Double) -> StrokeStyle {
        StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
    }

    static func smoothPath(_ pts: [CGPoint], _ size: CGSize) -> Path {
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
