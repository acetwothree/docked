//
//  KineticSandView.swift
//  Docked
//
//  A zen sand tray. Drag to rake grooves in the sand; "Smooth" sweeps a fresh
//  layer of sand over the tray and flattens it again. Session only — it's a
//  fidget.
//

import SwiftUI

struct KineticSandView: View {
    @Environment(AppModel.self) private var app
    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    /// 0 = grooves visible, 1 = fresh sand fully swept over the tray.
    @State private var smoothWipe: Double = 0
    @State private var smoothCount = 0

    private let sand = Color(red: 0.90, green: 0.83, blue: 0.68)
    private let groove = Color(red: 0.74, green: 0.65, blue: 0.49)
    private let ridge = Color(red: 0.97, green: 0.92, blue: 0.80)

    private var isSmooth: Bool { strokes.isEmpty && current.count < 2 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(sand))
                for s in strokes { rake(&ctx, s) }
                if current.count > 1 { rake(&ctx, current) }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in current.append(v.location) }
                    .onEnded { _ in
                        if current.count > 1 { strokes.append(current) }
                        current = []
                    }
            )
            .overlay {
                // The "smoothing" sweep: a fresh sheet of sand fades in over the
                // grooves, then fades back out once the tray has been cleared.
                Rectangle()
                    .fill(sand)
                    .opacity(smoothWipe)
                    .allowsHitTesting(false)
            }

            Button {
                smoothOver()
            } label: {
                Label("Smooth", systemImage: "wind")
                    .font(.system(size: 12, weight: .heavy))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.primary)
                    .opacity(isSmooth ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isSmooth)
            .padding(14)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: smoothCount) { _, _ in app.haptics }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: current.count) { _, _ in app.haptics && !current.isEmpty }
        .sensoryFeedback(.impact(weight: .light), trigger: strokes.count) { _, _ in app.haptics }
    }

    private func smoothOver() {
        guard !isSmooth else { return }
        smoothCount += 1
        withAnimation(.easeIn(duration: 0.28)) { smoothWipe = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            strokes = []
            current = []
            withAnimation(.easeOut(duration: 0.3)) { smoothWipe = 0 }
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
