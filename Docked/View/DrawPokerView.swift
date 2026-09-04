//
//  DrawPokerView.swift
//  Docked
//
//  "Draw Poker" (premium) — five-card draw video poker with a standard 52-card
//  deck. Bet chips, hold the cards you want, draw once, get paid on the
//  standard Jacks-or-Better table. Chips can't run out — a broke balance
//  refills on a short timer.
//
//  Original mechanic + a normal playing-card deck. No third-party assets.
//

import SwiftUI

struct DrawPokerView: View {
    @Environment(AppModel.self) private var app

    private enum Phase { case bet, draw, result }

    @State private var phase: Phase = .bet
    @State private var hand: [Card] = []
    @State private var held: [Bool] = Array(repeating: false, count: 5)
    @State private var deck: [Card] = []
    @State private var bet = 20
    @State private var result = ""
    @State private var dealTick = 0
    @State private var holdTick = 0
    @State private var winTick = 0
    @State private var bigWinTick = 0

    private let minBet = 5
    private var broke: Bool { app.coins < minBet }
    private var maxBet: Int { max(minBet, min(200, app.coins)) }

    struct Card: Equatable {
        var rank: Int   // 2...14 (11 J, 12 Q, 13 K, 14 A)
        var suit: Int   // 0 ♠  1 ♥  2 ♦  3 ♣
        var glyph: String { ["♠", "♥", "♦", "♣"][suit] }
        var isRed: Bool { suit == 1 || suit == 2 }
        var label: String {
            switch rank {
            case 14: return "A"; case 13: return "K"; case 12: return "Q"; case 11: return "J"
            default: return "\(rank)"
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("DRAW POKER")
                    .font(.system(size: 12, weight: .black, design: .rounded)).tracking(2)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Label("\(app.coins)", systemImage: "circle.fill")
                    .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(Color(hex: "F5C518"))
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                ForEach(Array(hand.enumerated()), id: \.offset) { pair in
                    cardView(pair.element, held: held[pair.offset])
                        .onTapGesture {
                            guard phase == .draw else { return }
                            held[pair.offset].toggle()
                            holdTick += 1
                        }
                }
                if hand.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 7).fill(Theme.accent.opacity(0.4))
                            .frame(width: 46, height: 66).opacity(0.3)
                    }
                }
            }
            .frame(height: 80)

            Text(result.isEmpty ? " " : result)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(result.contains("+") ? Color.green : .secondary)
                .frame(height: 20)

            Spacer(minLength: 0)

            controls
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: dealTick) { _, _ in app.haptics }
        .sensoryFeedback(.selection, trigger: holdTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: winTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: bigWinTick) { _, _ in app.haptics }
        .onAppear { app.checkChipRefill() }
    }

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
                    step("minus") { bet = max(minBet, bet - 5) }
                    VStack(spacing: 0) {
                        Text("BET").font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
                        Text("\(bet)").font(.system(size: 20, weight: .black)).monospacedDigit()
                    }
                    .frame(width: 60)
                    step("plus") { bet = min(maxBet, bet + 5) }
                    Button { deal() } label: {
                        Text("Deal").font(.system(size: 15, weight: .heavy))
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(Theme.accent, in: Capsule())
                            .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .draw:
            Button { draw() } label: {
                Text("Draw").font(.system(size: 15, weight: .heavy))
                    .padding(.horizontal, 26).padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
            }
            .buttonStyle(.plain)
        case .result:
            Button { phase = .bet; result = "" } label: {
                Text("Next hand").font(.system(size: 15, weight: .heavy))
                    .padding(.horizontal, 22).padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
            }
            .buttonStyle(.plain)
        }
    }

    private func step(_ icon: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).font(.system(size: 15, weight: .black))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func cardView(_ c: Card, held: Bool) -> some View {
        VStack(spacing: 1) {
            Text(c.label).font(.system(size: 17, weight: .black, design: .rounded))
            Text(c.glyph).font(.system(size: 15))
        }
        .foregroundStyle(c.isRed ? Color(hex: "E0473E") : Color.primary)
        .frame(width: 46, height: 66)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(held ? Theme.accent : Theme.hairline, lineWidth: held ? 2.5 : 1))
        .overlay(alignment: .bottom) {
            if held {
                Text("HELD").font(.system(size: 7, weight: .black))
                    .foregroundStyle(Theme.accent).padding(.bottom, 1)
            }
        }
    }

    // MARK: flow

    private func freshDeck() -> [Card] {
        var d: [Card] = []
        for s in 0..<4 { for r in 2...14 { d.append(Card(rank: r, suit: s)) } }
        d.shuffle()
        return d
    }

    private func deal() {
        app.checkChipRefill()
        guard !broke else { return }
        bet = min(bet, max(minBet, app.coins))
        _ = app.placeBet(bet)
        deck = freshDeck()
        hand = Array(deck.prefix(5))
        deck.removeFirst(5)
        held = Array(repeating: false, count: 5)
        result = ""
        phase = .draw
        dealTick += 1
    }

    private func draw() {
        for i in 0..<5 where !held[i] {
            hand[i] = deck.removeFirst()
        }
        dealTick += 1
        let (name, mult) = Self.evaluate(hand)
        phase = .result
        if mult > 0 {
            let payout = bet * mult
            app.awardChips(payout)
            result = "\(name)  +\(payout)"
            if mult >= 9 { bigWinTick += 1 } else { winTick += 1 }
        } else {
            result = "No pay — \(name)"
        }
        app.checkChipRefill()
    }

    // MARK: hand ranking (Jacks or Better)

    static func evaluate(_ cards: [Card]) -> (String, Int) {
        let ranks = cards.map { $0.rank }.sorted()
        let suits = Set(cards.map { $0.suit })
        var counts: [Int: Int] = [:]
        for r in ranks { counts[r, default: 0] += 1 }
        let groups = counts.values.sorted(by: >)

        let flush = suits.count == 1
        let unique = Set(ranks).sorted()
        var straight = false
        if unique.count == 5 {
            if unique[4] - unique[0] == 4 { straight = true }
            if unique == [2, 3, 4, 5, 14] { straight = true }   // wheel
        }

        if straight && flush {
            return unique == [10, 11, 12, 13, 14] ? ("Royal Flush", 250) : ("Straight Flush", 50)
        }
        if groups.first == 4 { return ("Four of a Kind", 25) }
        if groups.first == 3 && groups.count > 1 && groups[1] == 2 { return ("Full House", 9) }
        if flush { return ("Flush", 6) }
        if straight { return ("Straight", 4) }
        if groups.first == 3 { return ("Three of a Kind", 3) }
        if groups.first == 2 && groups.count > 1 && groups[1] == 2 { return ("Two Pair", 2) }
        if groups.first == 2 {
            // paying pair only if it's Jacks or better
            if let pairRank = counts.first(where: { $0.value == 2 })?.key, pairRank >= 11 {
                return ("Jacks or Better", 1)
            }
            return ("Low Pair", 0)
        }
        return ("High Card", 0)
    }
}
