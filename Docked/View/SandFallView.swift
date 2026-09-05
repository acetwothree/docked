//
//  SandFallView.swift
//  Docked
//
//  "Crumble Drop" — coloured tetromino pieces fall smoothly, then crumble
//  into loose sand that trickles into gaps. A colour clears once a connected
//  patch of it spans every column from the left wall to the right wall.
//  Pieces don't rotate — drag left/right to slide them (they follow your
//  finger 1:1), and either tap or swipe down to drop instantly.
//
//  Settled grains keep a stable identity (`Grain.id`) across the model's
//  settle passes, so `ForEach(model.grains)` animates each one sliding to its
//  new cell — that's what gives the "sand flowing" look — rather than cells
//  just changing colour in place.
//

import SwiftUI
import Combine

struct SandFallView: View {
    @Environment(AppModel.self) private var app
    @State private var model: SandFallModel

    /// Net columns already applied for the drag in progress, so continued
    /// finger movement only applies the DELTA each time (free 1:1 tracking).
    @State private var dragAppliedCols = 0

    /// Ticks fast with an animation exactly as long as the gap between ticks,
    /// so one linear step's motion ends right as the next begins — that's
    /// what reads as a smooth continuous fall instead of a jerky hop.
    private static let fallInterval = 0.15
    private let fallTimer = Timer.publish(every: fallInterval, on: .main, in: .common).autoconnect()

    init(highScore: Int) {
        _model = State(initialValue: SandFallModel(best: highScore))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                stat("SCORE", model.score)
                Spacer()
                stat("BEST", max(model.best, model.score))
                Spacer()
                Button { model.resetRun() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geo in
                board(w: geo.size.width, h: geo.size.height)
            }

            Text(model.phase == .over ? "Sand piled up — resetting…" : "Drag left/right to slide · tap to drop")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(model.phase == .over ? Color.orange : Color.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(fallTimer) { _ in
            guard model.phase == .play else { return }
            withAnimation(.linear(duration: Self.fallInterval)) { _ = model.stepDown() }
        }
        .onChange(of: model.lockTick) { _, _ in settleLoop() }
        .onChange(of: model.overTick) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { model.resetRun() }
        }
        .onChange(of: model.best) { _, v in app.sandHighScore = v }
        .sensoryFeedback(.impact(weight: .light), trigger: model.lockTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: model.clearTick) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: model.overTick) { _, _ in app.haptics }
    }

    // MARK: settle / clear chain — mirrors the stepped, animated cadence used
    // by the other "gravity settles" games in this app (Merge, Color Blocks).

    private func settleLoop() {
        let moved = withAnimation(.easeInOut(duration: 0.09)) { model.settleStep() }
        if moved {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { settleLoop() }
        } else {
            checkClears()
        }
    }

    private func checkClears() {
        let cells = model.spanningClearCells()
        guard !cells.isEmpty else {
            model.afterLockShouldSpawnNext()
            return
        }
        withAnimation(.easeOut(duration: 0.15)) { model.beginClearing(cells) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeInOut(duration: 0.12)) { model.finishClearing() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { settleLoop() }
        }
    }

    // MARK: board

    private func board(w: CGFloat, h: CGFloat) -> some View {
        let cell = min(w / CGFloat(model.cols), h / CGFloat(model.rows))
        let boardW = cell * CGFloat(model.cols)
        let boardH = cell * CGFloat(model.rows)
        let ox = (w - boardW) / 2
        let oy = (h - boardH) / 2

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "12141C"))
                .frame(width: boardW, height: boardH)
                .position(x: ox + boardW / 2, y: oy + boardH / 2)

            ForEach(model.grains) { g in
                grainView(g.color, cell: cell)
                    .overlay {
                        if model.clearingCells.contains(g.row * model.cols + g.col) {
                            RoundedRectangle(cornerRadius: max(2, cell * 0.18), style: .continuous)
                                .fill(.white.opacity(0.75))
                                .blendMode(.plusLighter)
                        }
                    }
                    .position(x: ox + CGFloat(g.col) * cell + cell / 2, y: oy + CGFloat(g.row) * cell + cell / 2)
            }

            ForEach(Array(model.activeCells.enumerated()), id: \.offset) { _, c in
                if c.row >= 0 {
                    grainView(model.activeColor, cell: cell)
                        .position(x: ox + CGFloat(c.col) * cell + cell / 2, y: oy + CGFloat(c.row) * cell + cell / 2)
                }
            }
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        // A plain tap (never exceeds the drag's minimum distance) falls
        // through to the tap gesture and drops instantly; anything that
        // moves far enough is treated as a slide, with a fast downward one
        // still working as a drop too.
        .gesture(dragGesture(cell: cell).exclusively(before: tapToDropGesture))
    }

    private var tapToDropGesture: some Gesture {
        TapGesture().onEnded { withAnimation(.easeIn(duration: 0.1)) { model.hardDrop() } }
    }

    /// Free 1:1 horizontal dragging (not step swipes) plus a downward swipe
    /// to hard-drop.
    private func dragGesture(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard cell > 0 else { return }
                let wanted = Int((v.translation.width / cell).rounded())
                if wanted != dragAppliedCols {
                    let step = wanted > dragAppliedCols ? 1 : -1
                    for _ in 0..<abs(wanted - dragAppliedCols) {
                        withAnimation(.easeOut(duration: 0.08)) { model.moveActive(dCol: step) }
                    }
                    dragAppliedCols = wanted
                }
            }
            .onEnded { v in
                let dx = v.translation.width, dy = v.translation.height
                if dy > 40, abs(dy) > abs(dx) * 1.2 {
                    withAnimation(.easeIn(duration: 0.1)) { model.hardDrop() }
                }
                dragAppliedCols = 0
            }
    }

    private func grainView(_ color: Color, cell: CGFloat) -> some View {
        let corner = max(2, cell * 0.18)
        return RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 0.75))
            .frame(width: max(1, cell - 1.5), height: max(1, cell - 1.5))
    }

    private func stat(_ label: String, _ v: Int) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
            Text("\(v)").font(.system(size: 18, weight: .black)).monospacedDigit()
        }
    }
}
