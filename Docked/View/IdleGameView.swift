//
//  IdleGameView.swift
//  Docked
//
//  "Garden Idle" — tap the soil to harvest; crops also grow on their own (with
//  capped offline catch-up). Spend crops on five plots that raise the passive
//  rate. When the garden's big enough you can replant for a permanent season
//  bonus. Everything persists.
//

import SwiftUI
import Combine
import Foundation

private struct Plot {
    let name: String
    let rate: Double
    let base: Double
}

struct IdleGameView: View {
    @AppStorage("docked.idle.energy") private var crops: Double = 0
    @AppStorage("docked.idle.lifetime") private var lifetime: Double = 0
    @AppStorage("docked.idle.seasons") private var seasons: Int = 0
    @AppStorage("docked.idle.a") private var t0: Int = 0
    @AppStorage("docked.idle.b") private var t1: Int = 0
    @AppStorage("docked.idle.c") private var t2: Int = 0
    @AppStorage("docked.idle.d") private var t3: Int = 0
    @AppStorage("docked.idle.e") private var t4: Int = 0
    @AppStorage("docked.idle.seen") private var seen: Double = 0

    @State private var tap = 0
    @State private var confirmSeason = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let plots: [Plot] = [
        Plot(name: "🌱 Seed Bed",   rate: 0.2,  base: 10),
        Plot(name: "🪴 Greenhouse", rate: 1.5,  base: 130),
        Plot(name: "🌳 Orchard",    rate: 9,    base: 1_600),
        Plot(name: "🐝 Beehive",    rate: 55,   base: 22_000),
        Plot(name: "🚜 Barn",       rate: 340,  base: 300_000),
    ]

    private var counts: [Int] { [t0, t1, t2, t3, t4] }
    private var seasonMult: Double { 1 + 0.2 * Double(seasons) }

    private var perSec: Double {
        var total = 0.0
        for (i, p) in plots.enumerated() { total += Double(counts[i]) * p.rate }
        return total * seasonMult
    }

    private func cost(_ i: Int) -> Double {
        plots[i].base * pow(1.16, Double(counts[i]))
    }

    private var seasonReady: Bool { lifetime >= 50_000 * Double(seasons + 1) }
    private var seasonGain: Int { max(1, Int((lifetime / 50_000).squareRoot())) }

    private var rateText: String {
        var s = "\(fmt(perSec)) / sec"
        if seasons > 0 { s += "   ·   Season \(seasons)" }
        return s
    }
    private var seasonButtonText: String {
        if seasonReady { return "Replant  ·  +\(seasonGain) season" }
        return "Grow \(fmt(50_000 * Double(seasons + 1))) lifetime to replant"
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text("🌾").font(.system(size: 22))
                    Text(fmt(crops))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                Text(rateText)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)

            Button {
                let g = 1 + Double(seasons)
                crops += g
                lifetime += g
                tap += 1
            } label: {
                ZStack {
                    Circle().fill(Color(red: 0.55, green: 0.40, blue: 0.26)).frame(width: 108, height: 108)
                    Circle().fill(Color(red: 0.40, green: 0.30, blue: 0.20)).frame(width: 90, height: 90)
                    Text("🌱").font(.system(size: 38))
                }
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            ScrollView {
                VStack(spacing: 7) {
                    ForEach(Array(plots.enumerated()), id: \.offset) { pair in
                        plotRow(pair.offset, pair.element)
                    }
                }
                .padding(.horizontal, 2)
            }

            Button {
                confirmSeason = true
            } label: {
                Text(seasonButtonText)
                    .font(.system(size: 12, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(seasonReady ? Theme.accent.opacity(0.9) : Theme.paper,
                               in: Capsule())
                    .foregroundStyle(seasonReady ? Color(red: 0.11, green: 0.08, blue: 0.02) : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!seasonReady)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: tap)
        .onReceive(clock) { _ in
            let g = perSec
            crops += g
            lifetime += g
        }
        .onAppear {
            let now = Date().timeIntervalSince1970
            if seen > 0 {
                let away = min(max(now - seen, 0), 8 * 3600)
                let g = away * perSec
                crops += g
                lifetime += g
            }
            seen = now
        }
        .onDisappear { seen = Date().timeIntervalSince1970 }
        .alert("Replant the garden?", isPresented: $confirmSeason) {
            Button("Cancel", role: .cancel) {}
            Button("Replant") { replant() }
        } message: {
            Text("Resets your crops and plots, but every season permanently boosts your growth rate by 20%.")
        }
    }

    private func plotRow(_ i: Int, _ p: Plot) -> some View {
        let c = cost(i)
        let affordable = crops >= c
        return Button {
            if crops >= c { crops -= c; bump(i); tap += 1 }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(p.name)  ×\(counts[i])").font(.system(size: 13, weight: .bold))
                    Text("+\(fmt(p.rate)) / sec").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(fmt(c))
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

    private func bump(_ i: Int) {
        switch i {
        case 0: t0 += 1
        case 1: t1 += 1
        case 2: t2 += 1
        case 3: t3 += 1
        default: t4 += 1
        }
    }

    private func replant() {
        seasons += seasonGain
        crops = 0
        t0 = 0; t1 = 0; t2 = 0; t3 = 0; t4 = 0
        // lifetime is kept — it's the prestige currency
    }

    private func fmt(_ v: Double) -> String {
        if v >= 1_000_000_000 { return String(format: "%.2fB", v / 1_000_000_000) }
        if v >= 1_000_000 { return String(format: "%.2fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.1fk", v / 1_000) }
        return String(format: "%.0f", v)
    }
}
