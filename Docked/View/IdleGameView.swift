//
//  IdleGameView.swift
//  Docked
//
//  "Reactor" — a tiny idle game. Tap the core for energy; energy also trickles
//  in on its own (and catches up a capped amount while you're away). Spend it
//  on three upgrade tiers that raise the passive rate. Everything persists.
//

import SwiftUI
import Combine
import Foundation

struct IdleGameView: View {
    @AppStorage("docked.idle.energy") private var energy: Double = 0
    @AppStorage("docked.idle.a") private var tierA: Int = 0
    @AppStorage("docked.idle.b") private var tierB: Int = 0
    @AppStorage("docked.idle.c") private var tierC: Int = 0
    @AppStorage("docked.idle.seen") private var seen: Double = 0

    @State private var tap = 0

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var perSec: Double {
        Double(tierA) * 0.2 + Double(tierB) * 1.5 + Double(tierC) * 9
    }
    private var costA: Double { 10 * pow(1.16, Double(tierA)) }
    private var costB: Double { 130 * pow(1.16, Double(tierB)) }
    private var costC: Double { 1600 * pow(1.16, Double(tierC)) }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(fmt(energy))
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("\(fmt(perSec)) / sec")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Button {
                energy += 1
                tap += 1
            } label: {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.16)).frame(width: 128, height: 128)
                    Circle().fill(Theme.accent).frame(width: 90, height: 90)
                        .shadow(color: Theme.accent.opacity(0.5), radius: 14, y: 5)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.09, blue: 0.03))
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                row("Panel", "+0.2 / sec", count: tierA, cost: costA, action: buyA)
                row("Turbine", "+1.5 / sec", count: tierB, cost: costB, action: buyB)
                row("Reactor", "+9 / sec", count: tierC, cost: costC, action: buyC)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: tap)
        .onReceive(clock) { _ in energy += perSec }
        .onAppear {
            let now = Date().timeIntervalSince1970
            if seen > 0 {
                let away = min(max(now - seen, 0), 8 * 3600)
                energy += away * perSec
            }
            seen = now
        }
        .onDisappear { seen = Date().timeIntervalSince1970 }
    }

    private func buyA() { if energy >= costA { energy -= costA; tierA += 1; tap += 1 } }
    private func buyB() { if energy >= costB { energy -= costB; tierB += 1; tap += 1 } }
    private func buyC() { if energy >= costC { energy -= costC; tierC += 1; tap += 1 } }

    private func row(_ name: String, _ rate: String, count: Int, cost: Double, action: @escaping () -> Void) -> some View {
        let affordable = energy >= cost
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
