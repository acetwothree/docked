//
//  SandFallView.swift
//  Docked
//
//  "Sand Fall" — coloured tetromino pieces fall, then crumble into loose sand
//  that trickles into gaps. Fill a row edge-to-edge with one colour and it
//  clears. Piling up to the top ends the run.
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

    private let fallTimer = Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()

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

            Text(model.phase == .over ? "Sand piled up — resetting…" : "Drag to move · tap to rotate · swipe down to drop")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(model.phase == .over ? Color.orange : Color.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.12)) { model.rotateActive() } }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if dy > 50, abs(dy) > abs(dx) {
                        withAnimation(.easeIn(duration: 0.1)) { model.hardDrop() }
                    } else if abs(dx) > 22 {
                        let steps = max(1, min(3, Int(abs(dx) / 32)))
                        for _ in 0..<steps {
                            withAnimation(.easeOut(duration: 0.1)) { model.moveActive(dCol: dx > 0 ? 1 : -1) }
                        }
                    }
                }
        )
        .onReceive(fallTimer) { _ in
            guard model.phase == .play else { return }
            withAnimation(.linear(duration: 0.18)) { _ = model.stepDown() }
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
        let full = model.fullMonoRows()
        guard !full.isEmpty else {
            model.afterLockShouldSpawnNext()
            return
        }
        withAnimation(.easeOut(duration: 0.15)) { model.beginClearing(full) }
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
                    .opacity(model.clearingRows.contains(g.row) ? 0.3 : 1)
                    .position(x: ox + CGFloat(g.col) * cell + cell / 2, y: oy + CGFloat(g.row) * cell + cell / 2)
            }

            ForEach(Array(model.activeCells.enumerated()), id: \.offset) { _, c in
                if c.row >= 0 {
                    grainView(model.activeColor, cell: cell)
                        .position(x: ox + CGFloat(c.col) * cell + cell / 2, y: oy + CGFloat(c.row) * cell + cell / 2)
                }
            }

            if !model.clearingRows.isEmpty {
                ForEach(Array(model.clearingRows), id: \.self) { r in
                    Rectangle()
                        .fill(.white.opacity(0.65))
                        .blendMode(.plusLighter)
                        .frame(width: boardW, height: cell)
                        .position(x: ox + boardW / 2, y: oy + CGFloat(r) * cell + cell / 2)
                }
            }
        }
        .frame(width: w, height: h)
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
