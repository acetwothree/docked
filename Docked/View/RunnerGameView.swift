//
//  RunnerGameView.swift
//  Docked
//
//  Renders `RunnerModel`. A 60 Hz `Timer` publisher drives the sim; writing
//  the tick date into `@State lastTick` re-evaluates `body` each frame so the
//  `Canvas` redraws. Swipe left/right = change lane, swipe up = jump the
//  ground blocks, swipe down = slide under the overhead bars, tap = jump.
//

import SwiftUI
import Combine

struct RunnerGameView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    @State private var game = RunnerModel()
    @State private var lastTick = Date()
    @State private var jumpTick = 0
    @State private var slideTick = 0
    @State private var deathTick = 0

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                canvas(size: geo.size, tick: lastTick)
                hud
                messageOverlay
            }
            .contentShape(Rectangle())
            .onTapGesture { game.jump(); jumpTick += 1 }
            .gesture(
                DragGesture(minimumDistance: 16)
                    .onEnded { v in
                        let dx = v.translation.width, dy = v.translation.height
                        if abs(dx) > abs(dy) {
                            if dx > 0 { game.moveRight() } else { game.moveLeft() }
                        } else if dy < 0 {
                            game.jump(); jumpTick += 1
                        } else {
                            game.slideDown(); slideTick += 1
                        }
                    }
            )
            .onReceive(ticker) { _ in
                let now = Date()
                let dt = CGFloat(now.timeIntervalSince(lastTick))
                lastTick = now
                game.step(dt: dt, arenaHeight: geo.size.height)
            }
        }
        .onChange(of: game.phase) { _, phase in
            if phase == .gameOver {
                deathTick += 1
                if game.scoreValue > app.runnerHighScore { app.runnerHighScore = game.scoreValue }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.pauseIfRunning() }
        }
        .onDisappear { game.pauseIfRunning() }
        .sensoryFeedback(.impact(weight: .light), trigger: jumpTick) { _, _ in app.haptics && game.phase == .running }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: slideTick) { _, _ in app.haptics && game.phase == .running }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: game.dodgeTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: deathTick) { _, _ in app.haptics }
    }

    // MARK: world

    private func canvas(size: CGSize, tick: Date) -> some View {
        _ = tick
        return Canvas { ctx, cs in
            let laneW = cs.width / CGFloat(game.lanes)
            func laneX(_ l: Int) -> CGFloat { laneW * (CGFloat(l) + 0.5) }

            for l in 1..<game.lanes {
                var p = Path()
                p.move(to: CGPoint(x: laneW * CGFloat(l), y: 0))
                p.addLine(to: CGPoint(x: laneW * CGFloat(l), y: cs.height))
                ctx.stroke(p, with: .color(Theme.ink.opacity(0.10)),
                           style: StrokeStyle(lineWidth: 2, dash: [8, 10]))
            }

            for o in game.obstacles {
                let x = laneX(o.lane)
                let w = laneW * 0.6
                switch o.kind {
                case .ground:
                    // block on the floor — JUMP (accent, glyph ↑)
                    let h: CGFloat = 40
                    let rect = CGRect(x: x - w / 2, y: o.y - h / 2, width: w, height: h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 7, style: .continuous),
                             with: .color(Theme.accent))
                    ctx.draw(Text("↑").font(.system(size: 15, weight: .black))
                                .foregroundColor(Color(red: 0.11, green: 0.08, blue: 0.02)),
                             at: CGPoint(x: x, y: o.y))
                case .overhead:
                    // bar hanging from the top of the lane — SLIDE (ink, glyph ↓)
                    let h: CGFloat = 42
                    let rect = CGRect(x: x - w / 2, y: o.y - h, width: w, height: h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 7, style: .continuous),
                             with: .color(Theme.ink.opacity(0.82)))
                    ctx.draw(Text("↓").font(.system(size: 15, weight: .black))
                                .foregroundColor(.white),
                             at: CGPoint(x: x, y: o.y - h / 2))
                }
            }

            // player
            let base = cs.height - 90
            let px = laneX(game.lane)
            let sliding = game.slide > 0.4
            let pw: CGFloat = sliding ? laneW * 0.62 : laneW * 0.46
            let phh: CGFloat = sliding ? 22 : 50
            let py = base - game.hop * 52
            let pr = CGRect(x: px - pw / 2, y: py - phh + (sliding ? phh * 0.5 : 0),
                            width: pw, height: phh)
            ctx.fill(Path(roundedRect: pr, cornerRadius: 8, style: .continuous),
                     with: .color(Theme.accent))
            let sh = pw * (0.95 - game.hop * 0.4)
            ctx.fill(Path(ellipseIn: CGRect(x: px - sh / 2, y: cs.height - 70,
                                            width: sh, height: sh * 0.26)),
                     with: .color(.black.opacity(0.16 - game.hop * 0.09)))
        }
    }

    private var hud: some View {
        VStack {
            HStack {
                Label("\(game.scoreValue)", systemImage: "figure.run")
                    .font(.headline.monospacedDigit())
                Spacer()
                Text("Best \(max(app.runnerHighScore, game.scoreValue))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            Spacer()
        }
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder private var messageOverlay: some View {
        switch game.phase {
        case .ready:
            prompt("Tap to run", "⬆︎ jump the blocks · ⬇︎ slide under the bars · ⬅︎➡︎ switch lane")
        case .paused:
            prompt("Paused", "Tap to resume")
        case .gameOver:
            prompt("Crash!", "Score \(game.scoreValue) · tap to retry")
        case .running:
            EmptyView()
        }
    }

    private func prompt(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.title3.bold())
            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(Theme.ink)
    }
}
