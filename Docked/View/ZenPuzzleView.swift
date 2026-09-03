//
//  ZenPuzzleView.swift
//  Docked
//
//  Renders `ZenPuzzleModel`: a grid that fills the space around the video,
//  a 3-slot dock, and drag-to-place with a live ghost. Grid + blocks are
//  drawn in a Canvas; the dock and drag sprite are plain views.
//

import SwiftUI

struct ZenPuzzleView: View {
    @Environment(AppModel.self) private var app

    /// Video slot in this view's local coordinates.
    var videoRectInField: CGRect
    var tabsAreHeader: Bool
    var isBandLayout: Bool
    /// Changes whenever the video layout changes — triggers a run reset.
    var layoutKey: VideoLayout

    @State private var model: ZenPuzzleModel
    @State private var drag: DragState? = nil

    init(videoRectInField: CGRect, tabsAreHeader: Bool, isBandLayout: Bool, layoutKey: VideoLayout, highScore: Int) {
        self.videoRectInField = videoRectInField
        self.tabsAreHeader = tabsAreHeader
        self.isBandLayout = isBandLayout
        self.layoutKey = layoutKey
        _model = State(initialValue: ZenPuzzleModel(highScore: highScore))
    }

    private struct DragState {
        var slot: Int
        var shape: ZenShape
        var location: CGPoint
    }

    private struct ConfigKey: Equatable {
        var size: CGSize; var video: CGRect; var header: Bool; var band: Bool
    }

    var body: some View {
        GeometryReader { geo in
            let g = Self.geom(size: geo.size, video: videoRectInField,
                              tabsHeader: tabsAreHeader, band: isBandLayout)

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in draw(&ctx, g: g) }

                dockBar(g)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: tabsAreHeader ? .top : .bottom)

                if let d = drag { sprite(for: d, g: g) }

                if model.phase == .over {
                    VStack(spacing: 4) {
                        Text("No moves left").font(.system(size: 18, weight: .black))
                        Text("score \(model.score) · resetting…")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.5))
                }
            }
            .coordinateSpace(.named("zen"))
            .onAppear { model.configure(cols: g.cols, rows: g.rows, blockedMask: g.mask) }
            .onChange(of: ConfigKey(size: geo.size, video: videoRectInField,
                                    header: tabsAreHeader, band: isBandLayout)) { _, _ in
                model.configure(cols: g.cols, rows: g.rows, blockedMask: g.mask)
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

    // MARK: Dock

    private func dockBar(_ g: ZenGeom) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("\(model.score)")
                    .font(.system(size: 18, weight: .black)).monospacedDigit()
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
            .padding(.horizontal, 14)
        }
        .frame(height: 84)
        .frame(maxWidth: .infinity)
        .background(Theme.elevated.opacity(0.85))
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
        .frame(width: 96, height: 66)
        .opacity(model.dock[i] == nil || drag?.slot == i ? 0.28 : 1)
        .contentShape(Rectangle())
        .gesture(dragGesture(slot: i, g: g))
    }

    private func thumbnail(_ shape: ZenShape) -> some View {
        let dot: CGFloat = 12, gap: CGFloat = 3
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
        let originY = d.location.y - h - 16
        let anchor = Self.anchorCell(location: d.location, shape: d.shape, g: g)
        let ok = model.canPlace(d.shape, atRow: anchor.row, col: anchor.col)
        let filled = Set(d.shape.cells.map { "\($0.0),\($0.1)" })
        return VStack(spacing: 2) {
            ForEach(Array(0..<d.shape.height), id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(Array(0..<d.shape.width), id: \.self) { c in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(filled.contains("\(r),\(c)") ? AnyShapeStyle(d.shape.gradient) : AnyShapeStyle(Color.clear))
                            .frame(width: g.cell - 2, height: g.cell - 2)
                    }
                }
            }
        }
        .frame(width: w, height: h)
        .opacity(ok ? 0.95 : 0.6)
        .position(x: originX + w / 2, y: originY + h / 2)
        .allowsHitTesting(false)
    }

    // MARK: Canvas grid

    private func draw(_ ctx: inout GraphicsContext, g: ZenGeom) {
        for r in 0..<g.rows {
            for c in 0..<g.cols {
                let rect = CGRect(x: g.ox + CGFloat(c) * (g.cell + 2),
                                  y: g.oy + CGFloat(r) * (g.cell + 2),
                                  width: g.cell, height: g.cell)
                let path = Path(roundedRect: rect, cornerRadius: 4)
                let isBlocked = g.mask.indices.contains(r) && g.mask[r].indices.contains(c) && g.mask[r][c]
                let cleared = model.clearing.contains("\(r),\(c)")

                if isBlocked {
                    ctx.fill(path, with: .color(Color(hex: "1B1B23")))
                    var hatch = ctx
                    hatch.clip(to: path)
                    var lines = Path()
                    var x = rect.minX - rect.height
                    while x < rect.maxX {
                        lines.move(to: CGPoint(x: x, y: rect.maxY))
                        lines.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
                        x += 6
                    }
                    hatch.stroke(lines, with: .color(Color.white.opacity(0.07)), lineWidth: 2)
                } else if model.board.indices.contains(r), model.board[r].indices.contains(c),
                          let palette = model.board[r][c], !cleared {
                    ctx.fill(path, with: .linearGradient(
                        Gradient(colors: palette),
                        startPoint: rect.origin,
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                    ctx.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 2)),
                             with: .color(.white.opacity(0.25)))
                    ctx.fill(Path(CGRect(x: rect.minX, y: rect.maxY - 2, width: rect.width, height: 2)),
                             with: .color(.black.opacity(0.25)))
                } else {
                    ctx.fill(path, with: .color(Color.primary.opacity(0.05)))
                }
            }
        }

        // ghost
        if let d = drag {
            let anchor = Self.anchorCell(location: d.location, shape: d.shape, g: g)
            let ok = model.canPlace(d.shape, atRow: anchor.row, col: anchor.col)
            for (dr, dc) in d.shape.cells {
                let r = anchor.row + dr, c = anchor.col + dc
                guard r >= 0, c >= 0, r < g.rows, c < g.cols else { continue }
                let rect = CGRect(x: g.ox + CGFloat(c) * (g.cell + 2),
                                  y: g.oy + CGFloat(r) * (g.cell + 2),
                                  width: g.cell, height: g.cell)
                ctx.stroke(Path(roundedRect: rect, cornerRadius: 4),
                           with: .color(ok ? Color(hex: "3ECF7A") : Color(hex: "FF6B6B")),
                           lineWidth: 2)
            }
        }
    }

    // MARK: Geometry

    struct ZenGeom: Equatable {
        var cols = 0, rows = 0
        var cell: CGFloat = 30, ox: CGFloat = 0, oy: CGFloat = 0
        var mask: [[Bool]] = []
    }

    static func anchorCell(location: CGPoint, shape: ZenShape, g: ZenGeom) -> (row: Int, col: Int) {
        let w = CGFloat(shape.width) * g.cell
        let h = CGFloat(shape.height) * g.cell
        let topLeftX = location.x - w / 2
        let topLeftY = location.y - h - 16
        let col = Int(((topLeftX - g.ox) / (g.cell + 2)).rounded())
        let row = Int(((topLeftY - g.oy) / (g.cell + 2)).rounded())
        return (row, col)
    }

    static func geom(size: CGSize, video: CGRect, tabsHeader: Bool, band: Bool) -> ZenGeom {
        let W = size.width, H = size.height
        let dockH: CGFloat = 84
        var top: CGFloat = 8, bot: CGFloat = H - 8
        if tabsHeader { top = dockH + 8 } else { bot = H - dockH - 8 }
        if band {
            if video.minY < H / 2 { top = max(top, video.maxY + 12) }
            else { bot = min(bot, video.minY - 12) }
        }
        let gw = W - 16, gh = max(40, bot - top)
        // Bigger, chunkier cells — roughly 7 columns, fewer squares overall.
        let cell = min(max((min(gw / 7.2, gh / 12)).rounded(), 42), 62)
        let cols = max(4, Int((gw + 2) / (cell + 2)))
        let rows = max(4, Int((gh + 2) / (cell + 2)))
        let usedW = CGFloat(cols) * cell + CGFloat(cols - 1) * 2
        let usedH = CGFloat(rows) * cell + CGFloat(rows - 1) * 2
        let ox = 8 + (gw - usedW) / 2
        let oy = top + (gh - usedH) / 2

        let mask: [[Bool]] = (0..<rows).map { r in
            (0..<cols).map { c in
                guard !band else { return false }
                let cx = ox + CGFloat(c) * (cell + 2)
                let cy = oy + CGFloat(r) * (cell + 2)
                return cx < video.maxX + 6 && cx + cell > video.minX - 6
                    && cy < video.maxY + 6 && cy + cell > video.minY - 6
            }
        }
        return ZenGeom(cols: cols, rows: rows, cell: cell, ox: ox, oy: oy, mask: mask)
    }
}
