//
//  BeadsView.swift
//  Docked
//
//  "Beads" — a row of beads on a wire. Drag one and let go; it slides, shunts
//  its neighbours, and they clack off each other and the ends. Pure fidget.
//

import SwiftUI
import Combine

struct BeadsView: View {
    @Environment(AppModel.self) private var app

    private let count = 7
    private let br: CGFloat = 22

    @State private var pos: [CGFloat] = []     // 0…1 along the wire
    @State private var vel: [CGFloat] = []
    @State private var dragging: Int? = nil
    @State private var lastTick = Date()
    @State private var clickTick = 0

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let x0 = br + 6
            let x1 = max(x0 + 1, W - br - 6)
            let span = x1 - x0
            let minGap = (br * 2 + 2) / span

            ZStack {
                Capsule().fill(Theme.ink.opacity(0.18))
                    .frame(width: max(0, W - 12), height: 4)
                    .position(x: W / 2, y: H / 2)
                Capsule().fill(Theme.ink.opacity(0.4)).frame(width: 6, height: 34).position(x: x0, y: H / 2)
                Capsule().fill(Theme.ink.opacity(0.4)).frame(width: 6, height: 34).position(x: x1, y: H / 2)

                ForEach(Array(pos.enumerated()), id: \.offset) { pair in
                    Circle()
                        .fill(beadColor(pair.offset))
                        .frame(width: br * 2, height: br * 2)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                        .position(x: x0 + pair.element * span, y: H / 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let p = (v.location.x - x0) / span
                        if dragging == nil { dragging = nearestBead(to: p) }
                        if let d = dragging, pos.indices.contains(d) {
                            pos[d] = min(1, max(0, p))
                            vel[d] = 0
                            shove(from: d, minGap: minGap)
                        }
                    }
                    .onEnded { v in
                        if let d = dragging, vel.indices.contains(d) {
                            vel[d] = (v.velocity.width / span) * 0.5
                        }
                        dragging = nil
                    }
            )
            .onReceive(ticker) { _ in
                let now = Date()
                let dt = CGFloat(min(now.timeIntervalSince(lastTick), 1.0 / 30.0))
                lastTick = now
                stepPhysics(dt: dt, minGap: minGap)
            }
            .onAppear {
                if pos.count != count {
                    pos = (0..<count).map { CGFloat($0) / CGFloat(count - 1) * 0.5 }
                    vel = Array(repeating: 0, count: count)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: clickTick) { _, _ in app.haptics }
    }

    private func beadColor(_ i: Int) -> Color {
        let hues = ["4A9CFF", "3ECF7A", "F2B90C", "F25CA2", "8B5CF6", "FF8A3D", "37D6D6"]
        return Color(hex: hues[i % hues.count])
    }

    private func nearestBead(to p: CGFloat) -> Int {
        var bi = 0
        var bd = CGFloat.infinity
        for i in pos.indices {
            let d = abs(pos[i] - p)
            if d < bd { bd = d; bi = i }
        }
        return bi
    }

    private func stepPhysics(dt: CGFloat, minGap: CGFloat) {
        guard pos.count == count, vel.count == count else { return }
        for i in 0..<count where i != dragging {
            pos[i] += vel[i] * dt
            vel[i] *= 0.965
            if abs(vel[i]) < 0.002 { vel[i] = 0 }
            if pos[i] <= 0 {
                pos[i] = 0
                if vel[i] < 0 { if abs(vel[i]) > 0.05 { clickTick += 1 }; vel[i] = -vel[i] * 0.4 }
            }
            if pos[i] >= 1 {
                pos[i] = 1
                if vel[i] > 0 { if abs(vel[i]) > 0.05 { clickTick += 1 }; vel[i] = -vel[i] * 0.4 }
            }
        }
        for i in 0..<(count - 1) {
            let overlap = minGap - (pos[i + 1] - pos[i])
            if overlap > 0 {
                let hard = abs(vel[i] - vel[i + 1]) > 0.08
                pos[i] -= overlap / 2
                pos[i + 1] += overlap / 2
                let a = vel[i], b = vel[i + 1]
                vel[i] = b * 0.85
                vel[i + 1] = a * 0.85
                if hard { clickTick += 1 }
            }
        }
        for i in 0..<count { pos[i] = min(1, max(0, pos[i])) }
    }

    private func shove(from d: Int, minGap: CGFloat) {
        for i in stride(from: d - 1, through: 0, by: -1) {
            if pos[i] > pos[i + 1] - minGap { pos[i] = pos[i + 1] - minGap } else { break }
        }
        for i in (d + 1)..<count {
            if pos[i] < pos[i - 1] + minGap { pos[i] = pos[i - 1] + minGap } else { break }
        }
        for i in 0..<count { pos[i] = min(1, max(0, pos[i])) }
    }
}
