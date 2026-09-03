//
//  SpinnerView.swift
//  Docked
//
//  A fidget spinner. Flick it (or tap for a push) and it winds down with
//  friction. Lifetime spins persist.
//

import SwiftUI
import Combine
import Foundation

struct SpinnerView: View {
    @AppStorage("docked.spinner.spins") private var spins: Double = 0

    @State private var angle: Double = 0
    @State private var vel: Double = 0          // degrees / second
    @State private var pending: Double = 0      // spins not yet flushed to storage
    @State private var lastTick: Date = .now

    private let clock = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            Text("\(Int(spins + pending)) spins")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height) * 0.86
                spinner(size: s)
                    .frame(width: s, height: s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer(minLength: 0)

            Text("Flick to spin · tap for a push")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { vel += 700 }
        .gesture(
            DragGesture(minimumDistance: 8)
                .onEnded { v in
                    let vx = Double(v.velocity.width)
                    let vy = Double(v.velocity.height)
                    let speed = (vx * vx + vy * vy).squareRoot()
                    let sign: Double = vx >= 0 ? 1 : -1
                    vel += min(speed, 6000) * 0.28 * sign
                }
        )
        .onReceive(clock) { now in
            let dt = min(now.timeIntervalSince(lastTick), 0.05)
            lastTick = now
            guard vel != 0 else { return }
            angle += vel * dt
            pending += abs(vel * dt) / 360.0
            vel *= (1 - 0.9 * dt)          // friction
            if abs(vel) < 4 {
                vel = 0
                spins += pending
                pending = 0
            }
        }
        .onDisappear { spins += pending; pending = 0 }
    }

    private func spinner(size: CGFloat) -> some View {
        let arm = size * 0.34
        return ZStack {
            ForEach(Array(0..<3), id: \.self) { k in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .offset(y: -arm)
                    .rotationEffect(.degrees(Double(k) * 120))
            }
            Capsule()
                .fill(Theme.accent.opacity(0.55))
                .frame(width: size * 0.9, height: size * 0.24)
            Capsule()
                .fill(Theme.accent.opacity(0.55))
                .frame(width: size * 0.9, height: size * 0.24)
                .rotationEffect(.degrees(120))
            Capsule()
                .fill(Theme.accent.opacity(0.55))
                .frame(width: size * 0.9, height: size * 0.24)
                .rotationEffect(.degrees(240))
            Circle()
                .fill(Color(red: 0.12, green: 0.09, blue: 0.03))
                .frame(width: size * 0.22, height: size * 0.22)
        }
        .rotationEffect(.degrees(angle))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}
