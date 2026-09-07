//
//  SandFallView.swift
//  Docked
//
//  "Cascade" — coloured tetromino pieces spawn just above a dashed
//  starting line and immediately begin a slow, steady, continuous descent —
//  no pauses between steps. The piece always starts centred where the
//  preview shows it; drag and it slides left/right by however far your
//  finger has moved (relative, never a jump to the finger). Tap to rotate a
//  quarter-turn; swipe down for an instant hard drop. On landing it
//  scatters into loose grains that trickle into gaps. A colour clears once a
//  connected patch of it spans every column from the left wall to the right.
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
    /// finger movement only applies the DELTA each frame — the piece tracks
    /// relative to where it started (centred), never jumping to the finger.
    @State private var dragAppliedCols = 0
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
                nextChip()
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

            VStack(spacing: 3) {
                Text(model.phase == .over
                     ? "No room left — resetting…"
                     : "Connect one colour from the left wall to the right wall")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(model.phase == .over ? Color.orange : Color.primary)
                Text("Slide · tap to rotate · swipe down to drop")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1).minimumScaleFactor(0.65)
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

    // MARK: board

    private func board(w: CGFloat, h: CGFloat) -> some View {
        // Separate width/height per cell — fills the space exactly (no dead
        // margin on the shorter axis the way a single square cell size would).
        // A reserved band at the top holds the dashed "ceiling" line and a
        // small preview of the next piece, parked hard in the corner. The
        // active piece sits just BELOW the line, so the two never overlap.
        let cellW = w / CGFloat(model.cols)
        let cellH = h / (CGFloat(model.rows) + 2.5)
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

    /// The next piece, drawn small in the header (beside SCORE) so it's clearly
    /// a preview and never sits over the play area.
    private func nextChip() -> some View {
        let cells = model.nextShape
        let rs = cells.map(\.row), cs = cells.map(\.col)
        let minR = rs.min() ?? 0, maxR = rs.max() ?? 0
        let minC = cs.min() ?? 0, maxC = cs.max() ?? 0
        let u: CGFloat = 6, gap: CGFloat = 1
        return VStack(spacing: 2) {
            Text("NEXT").font(.system(size: 7, weight: .heavy)).tracking(1).foregroundStyle(.tertiary)
            ZStack(alignment: .topLeading) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, c in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(model.nextColor)
                        .frame(width: u, height: u)
                        .offset(x: CGFloat(c.col - minC) * (u + gap),
                                y: CGFloat(c.row - minR) * (u + gap))
                }
            }
            .frame(width: CGFloat(maxC - minC + 1) * (u + gap),
                   height: CGFloat(maxR - minR + 1) * (u + gap), alignment: .topLeading)
        }
        .frame(width: 46, height: 34)
    }

    /// Relative slide: the piece starts centred and moves by whatever whole
    /// number of columns your finger has travelled since the drag began —
    /// touching down off to one side never yanks it over there. A downward
    /// swipe speeds it into an instant hard drop with a quick motion streak.
    private func dragGesture(cellW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard cellW > 0, model.phase == .play else { return }
                let wanted = Int((v.translation.width / cellW).rounded())
                if wanted != dragAppliedCols {
                    model.nudgeActive(byCols: wanted - dragAppliedCols)
                    dragAppliedCols = wanted
                }
            }
            .onEnded { v in
                let dx = v.translation.width, dy = v.translation.height
                dragAppliedCols = 0
                // A downward swipe drops the piece; anything else just leaves
                // it parked where the slide left it.
                if dy > 40, abs(dy) > abs(dx) * 1.2 {
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
