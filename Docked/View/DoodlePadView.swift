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
import Foundation

struct DoodlePadView: View {
    @Environment(DoodleStore.self) private var store

    @State private var currentPoints: [CGPoint] = []
    @State private var colorHex = "F2B950"
    @State private var lineWidth: Double = 8
    @State private var erasing = false
    @State private var exportImage: Image?

    private let palette = ["F2B950", "FF6B6B", "FF8A3D", "F25CA2", "C792EA",
                           "6C8EFF", "4ECDC4", "3ECF7A", "B7C2CC", "111417"]
    private let widths: [Double] = [3, 8, 16, 28]

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
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(palette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 25, height: 25)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(!erasing && colorHex == hex ? 0.95 : 0.15), lineWidth: 2.5)
                        }
                        .contentShape(Circle())
                        .onTapGesture { colorHex = hex; erasing = false }
                }
            }

            HStack(spacing: 8) {
                ForEach(Array(widths.enumerated()), id: \.offset) { pair in
                    let w = pair.element
                    let on = abs(lineWidth - w) < 0.5
                    Button { lineWidth = w } label: {
                        Circle()
                            .fill(erasing ? Color.secondary : Color(hex: colorHex))
                            .frame(width: min(w + 6, 26), height: min(w + 6, 26))
                            .frame(width: 38, height: 34)
                            .background(on ? Color.primary.opacity(0.12) : Color.clear,
                                       in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Button { erasing.toggle() } label: {
                    Image(systemName: "eraser.fill")
                        .frame(width: 38, height: 34)
                        .foregroundStyle(erasing ? Theme.accent : Color.secondary)
                        .background(erasing ? Theme.accent.opacity(0.15) : Color.clear,
                                   in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 2)

                if let exportImage {
                    ShareLink(item: exportImage,
                              preview: SharePreview("Doodle", image: exportImage)) {
                        Image(systemName: "square.and.arrow.up").frame(width: 40, height: 34).contentShape(Rectangle())
                    }
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 40, height: 34)
                        .foregroundStyle(.tertiary)
                }
                Button { store.undo() } label: {
                    Image(systemName: "arrow.uturn.backward").frame(width: 40, height: 34).contentShape(Rectangle())
                }
                .disabled(store.strokes.isEmpty)
                Button(role: .destructive) { store.clear() } label: {
                    Image(systemName: "trash").frame(width: 40, height: 34).contentShape(Rectangle())
                }
                .disabled(store.strokes.isEmpty)
            }
            .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
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
                    store.append(DoodleStroke(points: currentPoints,
                                              colorHex: strokeHex, width: strokeWidth))
                }
                currentPoints = []
            }
    }

    private var strokeHex: String { erasing ? DoodleCanvas.eraseHex : colorHex }
    private var strokeWidth: Double { erasing ? lineWidth * 2.4 : lineWidth }

    private var liveStroke: DoodleCanvas.Live? {
        guard currentPoints.count > 1 else { return nil }
        return DoodleCanvas.Live(points: currentPoints, colorHex: strokeHex, width: strokeWidth)
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

    /// Sentinel colour that means "erase what's already drawn".
    static let eraseHex = "__erase__"

    var strokes: [DoodleStroke]
    var live: Live?

    var body: some View {
        Canvas { ctx, size in
            for stroke in strokes {
                paint(&ctx, points: stroke.points, hex: stroke.colorHex, width: stroke.width, size: size)
            }
            if let live, live.points.count > 1 {
                paint(&ctx, points: live.points, hex: live.colorHex, width: live.width, size: size)
            }
        }
    }

    private func paint(_ ctx: inout GraphicsContext, points: [CGPoint], hex: String, width: Double, size: CGSize) {
        let path = Self.smoothPath(points, size)
        if hex == Self.eraseHex {
            var eraser = ctx
            eraser.blendMode = .destinationOut
            eraser.stroke(path, with: .color(.black), style: Self.style(width))
        } else {
            ctx.stroke(path, with: .color(Color(hex: hex)), style: Self.style(width))
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
