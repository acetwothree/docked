//
//  ZenPuzzleView.swift
//  Docked
//
//  "Blocks" — renders `ZenPuzzleModel`. A clean rectangular grid fills the
//  space between the video and the tab bar; a 3-slot dock hugs the tab-bar
//  edge. Drag a piece onto the grid; full rows / columns clear; out of moves
//  auto-resets. No greyed cells — the grid never overlaps the video.
//

import SwiftUI

struct ZenPuzzleView: View {
    @Environment(AppModel.self) private var app

    var tabsAreHeader: Bool
    /// Changes whenever the video layout changes — triggers a run reset.
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

    private let dockH: CGFloat = 88

    var body: some View {
        GeometryReader { geo in
            let g = Self.geom(size: geo.size, dockH: dockH, dockAtTop: tabsAreHeader)

            ZStack(alignment: .topLeading) {
                Color.clear
                Canvas { ctx, _ in draw(&ctx, g: g) }

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
    }

    private struct ConfigKey: Equatable { var size: CGSize; var header: Bool }

    // MARK: Dock

    private func dockBar(_ g: ZenGeom) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("\(model.score)")
                    .font(.system(size: 19, weight: .black)).monospacedDigit()
                Text("· Best \(max(model.highScore, model.score))")
                    .font(.system(size: 12, weight: .bold)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                dockSlot(0, g)
                Spacer(minLength: 0)
                dockSlot(1, g)
                Spacer(minLength: 0)
                dockSlot(2, g)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .frame(height: dockH)
        .frame(maxWidth: .infinity)
        .background(Theme.elevated.opacity(0.9))
    }

    private func dockSlot(_ i: Int, _ g: ZenGeom) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline)
                }
            if let shape = model.dock[i], drag?.slot != i {
                thumbnail(shape)
            }
        }
        .frame(width: 98, height: 62)
        .opacity(model.dock[i] == nil || drag?.slot == i ? 0.28 : 1)
        .contentShape(Rectangle())
        .gesture(dragGesture(slot: i, g: g))
    }

    private func thumbnail(_ shape: ZenShape) -> some View {
        let dot: CGFloat = 11, gap: CGFloat = 3
        let filled = Set(shape.cells.map { "\($0.0),\($0.1)" })
        return VStack(spacing: gap) {
            ForEach(Array(0..<shape.height), id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(Array(0..<shape.width), id: \.self) { c in
                        RoundedRectangle(cornerRadius: 3)
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
        let w = CGFloat(d.shape.width) * g.cell
        let h = CGFloat(d.shape.height) * g.cell
        let originX = d.location.x - w / 2
        let originY = d.location.y - h - 18
        let anchor = Self.anchorCell(location: d.location, shape: d.shape, g: g)
        let ok = model.canPlace(d.shape, atRow: anchor.row, col: anchor.col)
        let filled = Set(d.shape.cells.map { "\($0.0),\($0.1)" })
        return VStack(spacing: 2) {
            ForEach(Array(0..<d.shape.height), id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(Array(0..<d.shape.width), id: \.self) { c in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(filled.contains("\(r),\(c)") ? AnyShapeStyle(d.shape.gradient) : AnyShapeStyle(Color.clear))
                            .frame(width: g.cell - 2, height: g.cell - 2)
                    }
                }
            }
        }
        .frame(width: w, height: h)
        .opacity(ok ? 0.95 : 0.55)
        .position(x: originX + w / 2, y: originY + h / 2)
        .allowsHitTesting(false)
    }

    // MARK: Canvas grid

    private func draw(_ ctx: inout GraphicsContext, g: ZenGeom) {
        for r in 0..<g.rows {
            for c in 0..<g.cols {
                let rect = CGRect(x: g.ox + CGFloat(c) * (g.cell + 3),
                                  y: g.oy + CGFloat(r) * (g.cell + 3),
                                  width: g.cell, height: g.cell)
                let path = Path(roundedRect: rect, cornerRadius: 5)
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
                let rect = CGRect(x: g.ox + CGFloat(c) * (g.cell + 3),
                                  y: g.oy + CGFloat(r) * (g.cell + 3),
                                  width: g.cell, height: g.cell)
                ctx.stroke(Path(roundedRect: rect, cornerRadius: 5),
                           with: .color(ok ? Color(hex: "3ECF7A") : Color(hex: "FF6B6B")),
                           lineWidth: 3)
            }
        }
    }

    // MARK: Geometry

    struct ZenGeom: Equatable {
        var cols = 0, rows = 0
        var cell: CGFloat = 44, ox: CGFloat = 0, oy: CGFloat = 0
    }

    static func anchorCell(location: CGPoint, shape: ZenShape, g: ZenGeom) -> (row: Int, col: Int) {
        let w = CGFloat(shape.width) * g.cell
        let h = CGFloat(shape.height) * g.cell
        let topLeftX = location.x - w / 2
        let topLeftY = location.y - h - 18
        let col = Int(((topLeftX - g.ox) / (g.cell + 3)).rounded())
        let row = Int(((topLeftY - g.oy) / (g.cell + 3)).rounded())
        return (row, col)
    }

    /// The grid fills the module rect minus the dock strip (which hugs the
    /// tab-bar edge). ~6 columns of big cells.
    static func geom(size: CGSize, dockH: CGFloat, dockAtTop: Bool) -> ZenGeom {
        let W = size.width, H = size.height
        let pad: CGFloat = 8
        let top = dockAtTop ? dockH + pad : pad
        let bot = dockAtTop ? H - pad : H - dockH - pad
        let gw = W - 12, gh = max(40, bot - top)

        let cell = min(max((min(gw / 6.3, gh / 11)).rounded(), 44), 66)
        let cols = max(3, Int((gw + 3) / (cell + 3)))
        let rows = max(3, Int((gh + 3) / (cell + 3)))
        let usedW = CGFloat(cols) * cell + CGFloat(cols - 1) * 3
        let usedH = CGFloat(rows) * cell + CGFloat(rows - 1) * 3
        let ox = (W - usedW) / 2
        let oy = top + (gh - usedH) / 2
        return ZenGeom(cols: cols, rows: rows, cell: cell, ox: ox, oy: oy)
    }
}
