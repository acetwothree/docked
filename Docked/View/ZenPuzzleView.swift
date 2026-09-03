//
//  ZenPuzzleView.swift
//  Docked
//
//  "Blocks" — a 7x7 grid between the video and the tab bar, a 3-slot dock
//  hugging the tab-bar edge, drag-to-place with a live ghost, and a soft
//  flash when a line clears. Out of moves auto-resets.
//

import SwiftUI

struct ZenPuzzleView: View {
    @Environment(AppModel.self) private var app

    var tabsAreHeader: Bool
    var layoutKey: VideoLayout

    @State private var model: ZenPuzzleModel
    @State private var drag: DragState? = nil

    init(tabsAreHeader: Bool, layoutKey: VideoLayout, highScore: Int) {
        self.tabsAreHeader = tabsAreHeader
        self.layoutKey = layoutKey
        _model = State(initialValue: ZenPuzzleModel(highScore: highScore))
    }

    private struct DragState {
        var slot: Int
        var shape: ZenShape
        var location: CGPoint
    }

    private let dockH: CGFloat = 122

    var body: some View {
        GeometryReader { geo in
            let g = Self.geom(size: geo.size, dockH: dockH, dockAtTop: tabsAreHeader)

            ZStack(alignment: .topLeading) {
                Color.clear
                Canvas { ctx, _ in draw(&ctx, g: g) }

                clearFlash(g)

                dockBar(g)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: tabsAreHeader ? .top : .bottom)

                if let d = drag { sprite(for: d, g: g) }

                if model.phase == .over {
                    VStack(spacing: 4) {
                        Text("No moves left").font(.system(size: 19, weight: .black))
                        Text("score \(model.score) · resetting…")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.55))
                }
            }
            .coordinateSpace(.named("zen"))
            .onAppear { model.configure(cols: g.cols, rows: g.rows) }
            .onChange(of: ConfigKey(size: geo.size, header: tabsAreHeader)) { _, _ in
                model.configure(cols: g.cols, rows: g.rows)
            }
        }
        .onChange(of: layoutKey) { _, _ in model.resetRun() }
        .onChange(of: model.phase) { _, phase in
            if phase == .over {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { model.resetRun() }
            }
        }
        .onChange(of: model.highScore) { _, v in app.zenHighScore = v }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: model.placeEvents)
        .sensoryFeedback(.success, trigger: model.clearEvents)
        .sensoryFeedback(.error, trigger: model.phase) { _, phase in phase == .over }
    }

    private struct ConfigKey: Equatable { var size: CGSize; var header: Bool }

    // MARK: Line-clear flash (lowkey)

    @ViewBuilder private func clearFlash(_ g: ZenGeom) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.clearing), id: \.self) { key in
                let p = key.split(separator: ",").compactMap { Int($0) }
                if p.count == 2 {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.5))
                        .blendMode(.plusLighter)
                        .frame(width: g.cell, height: g.cell)
                        .position(x: g.ox + CGFloat(p[1]) * (g.cell + g.gap) + g.cell / 2,
                                  y: g.oy + CGFloat(p[0]) * (g.cell + g.gap) + g.cell / 2)
                        .transition(.scale(scale: 1.25).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: model.clearing)
        .allowsHitTesting(false)
    }

    // MARK: Dock

    private func dockBar(_ g: ZenGeom) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("\(model.score)").font(.system(size: 20, weight: .black)).monospacedDigit()
                Text("BEST \(max(model.highScore, model.score))")
                    .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    dockSlot(i, g)
                    if i < 2 { Spacer(minLength: 0) }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, tabsAreHeader ? 14 : 10)
        .padding(.bottom, tabsAreHeader ? 10 : 14)
        .frame(height: dockH)
        .frame(maxWidth: .infinity)
        .background(Theme.elevated.opacity(0.92))
    }

    private func dockSlot(_ i: Int, _ g: ZenGeom) -> some View {
        let slotW: CGFloat = 104, slotH: CGFloat = 60
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline)
                }
            if let shape = model.dock[i], drag?.slot != i {
                thumbnail(shape, maxW: slotW - 18, maxH: slotH - 16)
            }
        }
        .frame(width: slotW, height: slotH)
        .opacity(model.dock[i] == nil || drag?.slot == i ? 0.26 : 1)
        .contentShape(Rectangle())
        .gesture(dragGesture(slot: i, g: g))
    }

    private func thumbnail(_ shape: ZenShape, maxW: CGFloat, maxH: CGFloat) -> some View {
        let gap: CGFloat = 2.5
        let dot = min(maxW / CGFloat(shape.width), maxH / CGFloat(shape.height), 22) - gap
        let filled = Set(shape.cells.map { "\($0.0),\($0.1)" })
        return VStack(spacing: gap) {
            ForEach(Array(0..<shape.height), id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(Array(0..<shape.width), id: \.self) { c in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(filled.contains("\(r),\(c)") ? AnyShapeStyle(shape.gradient) : AnyShapeStyle(Color.clear))
                            .frame(width: dot, height: dot)
                    }
                }
            }
        }
    }

    // MARK: Drag

    private func dragGesture(slot i: Int, g: ZenGeom) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("zen"))
            .onChanged { v in
                guard model.phase == .play, let shape = model.dock[i] else { return }
                drag = DragState(slot: i, shape: shape, location: v.location)
            }
            .onEnded { _ in
                guard let d = drag else { return }
                let anchor = Self.anchorCell(location: d.location, shape: d.shape, g: g)
                model.place(slot: d.slot, shape: d.shape, atRow: anchor.row, col: anchor.col)
                drag = nil
            }
    }

    private func sprite(for d: DragState, g: ZenGeom) -> some View {
        let w = CGFloat(d.shape.width) * (g.cell + g.gap) - g.gap
        let h = CGFloat(d.shape.height) * (g.cell + g.gap) - g.gap
        let anchor = Self.anchorCell(location: d.location, shape: d.shape, g: g)
        let ok = model.canPlace(d.shape, atRow: anchor.row, col: anchor.col)
        let filled = Set(d.shape.cells.map { "\($0.0),\($0.1)" })
        return VStack(spacing: g.gap) {
            ForEach(Array(0..<d.shape.height), id: \.self) { r in
                HStack(spacing: g.gap) {
                    ForEach(Array(0..<d.shape.width), id: \.self) { c in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(filled.contains("\(r),\(c)") ? AnyShapeStyle(d.shape.gradient) : AnyShapeStyle(Color.clear))
                            .frame(width: g.cell, height: g.cell)
                    }
                }
            }
        }
        .frame(width: w, height: h)
        .opacity(ok ? 0.95 : 0.55)
        .position(x: d.location.x, y: d.location.y - h / 2 - 18)
        .allowsHitTesting(false)
    }

    // MARK: Canvas grid

    private func draw(_ ctx: inout GraphicsContext, g: ZenGeom) {
        for r in 0..<g.rows {
            for c in 0..<g.cols {
                let rect = CGRect(x: g.ox + CGFloat(c) * (g.cell + g.gap),
                                  y: g.oy + CGFloat(r) * (g.cell + g.gap),
                                  width: g.cell, height: g.cell)
                let path = Path(roundedRect: rect, cornerRadius: 6)
                let cleared = model.clearing.contains("\(r),\(c)")

                if model.board.indices.contains(r), model.board[r].indices.contains(c),
                   let palette = model.board[r][c], !cleared {
                    ctx.fill(path, with: .linearGradient(
                        Gradient(colors: palette),
                        startPoint: rect.origin,
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                    ctx.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 3)),
                             with: .color(.white.opacity(0.28)))
                    ctx.fill(Path(CGRect(x: rect.minX, y: rect.maxY - 3, width: rect.width, height: 3)),
                             with: .color(.black.opacity(0.28)))
                } else {
                    ctx.fill(path, with: .color(Color.primary.opacity(0.055)))
                }
            }
        }

        if let d = drag {
            let anchor = Self.anchorCell(location: d.location, shape: d.shape, g: g)
            let ok = model.canPlace(d.shape, atRow: anchor.row, col: anchor.col)
            for (dr, dc) in d.shape.cells {
                let r = anchor.row + dr, c = anchor.col + dc
                guard r >= 0, c >= 0, r < g.rows, c < g.cols else { continue }
                let rect = CGRect(x: g.ox + CGFloat(c) * (g.cell + g.gap),
                                  y: g.oy + CGFloat(r) * (g.cell + g.gap),
                                  width: g.cell, height: g.cell)
                ctx.stroke(Path(roundedRect: rect, cornerRadius: 6),
                           with: .color(ok ? Color(hex: "3ECF7A") : Color(hex: "FF6B6B")),
                           lineWidth: 3)
            }
        }
    }

    // MARK: Geometry

    struct ZenGeom: Equatable {
        var cols = 7, rows = 7
        var cell: CGFloat = 44, gap: CGFloat = 4, ox: CGFloat = 0, oy: CGFloat = 0
    }

    static func anchorCell(location: CGPoint, shape: ZenShape, g: ZenGeom) -> (row: Int, col: Int) {
        let w = CGFloat(shape.width) * (g.cell + g.gap) - g.gap
        let h = CGFloat(shape.height) * (g.cell + g.gap) - g.gap
        let topLeftX = location.x - w / 2
        let topLeftY = location.y - h - 18
        let col = Int(((topLeftX - g.ox) / (g.cell + g.gap)).rounded())
        let row = Int(((topLeftY - g.oy) / (g.cell + g.gap)).rounded())
        return (row, col)
    }

    /// A 7x7 grid, sized to fit both the width and the height of the space
    /// between the dock and the video.
    static func geom(size: CGSize, dockH: CGFloat, dockAtTop: Bool) -> ZenGeom {
        let W = size.width, H = size.height
        let pad: CGFloat = 8
        let top = dockAtTop ? dockH + pad : pad
        let bot = dockAtTop ? H - pad : H - dockH - pad
        let gw = W - 12, gh = max(40, bot - top)
        let n: CGFloat = 7
        let gap: CGFloat = 4
        let cell = min(max((min((gw - (n - 1) * gap) / n, (gh - (n - 1) * gap) / n)).rounded(.down), 34), 58)
        let used = n * cell + (n - 1) * gap
        let ox = (W - used) / 2
        let oy = top + (gh - used) / 2
        return ZenGeom(cols: 7, rows: 7, cell: cell, gap: gap, ox: ox, oy: max(top, oy))
    }
}
