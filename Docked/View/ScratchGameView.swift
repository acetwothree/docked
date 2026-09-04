//
//  ScratchGameView.swift
//  Docked
//
//  A branded "Docked" scratch-off. Rub away the foil to reveal three symbols —
//  match all three to win, richer symbols pay more. Win or lose, a fresh card
//  deals itself. Lifetime winnings persist.
//

import SwiftUI

struct ScratchGameView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.scratch.total") private var total: Int = 0

    // symbol index 0..<6, richer = higher
    @State private var symbols: [Int] = [0, 1, 2]
    @State private var scratched: Set<Int> = []
    @State private var revealed = false
    @State private var dealing = false

    private let colsN = 21
    private let rowsN = 10
    private let icons = ["🍒", "🍋", "🔔", "⭐", "💎", "7️⃣"]
    private let payouts = [25, 50, 100, 200, 500, 1000]

    private var isWin: Bool { revealed && symbols[0] == symbols[1] && symbols[1] == symbols[2] }
    private var prize: Int { isWin ? payouts[symbols[0]] : 0 }

    var body: some View {
        VStack(spacing: 10) {
            Text("DOCKED · LUCKY SCRATCH")
                .font(.system(size: 12, weight: .black, design: .rounded)).tracking(2)
                .foregroundStyle(Theme.accent)

            GeometryReader { geo in
                let cardW = geo.size.width
                let cardH = geo.size.height
                let cw = cardW / CGFloat(colsN)
                let ch = cardH / CGFloat(rowsN)

                ZStack {
                    // prize row — three ticket windows
                    HStack(spacing: 10) {
                        ForEach(Array(0..<3), id: \.self) { i in
                            Text(icons[symbols[i] % icons.count])
                                .font(.system(size: min(cardW / 4.6, cardH * 0.58)))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Theme.TV.key.opacity(0.4), lineWidth: 2)
                                )
                        }
                    }
                    .padding(12)

                    // foil
                    Canvas { ctx, _ in
                        guard !revealed else { return }
                        for r in 0..<rowsN {
                            for c in 0..<colsN {
                                if scratched.contains(r * colsN + c) { continue }
                                let rect = CGRect(x: CGFloat(c) * cw, y: CGFloat(r) * ch,
                                                  width: cw + 0.8, height: ch + 0.8)
                                ctx.fill(Path(rect), with: .color(Theme.TV.mid))
                            }
                        }
                    }
                    .allowsHitTesting(false)

                    if !revealed && scratched.isEmpty {
                        VStack(spacing: 4) {
                            Image(systemName: "hand.draw.fill").font(.system(size: 22))
                            Text("SCRATCH").font(.system(size: 12, weight: .heavy)).tracking(3)
                        }
                        .foregroundStyle(Theme.TV.key.opacity(0.5))
                    }
                }
                .frame(width: cardW, height: cardH)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline, lineWidth: 1.5))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in rub(at: v.location, cw: cw, ch: ch) }
                )
            }

            Text(bannerText)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(isWin ? Color.green : Color.secondary)
                .frame(height: 22)

            Text("LIFETIME WINNINGS  \(total)")
                .font(.system(size: 10, weight: .heavy)).tracking(1)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.success, trigger: revealed) { _, now in now && app.haptics }
        .onAppear { if scratched.isEmpty && !revealed { deal() } }
    }

    private var bannerText: String {
        if !revealed { return "Match 3 to win" }
        if isWin { return "MATCH!  +\(prize)" }
        return "No match — new card…"
    }

    private func rub(at p: CGPoint, cw: CGFloat, ch: CGFloat) {
        guard !revealed, !dealing else { return }
        let c = Int(p.x / cw)
        let r = Int(p.y / ch)
        for dr in -1...1 {
            for dc in -1...1 {
                let rr = r + dr, cc = c + dc
                if rr >= 0, rr < rowsN, cc >= 0, cc < colsN {
                    scratched.insert(rr * colsN + cc)
                }
            }
        }
        if Double(scratched.count) >= Double(rowsN * colsN) * 0.55 {
            finish()
        }
    }

    private func finish() {
        guard !revealed else { return }
        revealed = true
        total += prize
        dealing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            deal()
        }
    }

    private func deal() {
        symbols = rollSymbols()
        scratched = []
        revealed = false
        dealing = false
    }

    private func rollSymbols() -> [Int] {
        // ~1 in 5 cards is a winner; cheaper symbols win more often.
        if Int.random(in: 0..<100) < 20 {
            let weights = [34, 26, 18, 12, 7, 3]
            var roll = Int.random(in: 0..<weights.reduce(0, +))
            var idx = 0
            for (i, wt) in weights.enumerated() {
                if roll < wt { idx = i; break }
                roll -= wt
            }
            return [idx, idx, idx]
        }
        // guaranteed non-matching triple
        var trio: [Int] = []
        while trio.count < 3 {
            let x = Int.random(in: 0..<icons.count)
            if trio.filter({ $0 == x }).count < 2 { trio.append(x) }
        }
        if trio[0] == trio[1] && trio[1] == trio[2] { trio[2] = (trio[2] + 1) % icons.count }
        return trio
    }
}
