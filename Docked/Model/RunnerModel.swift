//
//  RunnerModel.swift
//  Docked
//
//  A minimalist endless runner (think the offline dinosaur game): a block
//  runs on the spot, obstacles scroll in from the right, tap to jump.
//
//  This type is pure simulation — no SwiftUI. `step(dt:arenaWidth:)` is
//  called from the view's 60 Hz ticker; all the tuning knobs live up top.
//

import SwiftUI

@Observable
final class RunnerModel {

    enum Phase: Equatable {
        case ready      // waiting for the first tap
        case running
        case paused     // left the tab / backgrounded mid-run
        case gameOver
    }

    // MARK: - Tuning (points & seconds)

    private let gravity: CGFloat = 3200
    private let jumpImpulse: CGFloat = 980
    private let baseSpeed: CGFloat = 340
    private let maxSpeed: CGFloat = 760

    let groundHeight: CGFloat = 26      // ground strip height, from the bottom
    let playerSize: CGFloat = 32
    let playerX: CGFloat = 54           // player is pinned at this x

    // MARK: - State (read-only to the outside)

    private(set) var phase: Phase = .ready
    private(set) var playerBottom: CGFloat = 0     // height of the player above the ground
    private(set) var velocityY: CGFloat = 0        // positive = moving up
    private(set) var obstacles: [Obstacle] = []
    private(set) var score: Double = 0
    private(set) var speed: CGFloat = 340
    private(set) var groundScroll: CGFloat = 0     // 0..<24, drives the moving ground ticks

    private var spawnCountdown: CGFloat = 1.2

    var scoreValue: Int { Int(score) }

    struct Obstacle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var width: CGFloat
        var height: CGFloat
    }

    // MARK: - Intent

    /// Single input for the whole game: start / jump / resume / retry.
    func tap() {
        switch phase {
        case .ready, .gameOver:
            resetWorld()
            phase = .running
        case .paused:
            phase = .running
        case .running:
            if playerBottom <= 0.5 {      // only jump when grounded
                velocityY = jumpImpulse
            }
        }
    }

    /// Called when the game scrolls out of view or the app backgrounds.
    func pauseIfRunning() {
        if phase == .running { phase = .paused }
    }

    private func resetWorld() {
        playerBottom = 0
        velocityY = 0
        obstacles.removeAll()
        score = 0
        speed = baseSpeed
        spawnCountdown = 1.2
        groundScroll = 0
    }

    // MARK: - Simulation

    /// Advance the world by `dt` seconds. `arenaWidth` is the current
    /// play-area width so obstacles enter just off the right edge regardless
    /// of the active layout.
    func step(dt: CGFloat, arenaWidth: CGFloat) {
        guard phase == .running else { return }
        let dt = min(dt, 1.0 / 30.0)   // clamp so a dropped frame can't teleport things

        // Difficulty ramps with distance.
        speed = min(maxSpeed, baseSpeed + CGFloat(score) * 1.6)

        // Player physics (semi-implicit Euler).
        velocityY -= gravity * dt
        playerBottom += velocityY * dt
        if playerBottom <= 0 {
            playerBottom = 0
            velocityY = 0
        }

        // Scrolling ground ticks.
        groundScroll = (groundScroll + speed * dt).truncatingRemainder(dividingBy: 24)

        // Move & cull obstacles.
        for i in obstacles.indices {
            obstacles[i].x -= speed * dt
        }
        obstacles.removeAll { $0.x + $0.width < -4 }

        // Spawn on a shrinking cadence.
        spawnCountdown -= dt
        if spawnCountdown <= 0 {
            let height = CGFloat.random(in: 24...50)
            let width = CGFloat.random(in: 14...24)
            let spawnX = max(arenaWidth, 260) + 24
            obstacles.append(Obstacle(x: spawnX, width: width, height: height))
            let gap = CGFloat.random(in: 0.95...1.7) * (baseSpeed / speed)
            spawnCountdown = max(0.7, gap)
        }

        // Score by distance.
        score += Double(dt) * 14

        // Collision: axis-aligned boxes, player fixed at playerX.
        let player = CGRect(x: playerX, y: playerBottom, width: playerSize, height: playerSize)
        for obstacle in obstacles {
            let box = CGRect(x: obstacle.x, y: 0, width: obstacle.width, height: obstacle.height)
            if player.intersects(box) {
                phase = .gameOver
                return
            }
        }
    }
}
