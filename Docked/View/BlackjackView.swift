//
//  BlackjackView.swift
//  Docked
//
//  Dead-simple blackjack for the Gambling section. Bet play-money chips, hit
//  or stand, dealer draws to 17. Blackjack pays 3:2. Chips can never run out —
//  a low balance quietly tops itself back up.
//

import SwiftUI

struct BlackjackView: View {
    @Environment(AppModel.self) private var app

    private enum Phase { case betting, player, dealer, done }

    @State private var phase: Phase = .betting
    @State private var bet = 25
    @State private var player: [Int] = []
    @State private var dealer: [Int] = []
    @State private var message = "Place your bet"
    @State private var settleTick = 0
    @State private var winTick = 0

    private let minBet = 5

    var body: some View {
        VStack(spacing: 14) {
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

            // Dealer
            VStack(spacing: 4) {
                Text(dealerHeader)
                    .font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
                hand(dealer, hideFirst: phase == .player)
            }

            // Player
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

            controls
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: player.count + dealer.count) { _, _ in app.haptics && phase != .betting }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: settleTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: winTick) { _, _ in app.haptics }
        .onAppear { app.ensureChips(min: minBet) }
    }

    // MARK: controls

    @ViewBuilder private var controls: some View {
        switch phase {
        case .betting:
            HStack(spacing: 14) {
                stepBtn("minus") { bet = max(minBet, bet - 5) }
                VStack(spacing: 0) {
                    Text("BET").font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
                    Text("\(bet)").font(.system(size: 20, weight: .black)).monospacedDigit()
                }
                .frame(width: 74)
                stepBtn("plus") { bet = min(maxBet, bet + 5) }
                Button { deal() } label: {
                    Text("Deal").font(.system(size: 16, weight: .heavy))
                        .padding(.horizontal, 26).padding(.vertical, 11)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
                }
                .buttonStyle(.plain)
            }
        case .player:
            HStack(spacing: 14) {
                actionBtn("Hit") { hit() }
                actionBtn("Stand") { stand() }
            }
        case .dealer:
            Text("Dealer drawing…").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
        case .done:
            Button { phase = .betting; message = "Place your bet"; player = []; dealer = [] } label: {
                Text("Next hand").font(.system(size: 16, weight: .heavy))
                    .padding(.horizontal, 26).padding(.vertical, 11)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
            }
            .buttonStyle(.plain)
        }
    }

    private var maxBet: Int { max(minBet, min(250, app.coins)) }

    private func stepBtn(_ icon: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).font(.system(size: 15, weight: .black))
                .frame(width: 38, height: 38)
                .background(Color.primary.opacity(0.08), in: Circle())
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
            }
            if cards.isEmpty {
                cardView(0, faceDown: true).opacity(0.25)
            }
        }
        .frame(height: 62)
    }

    private func cardView(_ rank: Int, faceDown: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(faceDown ? AnyShapeStyle(Theme.accent.opacity(0.5)) : AnyShapeStyle(Theme.paper))
            .overlay {
                if !faceDown {
                    Text(rankLabel(rank))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.primary)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.hairline))
            .frame(width: 44, height: 62)
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
        if phase == .player { return dealer.count > 1 ? cardValue(dealer[1]) : 0 }
        return total(dealer)
    }

    private var dealerHeader: String {
        phase == .betting ? "DEALER" : "DEALER · \(dealerShownTotal)"
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
        app.ensureChips(min: minBet)
        bet = min(bet, max(minBet, app.coins))
        _ = app.placeBet(bet)
        player = [draw(), draw()]
        dealer = [draw(), draw()]
        phase = .player
        message = "Hit or stand"
        if total(player) == 21 {
            // natural blackjack
            phase = .done
            if total(dealer) == 21 {
                app.awardChips(bet)
                message = "Push"
            } else {
                app.awardChips(bet + bet * 3 / 2)
                message = "Blackjack! +\(bet * 3 / 2)"
                winTick += 1
            }
            settleTick += 1
            app.ensureChips(min: minBet)
        }
    }

    private func hit() {
        player.append(draw())
        if total(player) > 21 {
            phase = .done
            message = "Bust — dealer wins"
            settleTick += 1
            app.ensureChips(min: minBet)
        }
    }

    private func stand() {
        phase = .dealer
        message = "Dealer drawing…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dealerStep() }
    }

    private func dealerStep() {
        if total(dealer) < 17 {
            dealer.append(draw())
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { dealerStep() }
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
        app.ensureChips(min: minBet)
    }
}
