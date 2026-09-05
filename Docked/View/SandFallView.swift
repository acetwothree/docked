//
//  SandFallView.swift
//  Docked
//
//  "Crumble Drop" — coloured tetromino pieces hover in place until you act.
//  Drag left/right to slide one over (it follows your finger 1:1); releasing
//  the drag lets it start settling downward on its own, slowly — tap the
//  board at any point and it speeds up and locks in immediately. A plain tap
//  with no drag first also drops it straight away. On landing it crumbles
//  into loose sand that trickles into gaps. A colour clears once a connected
//  patch of it spans every column from the left wall to the right wall.
//  Pieces don't rotate.
//
//  Settled grains keep a stable identity (`Grain.id`) across the model's
//  settle passes, so `ForEach(model.grains)` animates each one sliding to its
//  new cell — that's what gives the "sand flowing" look — rather than cells
//  just changing colour in place.
//

import SwiftUI

struct SandFallView: View {
    @Environment(AppModel.self) private var app
    @State private var model: SandFallModel

    /// Net columns already applied for the drag in progress, so continued
    /// finger movement only applies the DELTA each time (free 1:1 tracking).
    @State private var dragAppliedCols = 0
    /// Bumped on every hard-drop/lock so a stale slow-fall loop from an
    /// earlier piece can recognise it's obsolete and stop.
    @State private var fallGen = 0

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

            Text(model.phase == .over ? "Sand piled up — resetting…" : "Drag to slide, then tap to drop fast")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(model.phase == .over ? Color.orange : Color.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: settle-then-tap-to-speed-up

    /// Started when a drag ends without triggering a hard drop — the piece
    /// begins a slow, steady descent on its own. A tap at any point jumps
    /// straight to `hardDrop`, which naturally makes this loop a no-op on its
    /// next scheduled step (`activeCells` is empty by then).
    private func startSlowFall() {
        fallGen += 1
        slowFallStep(gen: fallGen)
    }

    private func slowFallStep(gen: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard gen == fallGen, model.phase == .play, !model.activeCells.isEmpty else { return }
            withAnimation(.linear(duration: 0.3)) { _ = model.stepDown() }
            slowFallStep(gen: gen)
        }
    }

    // MARK: board

    private func board(w: CGFloat, h: CGFloat) -> some View {
        // Separate width/height per cell — fills the space exactly (no dead
        // margin on the shorter axis the way a single square cell size would).
        let cellW = w / CGFloat(model.cols)
        let cellH = h / CGFloat(model.rows)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "12141C"))
                .frame(width: w, height: h)

            ForEach(model.grains) { g in
                grainView(g.color, w: cellW, h: cellH)
                    .overlay {
                        if model.clearingCells.contains(g.row * model.cols + g.col) {
                            RoundedRectangle(cornerRadius: max(2, min(cellW, cellH) * 0.18), style: .continuous)
                                .fill(.white.opacity(0.75))
                                .blendMode(.plusLighter)
                        }
                    }
                    .position(x: CGFloat(g.col) * cellW + cellW / 2, y: CGFloat(g.row) * cellH + cellH / 2)
            }

            ForEach(Array(model.activeCells.enumerated()), id: \.offset) { _, c in
                if c.row >= 0 {
                    grainView(model.activeColor, w: cellW, h: cellH)
                        .position(x: CGFloat(c.col) * cellW + cellW / 2, y: CGFloat(c.row) * cellH + cellH / 2)
                }
            }
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        // A plain tap (never exceeds the drag's minimum distance) falls
        // through to the tap gesture and drops instantly; a drag that ends
        // without that downward flick instead starts the slow auto-fall.
        .gesture(dragGesture(cellW: cellW).exclusively(before: tapToDropGesture))
    }

    private var tapToDropGesture: some Gesture {
        TapGesture().onEnded {
            fallGen += 1
            withAnimation(.easeIn(duration: 0.08)) { model.hardDrop() }
        }
    }

    /// Free 1:1 horizontal dragging (not step swipes, and not animated —
    /// animating every tiny step is what made dragging feel laggy) plus a
    /// downward swipe as an alternate hard-drop.
    private func dragGesture(cellW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard cellW > 0 else { return }
                let wanted = Int((v.translation.width / cellW).rounded())
                if wanted != dragAppliedCols {
                    let step = wanted > dragAppliedCols ? 1 : -1
                    for _ in 0..<abs(wanted - dragAppliedCols) { model.moveActive(dCol: step) }
                    dragAppliedCols = wanted
                }
            }
            .onEnded { v in
                let dx = v.translation.width, dy = v.translation.height
                dragAppliedCols = 0
                if dy > 40, abs(dy) > abs(dx) * 1.2 {
                    fallGen += 1
                    withAnimation(.easeIn(duration: 0.08)) { model.hardDrop() }
                } else {
                    startSlowFall()
                }
            }
    }

    // A flat fill instead of a gradient+stroke — with up to ~120 of these
    // redrawing on every settle step, cutting each one down to a single
    // layer is what actually moves the needle on lag.
    private func grainView(_ color: Color, w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(2, min(w, h) * 0.18), style: .continuous)
            .fill(color)
            .frame(width: max(1, w - 1.5), height: max(1, h - 1.5))
    }

    private func stat(_ label: String, _ v: Int) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
            Text("\(v)").font(.system(size: 18, weight: .black)).monospacedDigit()
        }
    }
}
