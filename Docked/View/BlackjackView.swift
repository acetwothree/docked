//
//  BlackjackView.swift
//  Docked
//
//  Dead-simple blackjack for the Gambling section. Bet play-money chips, hit
//  or stand, dealer draws to 17. Blackjack pays 3:2. If you run out of chips a
//  short timer (running while the app is open) hands you 50 more.
//

import SwiftUI

struct BlackjackView: View {
    @Environment(AppModel.self) private var app

    private enum Phase { case betting, dealing, player, dealer, done }

    @State private var phase: Phase = .betting
    @State private var bet = 25
    @State private var player: [Int] = []
    @State private var dealer: [Int] = []
    @State private var message = "Place your bet"
    @State private var dealTick = 0
    @State private var settleTick = 0
    @State private var winTick = 0

    private let minBet = 5

    private var broke: Bool { app.coins < minBet }
    private var maxBet: Int { max(minBet, min(250, app.coins)) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("BLACKJACK")
                    .font(.system(size: 12, weight: .black, design: .rounded)).tracking(2)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Label("\(app.coins)", systemImage: "circle.fill")
                    .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(Color(hex: "F5C518"))
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text(dealerHeader)
                    .font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
                hand(dealer, hideFirst: phase == .player || phase == .dealing)
            }

            VStack(spacing: 4) {
                Text(playerHeader)
                    .font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
                hand(player, hideFirst: false)
            }

            Text(message)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(messageColor)
                .frame(height: 20)

            Spacer(minLength: 0)

            // Fixed height so switching between "Dealing…", "Hit / Stand",
            // the bet row etc. never shifts the cards vertically.
            controls
                .frame(maxWidth: .infinity, minHeight: 118, maxHeight: 118)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: dealTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: settleTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: winTick) { _, _ in app.haptics }
        .onAppear { app.checkChipRefill() }
    }

    // MARK: controls

    @ViewBuilder private var controls: some View {
        switch phase {
        case .betting:
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
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        stepBtn("minus") { bet = max(minBet, bet - 5) }
                        VStack(spacing: 0) {
                            Text("BET").font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
                            Text("\(bet)").font(.system(size: 20, weight: .black)).monospacedDigit()
                        }
                        .frame(width: 64)
                        stepBtn("plus") { bet = min(maxBet, bet + 5) }
                        Button { deal() } label: {
                            Text("Deal").font(.system(size: 15, weight: .heavy))
                                .padding(.horizontal, 22).padding(.vertical, 10)
                                .background(Theme.accent, in: Capsule())
                                .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 7) {
                        chipBtn("25") { bet = min(maxBet, 25) }
                        chipBtn("50") { bet = min(maxBet, 50) }
                        chipBtn("100") { bet = min(maxBet, 100) }
                        chipBtn("½") { bet = max(minBet, bet / 2) }
                        chipBtn("2×") { bet = min(maxBet, bet * 2) }
                        chipBtn("Max") { bet = maxBet }
                    }
                }
            }
        case .dealing:
            Text("Dealing…").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
        case .player:
            HStack(spacing: 14) {
                actionBtn("Hit") { hit() }
                actionBtn("Stand") { stand() }
            }
        case .dealer:
            Text("Dealer drawing…").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
        case .done:
            Button { phase = .betting; message = "Place your bet"; player = []; dealer = [] } label: {
                Text("Next hand").font(.system(size: 15, weight: .heavy))
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
            }
            .buttonStyle(.plain)
        }
    }

    private func stepBtn(_ icon: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).font(.system(size: 15, weight: .black))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func chipBtn(_ label: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(label).font(.system(size: 12, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func actionBtn(_ label: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(label).font(.system(size: 15, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.primary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: cards

    private func hand(_ cards: [Int], hideFirst: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(cards.enumerated()), id: \.offset) { pair in
                cardView(pair.element, faceDown: hideFirst && pair.offset == 0)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                            removal: .opacity))
            }
            if cards.isEmpty {
                cardView(0, faceDown: true).opacity(0.22)
            }
        }
        .frame(height: 62)
    }

    private func cardView(_ rank: Int, faceDown: Bool) -> some View {
        ZStack {
            // back
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.accent.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.hairline))
                .opacity(faceDown ? 1 : 0)
            // front (pre-flipped so it reads right when the card is rotated 180°)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.paper)
                .overlay {
                    Text(rankLabel(rank))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.primary)
                }
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.hairline))
                .opacity(faceDown ? 0 : 1)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: 44, height: 62)
        .rotation3DEffect(.degrees(faceDown ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        .animation(.easeInOut(duration: 0.5), value: faceDown)
    }

    private func rankLabel(_ r: Int) -> String {
        switch r {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(r)"
        }
    }

    // MARK: hand values

    private func cardValue(_ r: Int) -> Int { r >= 10 ? 10 : r }

    private func total(_ cards: [Int]) -> Int {
        var sum = cards.reduce(0) { $0 + cardValue($1) }
        var aces = cards.filter { $0 == 1 }.count
        while aces > 0 && sum + 10 <= 21 { sum += 10; aces -= 1 }
        return sum
    }

    private var dealerShownTotal: Int {
        if phase == .player || phase == .dealing {
            return dealer.count > 1 ? cardValue(dealer[1]) : 0
        }
        return total(dealer)
    }

    private var dealerHeader: String {
        (phase == .betting || dealer.isEmpty) ? "DEALER" : "DEALER · \(dealerShownTotal)"
    }

    private var playerHeader: String {
        player.isEmpty ? "YOU" : "YOU · \(total(player))"
    }

    private var messageColor: Color {
        if message.hasPrefix("You win") || message.contains("Blackjack") { return .green }
        if message.hasPrefix("Bust") || message.hasPrefix("Dealer wins") { return .red }
        return .secondary
    }

    // MARK: flow

    private func draw() -> Int { Int.random(in: 1...13) }

    private func deal() {
        app.checkChipRefill()
        guard !broke else { return }
        bet = min(bet, max(minBet, app.coins))
        _ = app.placeBet(bet)
        player = []
        dealer = []
        phase = .dealing
        message = "Dealing…"

        // First two cards each, one at a time.
        let steps: [() -> Void] = [
            { player.append(draw()) },
            { dealer.append(draw()) },
            { player.append(draw()) },
            { dealer.append(draw()) },
        ]
        for (i, stepFn) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 * Double(i)) {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) { stepFn() }
                dealTick += 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 * 4 + 0.15) {
            if total(player) == 21 {
                phase = .done
                settleTick += 1
                if total(dealer) == 21 {
                    app.awardChips(bet); message = "Push"
                } else {
                    app.awardChips(bet + bet * 3 / 2)
                    message = "Blackjack! +\(bet * 3 / 2)"
                    winTick += 1
                }
                app.checkChipRefill()
            } else {
                phase = .player
                message = "Hit or stand"
            }
        }
    }

    private func hit() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { player.append(draw()) }
        dealTick += 1
        let t = total(player)
        if t > 21 {
            phase = .done
            message = "Bust — dealer wins"
            settleTick += 1
            app.checkChipRefill()
        } else if t == 21 {
            stand()   // 21 auto-stands
        }
    }

    private func stand() {
        guard phase == .player else { return }
        phase = .dealer
        message = "Dealer drawing…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dealerStep() }
    }

    private func dealerStep() {
        if total(dealer) < 17 {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { dealer.append(draw()) }
            dealTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dealerStep() }
        } else {
            settle()
        }
    }

    private func settle() {
        let p = total(player), d = total(dealer)
        phase = .done
        settleTick += 1
        if d > 21 || p > d {
            app.awardChips(bet * 2)
            message = "You win +\(bet)"
            winTick += 1
        } else if p == d {
            app.awardChips(bet)
            message = "Push"
        } else {
            message = "Dealer wins"
        }
        app.checkChipRefill()
    }
}
