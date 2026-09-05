//
//  ZenPuzzleView.swift
//  Docked
//
//  "Color Blocks" — a grid filling the game area, a 3-slot dock hugging its
//  bottom edge, drag-to-place with a live ghost, and a bright flash across
//  the exact row/column when a line clears. Out of moves auto-resets.
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

    var body: some View {
        GeometryReader { geo in
            // Dock shrinks with the available height so a stretched TV never
            // pushes the board off the bottom — it scales instead of clipping.
            let dockH = min(120, max(76, geo.size.height * 0.30))
            let g = Self.geom(size: geo.size, dockH: dockH, dockAtTop: tabsAreHeader)

            ZStack(alignment: .topLeading) {
                Color.clear
                Canvas { ctx, _ in draw(&ctx, g: g) }

                clearFlash(g)

                dockBar(g, dockH: dockH)
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
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: model.placeEvents) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: model.clearEvents) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: model.phase) { _, phase in app.haptics && phase == .over }
    }

    private struct ConfigKey: Equatable { var size: CGSize; var header: Bool }

    // MARK: Line-clear flash — a bright bar across the exact row/column that
    // cleared, so the animation reads as "that line" rather than scattered cells.

    @ViewBuilder private func clearFlash(_ g: ZenGeom) -> some View {
        let boardW = CGFloat(g.cols) * (g.cell + g.gap) - g.gap
        let boardH = CGFloat(g.rows) * (g.cell + g.gap) - g.gap
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.clearingRows), id: \.self) { r in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.9), .white.opacity(0.15)],
                                         startPoint: .leading, endPoint: .trailing))
                    .blendMode(.plusLighter)
                    .frame(width: boardW, height: g.cell)
                    .position(x: g.ox + boardW / 2, y: g.oy + CGFloat(r) * (g.cell + g.gap) + g.cell / 2)
                    .transition(.opacity)
            }
            ForEach(Array(model.clearingCols), id: \.self) { c in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.9), .white.opacity(0.15)],
                                         startPoint: .top, endPoint: .bottom))
                    .blendMode(.plusLighter)
                    .frame(width: g.cell, height: boardH)
                    .position(x: g.ox + CGFloat(c) * (g.cell + g.gap) + g.cell / 2, y: g.oy + boardH / 2)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.32), value: model.clearingRows)
        .animation(.easeOut(duration: 0.32), value: model.clearingCols)
        .allowsHitTesting(false)
    }

    // MARK: Dock

    private func dockBar(_ g: ZenGeom, dockH: CGFloat) -> some View {
        let compact = dockH < 104
        let slotH = min(58, dockH * 0.46)
        let slotW = slotH * 1.72
        return VStack(spacing: compact ? 5 : 10) {
            HStack(spacing: 6) {
                Text("\(model.score)").font(.system(size: compact ? 17 : 20, weight: .black)).monospacedDigit()
                Text("BEST \(max(model.highScore, model.score))")
                    .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    dockSlot(i, g, slotW: slotW, slotH: slotH)
                    if i < 2 { Spacer(minLength: 0) }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, tabsAreHeader ? (compact ? 8 : 14) : (compact ? 6 : 10))
        .padding(.bottom, tabsAreHeader ? (compact ? 6 : 10) : (compact ? 8 : 14))
        .frame(height: dockH)
        .frame(maxWidth: .infinity)
        .background(Theme.elevated.opacity(0.92))
    }

    private func dockSlot(_ i: Int, _ g: ZenGeom, slotW: CGFloat, slotH: CGFloat) -> some View {
        ZStack {
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
                        if filled.contains("\(r),\(c)") {
                            shadedBlock(shape.gradient, corner: 3).frame(width: dot, height: dot)
                        } else {
                            Color.clear.frame(width: dot, height: dot)
                        }
                    }
                }
            }
        }
    }

    /// A gradient-filled block with a bright top-left sheen and a dark
    /// bottom-right shadow, so the colours pop more than a flat fill.
    private func shadedBlock(_ fill: LinearGradient, corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(fill)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: corner / 2, style: .continuous)
                    .fill(.white.opacity(0.5))
                    .frame(height: max(1.5, corner))
                    .padding(.horizontal, max(1, corner * 0.6))
                    .padding(.top, 1)
            }
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: corner / 2, style: .continuous)
                    .fill(.black.opacity(0.35))
                    .frame(height: max(1.5, corner))
                    .padding(.horizontal, max(1, corner * 0.6))
                    .padding(.bottom, 1)
            }
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
    }

    // MARK: Drag

    private func dragGesture(slot i: Int, g: ZenGeom) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("zen"))
            .onChanged { v in
                guard model.phase == .play, let shape = model.dock[i] else { return }
                // Right at the dock the piece tracks the thumb closely. The
                // further up you drag, the more extra lift gets added on top
                // of the raw finger travel, so reaching the top rows of the
                // board never needs a full-length swipe.
                let dx = v.location.x - v.startLocation.x
                let dyRaw = v.location.y - v.startLocation.y   // negative = moving up
                let upTravel = max(0, -dyRaw)
                let upFrac = min(1, upTravel / 300)
                let gain: CGFloat = 1.05 + upFrac * 0.35       // 1.05× near the dock, up to 1.4× higher up
                let loc = CGPoint(
                    x: v.startLocation.x + dx * 1.1,
                    y: v.startLocation.y + dyRaw * gain)
                drag = DragState(slot: i, shape: shape, location: loc)
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
                        if filled.contains("\(r),\(c)") {
                            shadedBlock(d.shape.gradient, corner: 5).frame(width: g.cell, height: g.cell)
                        } else {
                            Color.clear.frame(width: g.cell, height: g.cell)
                        }
                    }
                }
            }
        }
        .frame(width: w, height: h)
        .opacity(ok ? 0.95 : 0.55)
        .position(x: d.location.x, y: d.location.y - h / 2 - 24)
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
                    // A punchier bevel — bright top+left sheen, dark bottom+right
                    // shadow — so each block reads as a raised, glossy piece.
                    let inset = rect.insetBy(dx: 2, dy: 2)
                    ctx.fill(Path(roundedRect: CGRect(x: inset.minX, y: inset.minY, width: inset.width, height: 4),
                                  cornerRadius: 2),
                             with: .color(.white.opacity(0.5)))
                    ctx.fill(Path(CGRect(x: inset.minX, y: inset.minY + 3, width: 2.5, height: inset.height - 6)),
                             with: .color(.white.opacity(0.3)))
                    ctx.fill(Path(roundedRect: CGRect(x: inset.minX, y: inset.maxY - 4, width: inset.width, height: 4),
                                  cornerRadius: 2),
                             with: .color(.black.opacity(0.4)))
                    ctx.fill(Path(CGRect(x: inset.maxX - 2.5, y: inset.minY + 3, width: 2.5, height: inset.height - 6)),
                             with: .color(.black.opacity(0.3)))
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
        var cols = 6, rows = 6
        var cell: CGFloat = 44, gap: CGFloat = 4, ox: CGFloat = 0, oy: CGFloat = 0
    }

    static func anchorCell(location: CGPoint, shape: ZenShape, g: ZenGeom) -> (row: Int, col: Int) {
        let w = CGFloat(shape.width) * (g.cell + g.gap) - g.gap
        let h = CGFloat(shape.height) * (g.cell + g.gap) - g.gap
        let topLeftX = location.x - w / 2
        let topLeftY = location.y - h - 24
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
        let n: CGFloat = 6
        let gap: CGFloat = 5
        // Floor low enough that the board always fits the space it's given
        // (a stretched TV shrinks it rather than clipping the bottom row).
        let cell = min(max((min((gw - (n - 1) * gap) / n, (gh - (n - 1) * gap) / n)).rounded(.down), 24), 66)
        let used = n * cell + (n - 1) * gap
        let ox = (W - used) / 2
        let oy = top + (gh - used) / 2
        return ZenGeom(cols: 6, rows: 6, cell: cell, gap: gap, ox: ox, oy: max(top, oy))
    }
}
