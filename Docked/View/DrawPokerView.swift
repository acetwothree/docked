//
//  DrawPokerView.swift
//  Docked
//
//  "Draw Poker" (free, Gambling) — you're dealt five symbol cards one at a
//  time. Hold the ones you want, draw the rest, then the dealer reveals their
//  five. Best hand wins the pot. Bets use the shared chip balance; a broke
//  balance refills on a short timer.
//
//  Symbols and rules are original — no playing-card deck, no third-party art.
//

import SwiftUI

struct DrawPokerView: View {
    @Environment(AppModel.self) private var app

    private enum Phase { case bet, dealing, hold, reveal, result }

    // 6 symbols
    private let icons = ["star.fill", "heart.fill", "bolt.fill", "leaf.fill", "moon.fill", "flame.fill"]
    private let iconColors = [Color(hex: "F2B90C"), Color(hex: "F25CA2"), Color(hex: "4A9CFF"),
                              Color(hex: "3ECF7A"), Color(hex: "8B5CF6"), Color(hex: "FF8A3D")]
    private let rankNames = ["High", "Pair", "Two Pair", "Trips", "Full House", "Quads", "Fives"]

    @State private var phase: Phase = .bet
    @State private var player: [Int] = []
    @State private var dealer: [Int] = []
    @State private var revealCount = 0        // how many dealer cards are shown
    @State private var held: [Bool] = Array(repeating: false, count: 5)
    @State private var bet = 20
    @State private var message = ""
    @State private var dealTick = 0
    @State private var holdTick = 0
    @State private var winTick = 0
    @State private var bigWinTick = 0

    private let minBet = 5
    private var broke: Bool { app.coins < minBet }
    private var maxBet: Int { max(minBet, min(200, app.coins)) }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("DRAW POKER")
                    .font(.system(size: 12, weight: .black, design: .rounded)).tracking(2)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Label("\(app.coins)", systemImage: "circle.fill")
                    .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(Color(hex: "F5C518"))
            }

            ladder

            Spacer(minLength: 0)

            hand(cards: dealer, faceUp: { $0 < revealCount }, showHolds: false, label: "DEALER",
                 rankText: phase == .result ? rankNames[Self.rank(dealer)] : nil)

            hand(cards: player, faceUp: { _ in true }, showHolds: phase == .hold, label: "YOU",
                 rankText: player.count == 5 ? rankNames[Self.rank(player)] : nil)

            Text(message.isEmpty ? " " : message)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(message.contains("win") || message.contains("+") ? Color.green
                                 : message.contains("Dealer") ? Color.red : .secondary)
                .frame(height: 20)

            Spacer(minLength: 0)

            controls.frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: dealTick) { _, _ in app.haptics }
        .sensoryFeedback(.selection, trigger: holdTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: winTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: bigWinTick) { _, _ in app.haptics }
        .onAppear { app.checkChipRefill() }
    }

    // MARK: ladder

    private var ladder: some View {
        HStack(spacing: 4) {
            ForEach(1..<7, id: \.self) { i in
                let mine = player.count == 5 && Self.rank(player) == i
                Text(rankNames[i])
                    .font(.system(size: 8.5, weight: .heavy))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 4).padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(mine ? Theme.accent.opacity(0.9) : Color.primary.opacity(0.06),
                               in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .foregroundStyle(mine ? Color(red: 0.11, green: 0.08, blue: 0.02) : .secondary)
            }
        }
    }

    // MARK: hands

    private func hand(cards: [Int], faceUp: @escaping (Int) -> Bool, showHolds: Bool, label: String, rankText: String?) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Text(label).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
                if let rankText { Text("· \(rankText)").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.accent) }
            }
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    let up = i < cards.count && faceUp(i)
                    card(icon: up ? cards[i] : nil, held: showHolds && held.indices.contains(i) && held[i])
                        .onTapGesture {
                            guard phase == .hold, label == "YOU", i < player.count else { return }
                            held[i].toggle()
                            holdTick += 1
                        }
                }
            }
        }
    }

    private func card(icon: Int?, held: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(icon == nil ? AnyShapeStyle(Theme.accent.opacity(0.5)) : AnyShapeStyle(Theme.paper))
            .overlay {
                if let icon {
                    Image(systemName: icons[icon])
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(iconColors[icon])
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(held ? Theme.accent : Theme.hairline, lineWidth: held ? 2.5 : 1))
            .overlay(alignment: .bottom) {
                if held { Text("HELD").font(.system(size: 7, weight: .black)).foregroundStyle(Theme.accent).padding(.bottom, 1) }
            }
            .frame(width: 46, height: 62)
    }

    // MARK: controls

    @ViewBuilder private var controls: some View {
        switch phase {
        case .bet:
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
            } else {
                HStack(spacing: 12) {
                    stepBtn("minus") { bet = max(minBet, bet - 5) }
                    VStack(spacing: 0) {
                        Text("BET").font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
                        Text("\(bet)").font(.system(size: 20, weight: .black)).monospacedDigit()
                    }
                    .frame(width: 58)
                    stepBtn("plus") { bet = min(maxBet, bet + 5) }
                    Button { startDeal() } label: {
                        Text("Deal").font(.system(size: 15, weight: .heavy))
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(Theme.accent, in: Capsule())
                            .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .dealing:
            Text("Dealing…").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
        case .hold:
            Button { draw() } label: {
                Text("Draw & Show").font(.system(size: 16, weight: .heavy))
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
            }
            .buttonStyle(.plain)
        case .reveal:
            Text("Revealing…").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
        case .result:
            Button { phase = .bet; message = ""; player = []; dealer = []; revealCount = 0 } label: {
                Text("Next hand").font(.system(size: 15, weight: .heavy))
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
            }
            .buttonStyle(.plain)
        }
    }

    private func stepBtn(_ icon: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).font(.system(size: 15, weight: .black))
                .frame(width: 34, height: 34)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: flow

    private func randIcon() -> Int { Int.random(in: 0..<icons.count) }

    private func startDeal() {
        app.checkChipRefill()
        guard !broke else { return }
        bet = min(bet, max(minBet, app.coins))
        _ = app.placeBet(bet)
        player = []
        dealer = (0..<5).map { _ in randIcon() }
        revealCount = 0
        held = Array(repeating: false, count: 5)
        message = ""
        phase = .dealing
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22 * Double(i)) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { player.append(randIcon()) }
                dealTick += 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22 * 5 + 0.1) { phase = .hold }
    }

    private func draw() {
        for i in 0..<5 where !held[i] {
            player[i] = randIcon()
        }
        dealTick += 1
        phase = .reveal
        revealCount = 0
        for k in 1...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28 * Double(k)) {
                withAnimation(.easeOut(duration: 0.2)) { revealCount = k }
                dealTick += 1
                if k == 5 { settle() }
            }
        }
    }

    private func settle() {
        let p = Self.rank(player), d = Self.rank(dealer)
        phase = .result
        if p > d {
            app.awardChips(bet * 2)
            message = "You win +\(bet)"
            if p >= 4 { bigWinTick += 1 } else { winTick += 1 }
        } else if p == d {
            app.awardChips(bet)
            message = "Push"
        } else {
            message = "Dealer wins"
        }
        app.checkChipRefill()
    }

    // MARK: ranking — 0 High, 1 Pair, 2 Two Pair, 3 Trips, 4 Full House, 5 Quads, 6 Fives

    static func rank(_ cards: [Int]) -> Int {
        guard cards.count == 5 else { return 0 }
        var counts: [Int: Int] = [:]
        for c in cards { counts[c, default: 0] += 1 }
        let g = counts.values.sorted(by: >)
        switch g.first {
        case 5: return 6
        case 4: return 5
        case 3: return g.count > 1 && g[1] == 2 ? 4 : 3
        case 2: return g.count > 1 && g[1] == 2 ? 2 : 1
        default: return 0
        }
    }
}
