//
//  ScratchGameView.swift
//  Docked
//
//  The Gambling section's scratch-off. Buy a ticket with chips, rub away the
//  foil to reveal three symbols — match all three to win chips. Win → the
//  ticket flashes gold and chips count up into the balance. Lose → the ticket
//  is tossed and a fresh one is ready to buy. Both are fast. Chips can't run
//  out — a broke balance refills on a short timer.
//

import SwiftUI

struct ScratchGameView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.scratch.total") private var total: Int = 0

    private let ticketCost = 15

    @State private var symbols: [Int] = [0, 1, 2]
    @State private var scratched: Set<Int> = []
    @State private var revealed = false
    @State private var awaitingBuy = true

    // card animation
    @State private var cardScale: CGFloat = 1
    @State private var cardRot: Double = 0
    @State private var cardOffset: CGSize = .zero
    @State private var cardOpacity: Double = 1
    @State private var winFlash = false
    @State private var flyPrize: Int? = nil
    @State private var displayCoins = 0
    @State private var tossTick = 0

    private let colsN = 21
    private let rowsN = 10
    private let icons = ["🍒", "🍋", "🔔", "⭐", "💎", "7️⃣"]
    private let payouts = [30, 60, 120, 250, 600, 1500]

    private var isWin: Bool { revealed && symbols[0] == symbols[1] && symbols[1] == symbols[2] }
    private var prize: Int { isWin ? payouts[symbols[0] % payouts.count] : 0 }
    private var broke: Bool { app.coins < ticketCost }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("DOCKED · LUCKY SCRATCH")
                    .font(.system(size: 12, weight: .black, design: .rounded)).tracking(2)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Label("\(displayCoins)", systemImage: "circle.fill")
                    .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(Color(hex: "F5C518"))
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                let cardW = geo.size.width
                let cardH = geo.size.height
                let cw = cardW / CGFloat(colsN)
                let ch = cardH / CGFloat(rowsN)

                ZStack {
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

                    if !revealed && scratched.isEmpty && !awaitingBuy {
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
                .overlay {
                    if winFlash {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: "F5C518").opacity(0.4))
                    }
                }
                .scaleEffect(cardScale)
                .rotationEffect(.degrees(cardRot))
                .offset(cardOffset)
                .opacity(cardOpacity)
                .overlay {
                    if let p = flyPrize {
                        Text("+\(p)")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "F5C518"))
                            .shadow(color: .black.opacity(0.3), radius: 3)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.6).combined(with: .opacity),
                                removal: .offset(y: -70).combined(with: .opacity)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in rub(at: v.location, cw: cw, ch: ch) }
                )

                if awaitingBuy {
                    buyOverlay
                        .frame(width: cardW, height: cardH)
                }
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
        .sensoryFeedback(.success, trigger: winFlash) { _, now in now && app.haptics }
        .sensoryFeedback(.impact(weight: .rigid), trigger: tossTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(weight: .light), trigger: scratched.count) { _, _ in app.haptics && !revealed }
        .onAppear {
            displayCoins = app.coins
            app.checkChipRefill()
        }
        .onChange(of: app.coins) { _, new in
            withAnimation(.easeOut(duration: 0.4)) { displayCoins = new }
        }
    }

    @ViewBuilder private var buyOverlay: some View {
        if broke {
            VStack(spacing: 4) {
                Text("Out of chips").font(.system(size: 14, weight: .heavy))
                if let at = app.chipRefillAt {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let s = max(0, Int(at.timeIntervalSince(ctx.date).rounded(.up)))
                        Text("+\(AppModel.chipRefillAmount) chips in \(s)s")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            Button { buyTicket() } label: {
                VStack(spacing: 2) {
                    Text("New Ticket").font(.system(size: 16, weight: .heavy))
                    Text("\(ticketCost) chips").font(.system(size: 11, weight: .semibold)).opacity(0.85)
                }
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(Theme.accent, in: Capsule())
                .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
            }
            .buttonStyle(.plain)
        }
    }

    private var bannerText: String {
        if awaitingBuy && !revealed { return "Match 3 to win chips" }
        if !revealed { return "Match 3 to win" }
        if isWin { return "MATCH!" }
        return "No match"
    }

    private func buyTicket() {
        app.checkChipRefill()
        guard !broke else { return }
        _ = app.placeBet(ticketCost)
        symbols = rollSymbols()
        scratched = []
        revealed = false
        cardScale = 1; cardRot = 0; cardOffset = .zero; cardOpacity = 1
        awaitingBuy = false
    }

    private func rub(at p: CGPoint, cw: CGFloat, ch: CGFloat) {
        guard !revealed, !awaitingBuy else { return }
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
        if Double(scratched.count) >= Double(rowsN * colsN) * 0.5 {
            finish()
        }
    }

    private func finish() {
        guard !revealed else { return }
        revealed = true

        if isWin {
            let p = prize
            total += p
            withAnimation(.easeOut(duration: 0.15)) { winFlash = true }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { flyPrize = p }
            // fly the "+prize" up, then bank the chips
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                app.awardChips(p)                 // triggers the count-up
                withAnimation(.easeIn(duration: 0.35)) { flyPrize = nil }
                withAnimation(.easeIn(duration: 0.3)) { winFlash = false }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                app.checkChipRefill()
                awaitingBuy = true
            }
        } else {
            // Losing ticket: hold the "No match" result long enough to read,
            // then a legible two-stage toss — a small crumple, then it spins
            // away off the bottom.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                tossTick += 1
                withAnimation(.easeInOut(duration: 0.16)) {
                    cardScale = 0.82
                    cardRot = -6
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.easeIn(duration: 0.42)) {
                        cardScale = 0.4
                        cardRot = 26
                        cardOffset = CGSize(width: 70, height: 130)
                        cardOpacity = 0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                    app.checkChipRefill()
                    awaitingBuy = true
                }
            }
        }
    }

    private func rollSymbols() -> [Int] {
        if Int.random(in: 0..<100) < 22 {
            let weights = [34, 26, 18, 12, 7, 3]
            var roll = Int.random(in: 0..<weights.reduce(0, +))
            var idx = 0
            for (i, wt) in weights.enumerated() {
                if roll < wt { idx = i; break }
                roll -= wt
            }
            return [idx, idx, idx]
        }
        var trio: [Int] = []
        while trio.count < 3 {
            let x = Int.random(in: 0..<icons.count)
            if trio.filter({ $0 == x }).count < 2 { trio.append(x) }
        }
        if trio[0] == trio[1] && trio[1] == trio[2] { trio[2] = (trio[2] + 1) % icons.count }
        return trio
    }
}
