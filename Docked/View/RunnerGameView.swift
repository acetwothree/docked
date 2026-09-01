//
//  RunnerGameView.swift
//  Docked
//
//  Renders `RunnerModel`. A 60 Hz `Timer` publisher drives the simulation
//  from `onReceive` (outside `body`, so state mutation is safe); writing the
//  tick date into `@State lastTick` re-evaluates `body` every frame, which
//  rebuilds the `Canvas` and re-runs its renderer. Tap anywhere to start,
//  jump, resume or retry.
//

import SwiftUI
import Combine

struct RunnerGameView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    @State private var game = RunnerModel()
    @State private var lastTick = Date()

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.paper)

                // `tick` changes every frame, so this subview — and its
                // Canvas renderer — is rebuilt at ~60 fps.
                gameCanvas(size: geo.size, tick: lastTick)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))

                hud

                messageOverlay
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.08))
            }
            .contentShape(Rectangle())
            .onTapGesture { game.tap() }
            .onReceive(ticker) { _ in
                let now = Date()
                let dt = CGFloat(now.timeIntervalSince(lastTick))
                lastTick = now
                game.step(dt: dt, arenaWidth: geo.size.width)
            }
        }
        .onChange(of: game.phase) { _, phase in
            if phase == .gameOver, game.scoreValue > app.runnerHighScore {
                app.runnerHighScore = game.scoreValue
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.pauseIfRunning() }
        }
        .onDisappear { game.pauseIfRunning() }
    }

    // MARK: World

    private func gameCanvas(size: CGSize, tick: Date) -> some View {
        _ = tick   // frame pulse; see call site
        return Canvas { context, canvasSize in
            let groundY = canvasSize.height - game.groundHeight

            // Ground line.
            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: groundY))
            ground.addLine(to: CGPoint(x: canvasSize.width, y: groundY))
            context.stroke(ground, with: .color(Theme.ink.opacity(0.55)), lineWidth: 2)

            // Scrolling ground ticks.
            var ticks = Path()
            var x = -game.groundScroll
            while x < canvasSize.width {
                ticks.move(to: CGPoint(x: x, y: groundY + 7))
                ticks.addLine(to: CGPoint(x: x + 10, y: groundY + 7))
                x += 24
            }
            context.stroke(ticks, with: .color(Theme.ink.opacity(0.22)), lineWidth: 2)

            // Player.
            let playerY = groundY - game.playerSize - game.playerBottom
            let playerRect = CGRect(x: game.playerX, y: playerY,
                                    width: game.playerSize, height: game.playerSize)
            context.fill(
                Path(roundedRect: playerRect, cornerRadius: 7, style: .continuous),
                with: .color(Theme.accent)
            )

            // Obstacles.
            for obstacle in game.obstacles {
                let rect = CGRect(x: obstacle.x, y: groundY - obstacle.height,
                                  width: obstacle.width, height: obstacle.height)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 4, style: .continuous),
                    with: .color(Theme.ink.opacity(0.8))
                )
            }
        }
    }

    // MARK: HUD

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

    @ViewBuilder
    private var messageOverlay: some View {
        switch game.phase {
        case .ready:
            prompt("Tap to run", "Tap anywhere to hop the cactus")
        case .paused:
            prompt("Paused", "Tap to resume")
        case .gameOver:
            prompt("Game Over", "Score \(game.scoreValue) · tap to retry")
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
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(Theme.ink)
    }
}
