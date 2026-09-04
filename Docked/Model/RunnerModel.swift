//
//  RunnerModel.swift
//  Docked
//
//  "Fit" — a wall with a hole in it slides down at you. Get into the hole's
//  lane and strike its pose (stand / jump / duck) to pass. Occasional solid
//  blocks just need a lane change — never a jump or duck.
//
//  Pure simulation — no SwiftUI. `step(dt:arenaHeight:)` runs from the view's
//  60 Hz ticker.
//

import SwiftUI

@Observable
final class RunnerModel {

    enum Phase: Equatable { case ready, running, paused, gameOver }
    enum Pose: Equatable { case stand, jump, duck }
    enum Kind: Equatable { case wall, block }

    struct Hazard: Identifiable {
        let id = UUID()
        var kind: Kind
        var y: CGFloat
        var lane: Int      // wall: the hole's lane · block: the blocked lane
        var pose: Pose     // wall: the hole's pose · block: unused
        var scored = false
    }

    let lanes = 3

    private(set) var phase: Phase = .ready
    private(set) var lane = 1
    private(set) var hop: CGFloat = 0     // 0…1 through a jump
    private(set) var slide: CGFloat = 0   // 0…1 through a duck
    private(set) var hazards: [Hazard] = []
    private(set) var score: Double = 0
    private(set) var speed: CGFloat = 190
    private(set) var dodgeTick = 0

    private var hopTime: CGFloat = 0
    private var slideTime: CGFloat = 0
    private var spawnCountdown: CGFloat = 1.4

    private let hopDuration: CGFloat = 0.64
    private let slideDuration: CGFloat = 0.64
    private let baseSpeed: CGFloat = 190
    private let maxSpeed: CGFloat = 430

    var scoreValue: Int { Int(score) }

    var pose: Pose {
        if hop > 0.32 { return .jump }
        if slide > 0.35 { return .duck }
        return .stand
    }

    // MARK: intent

    func moveLeft() {
        if phase == .running { lane = max(0, lane - 1) } else { tap() }
    }
    func moveRight() {
        if phase == .running { lane = min(lanes - 1, lane + 1) } else { tap() }
    }
    func jump() {
        guard phase == .running else { tap(); return }
        if hopTime <= 0 && slideTime <= 0 { hopTime = hopDuration }
    }
    func duck() {
        guard phase == .running else { tap(); return }
        if slideTime <= 0 && hopTime <= 0 { slideTime = slideDuration }
    }
    func tap() {
        switch phase {
        case .ready, .gameOver: reset(); phase = .running
        case .paused: phase = .running
        case .running: if hopTime <= 0 && slideTime <= 0 { hopTime = hopDuration }
        }
    }
    func pauseIfRunning() { if phase == .running { phase = .paused } }

    private func reset() {
        lane = 1
        hop = 0; slide = 0
        hopTime = 0; slideTime = 0
        hazards.removeAll()
        score = 0
        speed = baseSpeed
        spawnCountdown = 1.4
    }

    // MARK: simulation

    func step(dt rawDt: CGFloat, arenaHeight: CGFloat) {
        guard phase == .running else { return }
        let dt = min(rawDt, 1.0 / 30.0)

        speed = min(maxSpeed, baseSpeed + CGFloat(score) * 0.85)
        score += Double(dt) * 9

        if hopTime > 0 {
            hopTime -= dt
            hop = CGFloat(sin(Double(max(0, 1 - hopTime / hopDuration)) * Double.pi))
            if hopTime <= 0 { hop = 0; hopTime = 0 }
        }
        if slideTime > 0 {
            slideTime -= dt
            slide = min(1, slideTime * 6)
            if slideTime <= 0 { slide = 0; slideTime = 0 }
        }

        for i in hazards.indices { hazards[i].y += speed * dt }
        hazards.removeAll { $0.y > arenaHeight + 110 }

        spawnCountdown -= dt
        if spawnCountdown <= 0 {
            if Int.random(in: 0..<4) == 0 {
                hazards.append(Hazard(kind: .block, y: -90,
                                      lane: Int.random(in: 0..<lanes), pose: .stand))
            } else {
                let poses: [Pose] = [.stand, .stand, .jump, .duck]
                hazards.append(Hazard(kind: .wall, y: -90,
                                      lane: Int.random(in: 0..<lanes),
                                      pose: poses.randomElement()!))
            }
            let base = max(1.0, 2.0 - CGFloat(score) * 0.0016)
            spawnCountdown = base * CGFloat.random(in: 0.85...1.2)
        }

        let playerY = arenaHeight - 92
        for i in hazards.indices {
            let hz = hazards[i]
            if !hz.scored && hz.y > playerY + 26 {
                hazards[i].scored = true
                dodgeTick += 1
                score += 3
            }
            guard abs(hz.y - playerY) < 24 else { continue }
            let safe: Bool
            switch hz.kind {
            case .wall:  safe = (lane == hz.lane && pose == hz.pose)
            case .block: safe = (lane != hz.lane)
            }
            if !safe { phase = .gameOver; return }
        }
    }
}
