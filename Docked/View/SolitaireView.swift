//
//  SolitaireView.swift
//  Docked
//
//  A pocket TriPeaks. Clear the little pyramid by taking any uncovered card
//  that's one rank above or below the pile card (Aces wrap to Kings). Tap the
//  stock when you're stuck. Games won persists.
//

import SwiftUI

struct SolitaireView: View {
    @AppStorage("docked.solitaire.wins") private var wins: Int = 0

    // pyramid: rows of 1,2,3,4 → flat 0..<10; each card is a 0..51 deck value
    @State private var pyramid: [Int]
    @State private var removed: Set<Int> = []
    @State private var stock: [Int]
    @State private var pileTop: Int
    @State private var moveTick = 0
    @State private var winTick = 0

    private let rowStart = [0, 1, 3, 6]   // flat index where each pyramid row begins

    init() {
        let d = Self.freshDeal()
        _pyramid = State(initialValue: d.pyramid)
        _stock = State(initialValue: d.stock)
        _pileTop = State(initialValue: d.pile)
    }

    private static func freshDeal() -> (pyramid: [Int], stock: [Int], pile: Int) {
        var deck = Array(0..<52)
        deck.shuffle()
        let pyr = Array(deck.prefix(10))
        var rest = Array(deck.dropFirst(10))
        let pile = rest.removeLast()
        return (pyr, rest, pile)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("WON \(wins)").font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { deal() } label: {
                    Label("New", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                ForEach(Array(0..<4), id: \.self) { r in
                    HStack(spacing: 6) {
                        ForEach(Array(0...r), id: \.self) { p in
                            pyramidCard(rowStart[r] + p)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 20) {
                Button { drawStock() } label: {
                    cardFace(stock.isEmpty ? nil : -1, faceUp: false)
                        .overlay(Text("\(stock.count)").font(.system(size: 13, weight: .black)).foregroundStyle(.white))
                }
                .buttonStyle(.plain)
                .disabled(stock.isEmpty)

                cardFace(pileTop, faceUp: true)
            }

            Text(removed.count == pyramid.count ? "Cleared!" : "Match one rank up or down")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(removed.count == pyramid.count ? Color.green : Color.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
        .sensoryFeedback(.success, trigger: winTick)
        .onAppear { if pyramid.isEmpty { deal() } }
    }

    private func pyramidCard(_ i: Int) -> some View {
        let gone = removed.contains(i)
        let free = isFree(i)
        return Button { take(i) } label: {
            cardFace(gone ? nil : pyramid[i], faceUp: true)
                .opacity(gone ? 0 : (free ? 1 : 0.5))
                .overlay {
                    if !gone && free && playable(pyramid[i]) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Theme.accent, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(gone)
    }

    private func cardFace(_ card: Int?, faceUp: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(faceUp ? Theme.paper : Theme.accent.opacity(0.85))
            .frame(width: 34, height: 46)
            .overlay {
                if faceUp, let card, card >= 0 {
                    VStack(spacing: 0) {
                        Text(rankLabel(card % 13))
                            .font(.system(size: 15, weight: .black))
                        Text(suitLabel(card / 13))
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(card / 13 % 2 == 0 ? Color(red: 0.8, green: 0.2, blue: 0.2) : Color.primary)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.hairline))
    }

    // MARK: logic

    private func isFree(_ i: Int) -> Bool {
        // which row is i in?
        var row = 0
        for r in 0..<4 where i >= rowStart[r] { row = r }
        if row == 3 { return true }
        let p = i - rowStart[row]
        let a = rowStart[row + 1] + p
        let b = rowStart[row + 1] + p + 1
        return removed.contains(a) && removed.contains(b)
    }

    private func playable(_ card: Int) -> Bool {
        let d = abs((card % 13) - (pileTop % 13))
        return d == 1 || d == 12
    }

    private func take(_ i: Int) {
        guard !removed.contains(i), isFree(i), playable(pyramid[i]) else { return }
        pileTop = pyramid[i]
        removed.insert(i)
        moveTick += 1
        if removed.count == pyramid.count {
            wins += 1
            winTick += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { deal() }
        }
    }

    private func drawStock() {
        guard let c = stock.popLast() else { return }
        pileTop = c
        moveTick += 1
    }

    private func deal() {
        let d = Self.freshDeal()
        pyramid = d.pyramid
        stock = d.stock
        pileTop = d.pile
        removed = []
    }

    private func rankLabel(_ r: Int) -> String {
        switch r {
        case 0: return "A"
        case 10: return "J"
        case 11: return "Q"
        case 12: return "K"
        default: return "\(r + 1)"
        }
    }
    private func suitLabel(_ s: Int) -> String {
        ["♥", "♠", "♦", "♣"][s % 4]
    }
}
