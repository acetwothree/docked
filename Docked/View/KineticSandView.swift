//
//  KineticSandView.swift
//  Docked
//
//  A zen sand tray. Drag to rake grooves in the sand; "Smooth" flattens it
//  again. Session only — it's a fidget.
//

import SwiftUI

struct KineticSandView: View {
    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []

    private let sand = Color(red: 0.90, green: 0.83, blue: 0.68)
    private let groove = Color(red: 0.74, green: 0.65, blue: 0.49)
    private let ridge = Color(red: 0.97, green: 0.92, blue: 0.80)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(sand))
                for s in strokes { rake(&ctx, s) }
                if current.count > 1 { rake(&ctx, current) }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in current.append(v.location) }
                    .onEnded { _ in
                        if current.count > 1 { strokes.append(current) }
                        current = []
                    }
            )

            Button {
                strokes = []
                current = []
            } label: {
                Label("Smooth", systemImage: "wind")
                    .font(.system(size: 12, weight: .heavy))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .padding(14)
        }
    }

    private func rake(_ ctx: inout GraphicsContext, _ pts: [CGPoint]) {
        var path = Path()
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.addLine(to: p) }
        ctx.stroke(path, with: .color(groove), style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(ridge.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        ctx.stroke(path, with: .color(sand), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
        ctx.stroke(path, with: .color(groove.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }
}
