//
//  IdleGameView.swift
//  Docked
//
//  "Garden" — a cozy idle game. Tap the soil to harvest; crops also grow on
//  their own (and catch up a capped amount while you're away). Spend your
//  harvest on three plots that raise the passive rate. Everything persists.
//

import SwiftUI
import Combine
import Foundation

struct IdleGameView: View {
    @AppStorage("docked.idle.energy") private var crops: Double = 0
    @AppStorage("docked.idle.a") private var beds: Int = 0
    @AppStorage("docked.idle.b") private var greenhouses: Int = 0
    @AppStorage("docked.idle.c") private var orchards: Int = 0
    @AppStorage("docked.idle.seen") private var seen: Double = 0

    @State private var tap = 0

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var perSec: Double {
        Double(beds) * 0.2 + Double(greenhouses) * 1.5 + Double(orchards) * 9
    }
    private var costA: Double { 10 * pow(1.16, Double(beds)) }
    private var costB: Double { 130 * pow(1.16, Double(greenhouses)) }
    private var costC: Double { 1600 * pow(1.16, Double(orchards)) }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text("🌾").font(.system(size: 24))
                    Text(fmt(crops))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                Text("\(fmt(perSec)) / sec")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Button {
                crops += 1
                tap += 1
            } label: {
                ZStack {
                    Circle().fill(Color(red: 0.55, green: 0.40, blue: 0.26)).frame(width: 128, height: 128)
                    Circle().fill(Color(red: 0.40, green: 0.30, blue: 0.20)).frame(width: 108, height: 108)
                    Text("🌱").font(.system(size: 44))
                }
                .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                row("🌱 Seed Bed", "+0.2 / sec", count: beds, cost: costA, action: buyA)
                row("🪴 Greenhouse", "+1.5 / sec", count: greenhouses, cost: costB, action: buyB)
                row("🌳 Orchard", "+9 / sec", count: orchards, cost: costC, action: buyC)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: tap)
        .onReceive(clock) { _ in crops += perSec }
        .onAppear {
            let now = Date().timeIntervalSince1970
            if seen > 0 {
                let away = min(max(now - seen, 0), 8 * 3600)
                crops += away * perSec
            }
            seen = now
        }
        .onDisappear { seen = Date().timeIntervalSince1970 }
    }

    private func buyA() { if crops >= costA { crops -= costA; beds += 1; tap += 1 } }
    private func buyB() { if crops >= costB { crops -= costB; greenhouses += 1; tap += 1 } }
    private func buyC() { if crops >= costC { crops -= costC; orchards += 1; tap += 1 } }

    private func row(_ name: String, _ rate: String, count: Int, cost: Double, action: @escaping () -> Void) -> some View {
        let affordable = crops >= cost
        return Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(name)  ×\(count)").font(.system(size: 13, weight: .bold))
                    Text(rate).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(fmt(cost))
                    .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(affordable ? Theme.accent : Color.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.hairline))
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
        .opacity(affordable ? 1 : 0.6)
    }

    private func fmt(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.2fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.1fk", v / 1_000) }
        return String(format: "%.0f", v)
    }
}
