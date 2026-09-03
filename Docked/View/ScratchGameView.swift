//
//  ScratchGameView.swift
//  Docked
//
//  A scratch-off card. Drag across the foil to rub it away; once enough is
//  gone the prize reveals and is added to your lifetime total. "New card"
//  deals another. Lifetime winnings persist.
//

import SwiftUI

struct ScratchGameView: View {
    @AppStorage("docked.scratch.total") private var total: Int = 0
    @AppStorage("docked.scratch.cards") private var cards: Int = 0

    @State private var prize = -1
    @State private var scratched: Set<Int> = []
    @State private var revealed = false

    private let colsN = 18
    private let rowsN = 12

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let cardW = geo.size.width
                let cardH = min(geo.size.height, cardW * 0.6)
                let cw = cardW / CGFloat(colsN)
                let ch = cardH / CGFloat(rowsN)

                ZStack {
                    prizeFace

                    Canvas { ctx, _ in
                        guard !revealed else { return }
                        for r in 0..<rowsN {
                            for c in 0..<colsN {
                                if scratched.contains(r * colsN + c) { continue }
                                let rect = CGRect(x: CGFloat(c) * cw, y: CGFloat(r) * ch,
                                                  width: cw + 0.7, height: ch + 0.7)
                                ctx.fill(Path(rect), with: .color(Theme.TV.mid))
                            }
                        }
                    }
                    .allowsHitTesting(false)

                    if !revealed {
                        Text("SCRATCH HERE")
                            .font(.system(size: 12, weight: .heavy)).tracking(2)
                            .foregroundStyle(Theme.TV.key.opacity(0.55))
                    }
                }
                .frame(width: cardW, height: cardH)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in rub(at: v.location, cw: cw, ch: ch) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            HStack {
                Text("WON  \(total)")
                    .font(.system(size: 11, weight: .heavy)).tracking(1)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    newCard()
                } label: {
                    Label("New card", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.success, trigger: revealed) { _, now in now }
        .onAppear { if prize < 0 { rollPrize() } }
    }

    private var prizeFace: some View {
        ZStack {
            LinearGradient(colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                Text(prizeEmoji)
                    .font(.system(size: 44))
                Text(prizeText)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var prizeEmoji: String {
        if prize <= 0 { return "🍀" }
        if prize >= 1000 { return "💎" }
        return "💰"
    }

    private var prizeText: String {
        if prize <= 0 { return "No win" }
        if prize >= 1000 { return "JACKPOT \(prize)" }
        return "+\(prize)"
    }

    private func rub(at p: CGPoint, cw: CGFloat, ch: CGFloat) {
        guard !revealed else { return }
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
        if Double(scratched.count) >= Double(rowsN * colsN) * 0.5 { reveal() }
    }

    private func reveal() {
        guard !revealed else { return }
        revealed = true
        if prize > 0 { total += prize }
        cards += 1
    }

    private func rollPrize() {
        let roll = Int.random(in: 0..<100)
        if roll < 52 { prize = 0 }
        else if roll < 80 { prize = 25 }
        else if roll < 93 { prize = 75 }
        else if roll < 99 { prize = 250 }
        else { prize = 1500 }
    }

    private func newCard() {
        scratched = []
        revealed = false
        rollPrize()
    }
}
