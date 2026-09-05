//
//  RingsView.swift
//  Docked
//
//  "Rings" — the classic tower puzzle. Move the rings one at a time between
//  the three pegs and rebuild the stack on the right, smallest on top. You can
//  never drop a bigger ring on a smaller one.
//

import SwiftUI

struct RingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.rings.level") private var ringCount = 4

    @State private var pegs: [[Int]] = [[], [], []]   // each: bottom → top, sizes
    @State private var held: (peg: Int, size: Int)? = nil
    @State private var moves = 0
    @State private var solved = false
    @State private var loaded = false
    @State private var liftTick = 0
    @State private var dropTick = 0
    @State private var nopeTick = 0
    @State private var winTick = 0

    private let ringColors: [Color] = [
        Color(hex: "E0473E"), Color(hex: "F2883C"), Color(hex: "F2B90C"),
        Color(hex: "3ECF7A"), Color(hex: "3EA1E0"), Color(hex: "8B5CF6"), Color(hex: "F25CA2"),
    ]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    stepBtn("minus.circle.fill", enabled: ringCount > 3) { newGame(ringCount - 1) }
                    Text("RINGS \(ringCount)")
                        .font(.system(size: 12, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
                        .frame(minWidth: 58)
                    stepBtn("plus.circle.fill", enabled: ringCount < 7) { newGame(ringCount + 1) }
                }
                Spacer()
                Text("MOVES \(moves)")
                    .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(solved ? Color.green : Color.secondary)
                Spacer()
                Button { newGame(ringCount) } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary).frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
            }

            Text("Goal: move the whole stack onto the ▶ right peg, big on the bottom. You can never place a bigger ring on a smaller one.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

            GeometryReader { geo in
                let W = geo.size.width, H = geo.size.height
                let pegW = W / 3
                let baseY = H - 18
                let ringH = min(20, (H - 60) / CGFloat(max(3, ringCount + 1)))
                let unit = (pegW - 24) / CGFloat(ringCount + 1)

                ZStack {
                    // pegs
                    ForEach(0..<3, id: \.self) { p in
                        let cx = pegW * (CGFloat(p) + 0.5)
                        let isGoal = p == 2
                        Capsule().fill(isGoal ? Theme.accent.opacity(0.35) : Theme.ink.opacity(0.18))
                            .frame(width: 6, height: H - 30)
                            .position(x: cx, y: (H - 30) / 2 + 6)
                        Capsule().fill(isGoal ? Theme.accent : Theme.ink.opacity(0.25))
                            .frame(width: pegW - 14, height: isGoal ? 7 : 6)
                            .position(x: cx, y: baseY + 4)
                        if isGoal {
                            Text("GOAL PEG").font(.system(size: 8, weight: .black)).tracking(2)
                                .foregroundStyle(Theme.accent)
                                .position(x: cx, y: baseY + 15)
                        }
                        // stacked rings
                        ForEach(Array(pegs[p].enumerated()), id: \.offset) { pair in
                            ringBar(size: pair.element, unit: unit, height: ringH)
                                .position(x: cx, y: baseY - ringH / 2 - CGFloat(pair.offset) * (ringH + 2))
                        }
                        // held ring hovers above its source peg
                        if let h = held, h.peg == p {
                            ringBar(size: h.size, unit: unit, height: ringH)
                                .position(x: cx, y: 16)
                        }
                    }

                    // tap targets
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { p in
                            Rectangle().fill(Color.clear)
                                .frame(width: pegW, height: H)
                                .contentShape(Rectangle())
                                .onTapGesture { tapPeg(p) }
                        }
                    }
                }
                .frame(width: W, height: H)
            }

            Text(solved ? "Solved in \(moves)! Use +/− above to change the ring count"
                 : held == nil ? "Tap a peg to lift its top ring" : "Tap a peg to drop it")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(solved ? Color.green : Color.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: liftTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: dropTick) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: nopeTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: winTick) { _, _ in app.haptics }
        .onAppear { if !loaded { newGame(ringCount); loaded = true } }
    }

    private func stepBtn(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(enabled ? Color.secondary : Color.secondary.opacity(0.3))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func ringBar(size: Int, unit: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(ringColors[(size - 1) % ringColors.count])
            .overlay(RoundedRectangle(cornerRadius: height / 2).stroke(.white.opacity(0.25), lineWidth: 1))
            .frame(width: 22 + CGFloat(size) * unit, height: height)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    private func newGame(_ n: Int) {
        ringCount = n
        pegs = [Array((1...n).reversed()), [], []]
        held = nil
        moves = 0
        solved = false
    }

    private func tapPeg(_ p: Int) {
        guard !solved else { return }
        if let h = held {
            // dropping
            if p == h.peg {
                pegs[p].append(h.size)   // put it back
                held = nil
                return
            }
            if let top = pegs[p].last, top < h.size {
                nopeTick += 1
                return
            }
            pegs[p].append(h.size)
            held = nil
            moves += 1
            dropTick += 1
            if pegs[2].count == ringCount {
                solved = true
                winTick += 1
            }
        } else {
            // lifting
            guard let top = pegs[p].popLast() else { return }
            held = (peg: p, size: top)
            liftTick += 1
        }
    }
}
