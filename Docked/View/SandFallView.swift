//
//  SandFallView.swift
//  Docked
//
//  "Crumble Drop" — coloured tetromino pieces spawn just above a dashed
//  starting line and immediately begin a slow, steady, continuous descent —
//  no pauses between steps. Drag left/right to slide the falling piece over
//  (it follows your finger 1:1); tap to rotate it a quarter-turn; swipe
//  down to speed it up into an instant hard drop. A preview square above
//  the line always shows the next piece. On landing it crumbles into loose
//  sand that trickles into gaps. A colour clears once a connected patch of
//  it spans every column from the left wall to the right wall.
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
    /// The column span of a just-triggered hard drop, for the motion streak.
    private struct DropStreak: Equatable { var lo: Int; var hi: Int; var gen: Int }
    @State private var dropStreak: DropStreak? = nil
    @State private var dropStreakGen = 0

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

            Text(model.phase == .over ? "Sand piled up — resetting…" : "Drag to slide · tap to rotate · swipe down to drop")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(model.phase == .over ? Color.orange : Color.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startSlowFall() }
        .onChange(of: model.spawnTick) { _, _ in startSlowFall() }
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

    // MARK: continuous slow fall

    /// Kicked off the moment a piece spawns (and restarted after a hard drop
    /// locks in, when the next piece's `spawnTick` fires) — steps continue
    /// back-to-back with NO gap between them (each one is scheduled to fire
    /// exactly when the previous step's animation finishes), which is what
    /// reads as one smooth continuous descent instead of a jump-pause-jump.
    private func startSlowFall() {
        fallGen += 1
        scheduleSlowFallStep(gen: fallGen, delay: 0.32)
    }

    private func scheduleSlowFallStep(gen: Int, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard gen == fallGen, model.phase == .play, !model.activeCells.isEmpty else { return }
            let stepDuration = 0.26
            withAnimation(.linear(duration: stepDuration)) { _ = model.stepDown() }
            scheduleSlowFallStep(gen: gen, delay: stepDuration)
        }
    }

    // MARK: board

    private func board(w: CGFloat, h: CGFloat) -> some View {
        // Separate width/height per cell — fills the space exactly (no dead
        // margin on the shorter axis the way a single square cell size would).
        // An extra reserved row's worth of height at the top is the "spawn
        // band" — a dashed starting line, with new pieces entering from
        // above it and a tiny preview of the next one parked in the corner.
        let cellW = w / CGFloat(model.cols)
        // ~3 rows' worth of height reserved at the top for the spawn band, so
        // the dashed line sits lower and a full piece fits above it.
        let cellH = h / (CGFloat(model.rows) + 3)
        let bandH = h - CGFloat(model.rows) * cellH
        func y(_ row: Int) -> CGFloat { bandH + CGFloat(row) * cellH + cellH / 2 }

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "12141C"))
                .frame(width: w, height: h)

            Path { p in
                p.move(to: CGPoint(x: 6, y: bandH))
                p.addLine(to: CGPoint(x: w - 6, y: bandH))
            }
            .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

            ForEach(model.grains) { g in
                grainView(g.color, w: cellW, h: cellH)
                    .overlay {
                        if model.clearingCells.contains(g.row * model.cols + g.col) {
                            RoundedRectangle(cornerRadius: max(2, min(cellW, cellH) * 0.18), style: .continuous)
                                .fill(.white.opacity(0.75))
                                .blendMode(.plusLighter)
                        }
                    }
                    .position(x: CGFloat(g.col) * cellW + cellW / 2, y: y(g.row))
            }

            ForEach(Array(model.activeCells.enumerated()), id: \.offset) { _, c in
                grainView(model.activeColor, w: cellW, h: cellH)
                    .position(x: CGFloat(c.col) * cellW + cellW / 2, y: y(c.row))
            }

            if let streak = dropStreak {
                let x0 = CGFloat(streak.lo) * cellW
                let x1 = CGFloat(streak.hi + 1) * cellW
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: max(2, x1 - x0), height: h)
                    .position(x: (x0 + x1) / 2, y: h / 2)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .id(streak.gen)
            }

            let previewBox = min(bandH * 0.8, cellW * 2.6)
            nextPreview(box: previewBox)
                .position(x: w - previewBox / 2 - 8, y: bandH * 0.5)
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        // A drag (>=8pt) slides / swipe-drops; a plain tap that never becomes
        // a drag falls through to rotate.
        .gesture(dragGesture(cellW: cellW).exclusively(before: tapToRotateGesture))
    }

    private var tapToRotateGesture: some Gesture {
        TapGesture().onEnded {
            // Quick snap — a slower tween makes the four cells look like
            // they're scattering to new spots rather than turning as one.
            withAnimation(.easeOut(duration: 0.06)) { model.rotateActive() }
        }
    }

    /// A tiny scaled-down rendering of `model.nextShape`, in its own colour —
    /// the "what's coming" square, parked above the dashed line.
    private func nextPreview(box: CGFloat) -> some View {
        let cells = model.nextShape
        let maxRow = max(1, cells.map(\.row).max() ?? 1)
        let maxCol = max(1, cells.map(\.col).max() ?? 1)
        let unit = box / CGFloat(max(maxRow, maxCol) + 1)
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: box, height: box)
            ForEach(Array(cells.enumerated()), id: \.offset) { _, c in
                RoundedRectangle(cornerRadius: max(1, unit * 0.18), style: .continuous)
                    .fill(model.nextColor)
                    .frame(width: max(1, unit - 1.5), height: max(1, unit - 1.5))
                    .position(x: CGFloat(c.col) * unit + unit / 2, y: CGFloat(c.row) * unit + unit / 2)
            }
        }
        .frame(width: box, height: box)
    }

    /// Column-step dragging with a short glide per step (a hair of easing, so
    /// it doesn't feel like the piece is teleporting) while it falls on its
    /// own; a downward swipe speeds it into an instant hard drop with a quick
    /// motion streak down the column.
    private func dragGesture(cellW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard cellW > 0 else { return }
                let wanted = Int((v.translation.width / cellW).rounded())
                if wanted != dragAppliedCols {
                    let step = wanted > dragAppliedCols ? 1 : -1
                    withAnimation(.easeOut(duration: 0.09)) {
                        for _ in 0..<abs(wanted - dragAppliedCols) { model.moveActive(dCol: step) }
                    }
                    dragAppliedCols = wanted
                }
            }
            .onEnded { v in
                let dx = v.translation.width, dy = v.translation.height
                dragAppliedCols = 0
                if dy > 40, abs(dy) > abs(dx) * 1.2 {
                    fallGen += 1
                    let cols = model.activeCells.map(\.col)
                    if let lo = cols.min(), let hi = cols.max() {
                        dropStreakGen += 1
                        dropStreak = DropStreak(lo: lo, hi: hi, gen: dropStreakGen)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            withAnimation(.easeOut(duration: 0.3)) { dropStreak = nil }
                        }
                    }
                    withAnimation(.easeIn(duration: 0.07)) { model.hardDrop() }
                }
                // Otherwise: nothing to do — the continuous slow fall is
                // already running independently of this gesture.
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
