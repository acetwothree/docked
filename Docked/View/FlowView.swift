//
//  FlowView.swift
//  Docked
//
//  Renders `FlowModel`. The grid fills the module rect (minus a small
//  margin); the Canvas and the drag gesture share one coordinate space so
//  the pipe tracks the finger exactly.
//

import SwiftUI

struct FlowView: View {
    @Environment(AppModel.self) private var app
    @State private var model = FlowModel()
    @State private var active: Int? = nil
    @State private var didResume = false

    var body: some View {
        GeometryReader { geo in
            let g = grid(for: geo.size)

            ZStack(alignment: .topLeading) {
                Color.clear
                Canvas { ctx, _ in draw(&ctx, g: g) }
                    .allowsHitTesting(false)

                // HUD floats in the top-left / top-right so it steals no room
                HStack(spacing: 8) {
                    Text("LEVEL \(model.levelIndex + 1)")
                        .font(.system(size: 13, weight: .heavy)).tracking(1)
                        .foregroundStyle(.secondary)
                    Text("\(model.filledCount)/\(model.cellCount) filled")
                        .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(model.filledCount == model.cellCount ? Color.green : Color.secondary)
                    Spacer()
                    Button { model.restart(); active = nil } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }
            .contentShape(Rectangle())
            .coordinateSpace(.named("flow"))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("flow"))
                    .onChanged { v in
                        let cell = cellAt(v.location, g)
                        if active == nil {
                            if let start = model.begin(at: cell) { active = start }
                        } else if let color = active {
                            model.extend(color, to: cell)
                        }
                    }
                    .onEnded { _ in
                        if let color = active { model.end(color) }
                        active = nil
                    }
            )
        }
        .sensoryFeedback(.success, trigger: model.completions) { _, _ in app.haptics }
        .onAppear {
            if !didResume { model.resume(at: app.flowLevel); didResume = true }
        }
        .onChange(of: model.levelIndex) { _, v in app.flowLevel = v }
    }

    // MARK: geometry (one coordinate space — the whole GeometryReader)

    private struct Grid { var n: Int; var cell: CGFloat; var ox: CGFloat; var oy: CGFloat }

    private func grid(for size: CGSize) -> Grid {
        let n = model.size
        // The HUD is a single thin line pinned top-left / top-right, so the
        // board only needs to clear a small strip — keep it tight so the grid
        // stays as large as possible, especially in the tiny corner layouts.
        let topReserve: CGFloat = size.height < 260 ? 24 : 30
        let m: CGFloat = 6
        let maxW = size.width - m * 2
        let maxH = size.height - topReserve - m
        let side = max(60, min(maxW, maxH))
        let cell = (side / CGFloat(n)).rounded(.down)
        let used = cell * CGFloat(n)
        let ox = (size.width - used) / 2
        // Pool leftover vertical space *below* the board (bias it up under the
        // HUD) instead of centring — otherwise a wide-short layout leaves a big
        // empty gap between the level label and the grid.
        let oy = topReserve + max(0, maxH - used) * 0.18
        return Grid(n: n, cell: cell, ox: ox, oy: oy)
    }

    private func center(_ c: FlowCell, _ g: Grid) -> CGPoint {
        CGPoint(x: g.ox + (CGFloat(c.c) + 0.5) * g.cell,
                y: g.oy + (CGFloat(c.r) + 0.5) * g.cell)
    }
    private func cellAt(_ p: CGPoint, _ g: Grid) -> FlowCell {
        FlowCell(r: Int(((p.y - g.oy) / g.cell).rounded(.down)),
                 c: Int(((p.x - g.ox) / g.cell).rounded(.down)))
    }

    // MARK: drawing

    private func draw(_ ctx: inout GraphicsContext, g: Grid) {
        for r in 0..<g.n {
            for c in 0..<g.n {
                let rect = CGRect(x: g.ox + CGFloat(c) * g.cell + 2,
                                  y: g.oy + CGFloat(r) * g.cell + 2,
                                  width: g.cell - 4, height: g.cell - 4)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 6),
                         with: .color(Color.primary.opacity(0.06)))
            }
        }
        for (color, path) in model.paths where path.count >= 2 {
            var line = Path()
            line.move(to: center(path[0], g))
            for cell in path.dropFirst() { line.addLine(to: center(cell, g)) }
            ctx.stroke(line,
                       with: .color(FlowPalette.colors[color % FlowPalette.colors.count]),
                       style: StrokeStyle(lineWidth: g.cell * 0.4, lineCap: .round, lineJoin: .round))
        }
        for (color, pair) in model.endpoints {
            let col = FlowPalette.colors[color % FlowPalette.colors.count]
            for cell in [pair.0, pair.1] {
                let p = center(cell, g)
                let d = g.cell * 0.58
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - d/2, y: p.y - d/2, width: d, height: d)),
                         with: .color(col))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - d*0.16, y: p.y - d*0.16, width: d*0.32, height: d*0.32)),
                         with: .color(.white.opacity(0.6)))
            }
        }
    }
}
