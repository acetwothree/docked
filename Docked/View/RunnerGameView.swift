//
//  RunnerGameView.swift
//  Docked
//
//  Renders `RunnerModel`. A 60 Hz `Timer` publisher drives the simulation from
//  `onReceive`; writing the tick date into `@State lastTick` re-evaluates
//  `body` each frame so the `Canvas` redraws. Swipe left/right to switch lane,
//  swipe up or tap to hop.
//

import SwiftUI
import Combine

struct RunnerGameView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    @State private var game = RunnerModel()
    @State private var lastTick = Date()
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
            .onTapGesture { game.tap() }
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { v in
                        let dx = v.translation.width, dy = v.translation.height
                        if abs(dx) > abs(dy) {
                            if dx > 0 { game.moveRight() } else { game.moveLeft() }
                        } else if dy < 0 {
                            game.jump()
                        } else {
                            game.tap()
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
        .sensoryFeedback(.impact(weight: .rigid), trigger: deathTick) { _, _ in app.haptics }
    }

    // MARK: world

    private func canvas(size: CGSize, tick: Date) -> some View {
        _ = tick
        return Canvas { ctx, cs in
            let laneW = cs.width / CGFloat(game.lanes)
            func laneX(_ l: Int) -> CGFloat { laneW * (CGFloat(l) + 0.5) }

            // lane dividers
            for l in 1..<game.lanes {
                var p = Path()
                p.move(to: CGPoint(x: laneW * CGFloat(l), y: 0))
                p.addLine(to: CGPoint(x: laneW * CGFloat(l), y: cs.height))
                ctx.stroke(p, with: .color(Theme.ink.opacity(0.12)),
                           style: StrokeStyle(lineWidth: 2, dash: [8, 10]))
            }

            // obstacles
            for o in game.obstacles {
                let w = laneW * 0.62
                let h: CGFloat = o.kind == .low ? 26 : 46
                let rect = CGRect(x: laneX(o.lane) - w / 2, y: o.y - h / 2, width: w, height: h)
                let col = o.kind == .low ? Theme.ink.opacity(0.45) : Theme.ink.opacity(0.82)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 6, style: .continuous), with: .color(col))
            }

            // player
            let ps: CGFloat = laneW * 0.5
            let py = cs.height - 88 - game.hop * 46
            let pr = CGRect(x: laneX(game.lane) - ps / 2, y: py - ps / 2, width: ps, height: ps)
            ctx.fill(Path(roundedRect: pr, cornerRadius: 8, style: .continuous), with: .color(Theme.accent))
            // shadow under the player scales down while hopping
            let sh = ps * (0.9 - game.hop * 0.4)
            ctx.fill(Path(ellipseIn: CGRect(x: laneX(game.lane) - sh / 2, y: cs.height - 70, width: sh, height: sh * 0.28)),
                     with: .color(.black.opacity(0.18 - game.hop * 0.1)))
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
            prompt("Tap to run", "Swipe to switch lane · swipe up to hop")
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
