//
//  RunnerGameView.swift
//  Docked
//
//  Renders `RunnerModel` ("Fit"). A 60 Hz `Timer` publisher drives the sim;
//  writing the tick date into `@State lastTick` re-evaluates `body` each frame
//  so the `Canvas` redraws. Swipe ⬅︎➡︎ to change lane, ⬆︎ to jump, ⬇︎ to duck.
//

import SwiftUI
import Combine

struct RunnerGameView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("docked.runner.highScore") private var best = 0

    @State private var game = RunnerModel()
    @State private var lastTick = Date()
    @State private var jumpTick = 0
    @State private var duckTick = 0
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
                            game.duck(); duckTick += 1
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
                if game.scoreValue > best { best = game.scoreValue }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.pauseIfRunning() }
        }
        .onDisappear { game.pauseIfRunning() }
        .sensoryFeedback(.impact(weight: .light), trigger: jumpTick) { _, _ in app.haptics && game.phase == .running }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: duckTick) { _, _ in app.haptics && game.phase == .running }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: game.dodgeTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: deathTick) { _, _ in app.haptics }
    }

    // MARK: world

    private func canvas(size: CGSize, tick: Date) -> some View {
        _ = tick
        return Canvas { ctx, cs in
            let laneW = cs.width / CGFloat(game.lanes)
            func laneX(_ l: Int) -> CGFloat { laneW * (CGFloat(l) + 0.5) }

            // lane bands
            for l in 0..<game.lanes where l % 2 == 1 {
                ctx.fill(Path(CGRect(x: CGFloat(l) * laneW, y: 0, width: laneW, height: cs.height)),
                         with: .color(Theme.ink.opacity(0.04)))
            }
            for l in 1..<game.lanes {
                var p = Path()
                p.move(to: CGPoint(x: laneW * CGFloat(l), y: 0))
                p.addLine(to: CGPoint(x: laneW * CGFloat(l), y: cs.height))
                ctx.stroke(p, with: .color(Theme.ink.opacity(0.08)), lineWidth: 1)
            }

            // hazards
            for hz in game.hazards {
                switch hz.kind {
                case .wall:
                    let barH: CGFloat = 30
                    // solid wall across the whole width…
                    ctx.fill(Path(roundedRect: CGRect(x: 2, y: hz.y - barH / 2, width: cs.width - 4, height: barH),
                                  cornerRadius: 5), with: .color(Theme.ink.opacity(0.82)))
                    // …with a bright hole punched out at (lane, pose)
                    let hx: CGFloat = laneX(hz.lane)
                    let holeW: CGFloat = laneW * 0.7
                    var holeH: CGFloat = barH + 6
                    var dy: CGFloat = 0
                    var glyph = "●"
                    if hz.pose == .jump { holeH = barH * 0.6; dy = -barH * 0.5; glyph = "▲" }
                    if hz.pose == .duck { holeH = barH * 0.6; dy = barH * 0.5; glyph = "▼" }
                    let holeRect = CGRect(x: hx - holeW / 2, y: hz.y - holeH / 2 + dy, width: holeW, height: holeH)
                    ctx.fill(Path(roundedRect: holeRect, cornerRadius: 4), with: .color(Theme.backdrop))
                    ctx.stroke(Path(roundedRect: holeRect, cornerRadius: 4), with: .color(Theme.accent), lineWidth: 2)
                    ctx.draw(Text(glyph).font(.system(size: 13, weight: .black)).foregroundColor(Theme.accent),
                             at: CGPoint(x: hx, y: hz.y + dy))
                case .block:
                    let w = laneW * 0.66
                    let r = CGRect(x: laneX(hz.lane) - w / 2, y: hz.y - 22, width: w, height: 44)
                    ctx.fill(Path(roundedRect: r, cornerRadius: 8, style: .continuous),
                             with: .color(Color(hex: "FF8A3D")))
                    ctx.draw(Text("⇄").font(.system(size: 16, weight: .black))
                                .foregroundColor(Color(red: 0.11, green: 0.08, blue: 0.02)),
                             at: CGPoint(x: laneX(hz.lane), y: hz.y))
                }
            }

            // player
            let base = cs.height - 92
            let px = laneX(game.lane)
            let ducking = game.slide > 0.35
            let pw: CGFloat = laneW * (ducking ? 0.6 : 0.44)
            let ph: CGFloat = ducking ? 22 : 48
            let py = base - game.hop * 50
            let pr = CGRect(x: px - pw / 2, y: py - ph, width: pw, height: ph)
            ctx.fill(Path(roundedRect: pr, cornerRadius: 8, style: .continuous), with: .color(Theme.accent))
            let sh = pw * (0.95 - game.hop * 0.4)
            ctx.fill(Path(ellipseIn: CGRect(x: px - sh / 2, y: base - 4, width: sh, height: sh * 0.24)),
                     with: .color(.black.opacity(0.16 - game.hop * 0.09)))
        }
    }

    private var hud: some View {
        VStack {
            HStack {
                Text("\(game.scoreValue)").font(.headline.monospacedDigit())
                Spacer()
                Text("Best \(max(best, game.scoreValue))")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(14)
            Spacer()
        }
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder private var messageOverlay: some View {
        switch game.phase {
        case .ready:
            prompt("Tap to start", "▲ hole = jump · ▼ hole = duck · ● = just be in that lane · ⇄ block = swipe past")
        case .paused:
            prompt("Paused", "Tap to resume")
        case .gameOver:
            prompt("Missed it", "Score \(game.scoreValue) · tap to retry")
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
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(Theme.ink)
    }
}
