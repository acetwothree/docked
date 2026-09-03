//
//  FlowView.swift
//  Docked
//
//  Renders `FlowModel`: drag from a dot to its twin to lay a coloured pipe.
//  Connect every pair and the level advances on its own.
//

import SwiftUI

struct FlowView: View {
    @State private var model = FlowModel(reached: 0)
    @State private var active: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let g = layout(in: geo.size)

            VStack(spacing: 0) {
                HStack {
                    Text("LEVEL \(model.levelIndex + 1)")
                        .font(.system(size: 13, weight: .heavy)).tracking(1)
                    Spacer()
                    Button {
                        model.restart(); active = nil
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)

                ZStack {
                    Canvas { ctx, _ in draw(&ctx, g: g) }
                        .frame(width: g.side, height: g.side)
                        .contentShape(Rectangle())
                        .gesture(drag(g))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .coordinateSpace(.named("flow"))
        }
        .sensoryFeedback(.success, trigger: model.completions)
    }

    // MARK: geometry

    private struct Geo { var side: CGFloat; var cell: CGFloat; var ox: CGFloat; var oy: CGFloat; var n: Int }

    private func layout(in size: CGSize) -> Geo {
        let n = model.size
        let avail = min(size.width - 24, size.height - 44 - 24)
        let side = max(80, avail)
        let cell = side / CGFloat(n)
        let ox = (size.width - side) / 2
        let oy = 44 + (size.height - 44 - side) / 2
        return Geo(side: side, cell: cell, ox: ox, oy: max(44, oy), n: n)
    }

    private func center(_ cell: FlowCell, _ g: Geo) -> CGPoint {
        CGPoint(x: g.ox + (CGFloat(cell.c) + 0.5) * g.cell,
                y: g.oy + (CGFloat(cell.r) + 0.5) * g.cell)
    }
    private func cellAt(_ p: CGPoint, _ g: Geo) -> FlowCell {
        FlowCell(r: Int(((p.y - g.oy) / g.cell).rounded(.down)),
                 c: Int(((p.x - g.ox) / g.cell).rounded(.down)))
    }

    // MARK: drawing

    private func draw(_ ctx: inout GraphicsContext, g: Geo) {
        // grid
        for r in 0..<g.n {
            for c in 0..<g.n {
                let rect = CGRect(x: g.ox + CGFloat(c) * g.cell + 1.5,
                                  y: g.oy + CGFloat(r) * g.cell + 1.5,
                                  width: g.cell - 3, height: g.cell - 3)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 5),
                         with: .color(Color.primary.opacity(0.06)))
            }
        }
        // pipes
        for (color, path) in model.paths where path.count >= 2 {
            var line = Path()
            line.move(to: center(path[0], g))
            for cell in path.dropFirst() { line.addLine(to: center(cell, g)) }
            ctx.stroke(line, with: .color(FlowPalette.colors[color % FlowPalette.colors.count]),
                       style: StrokeStyle(lineWidth: g.cell * 0.42, lineCap: .round, lineJoin: .round))
        }
        // endpoints
        for (color, pair) in model.endpoints {
            let col = FlowPalette.colors[color % FlowPalette.colors.count]
            for cell in [pair.0, pair.1] {
                let ctr = center(cell, g)
                let d = g.cell * 0.56
                ctx.fill(Path(ellipseIn: CGRect(x: ctr.x - d/2, y: ctr.y - d/2, width: d, height: d)),
                         with: .color(col))
                ctx.fill(Path(ellipseIn: CGRect(x: ctr.x - d/6, y: ctr.y - d/6, width: d/3, height: d/3)),
                         with: .color(.white.opacity(0.55)))
            }
        }
    }

    // MARK: drag

    private func drag(_ g: Geo) -> some Gesture {
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
    }
}
