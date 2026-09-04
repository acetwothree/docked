//
//  DotsBoxesView.swift
//  Docked
//
//  Pass-the-phone Dots & Boxes on a 3×3 grid. Tap between two dots to draw a
//  line; complete a box to claim it and go again. Most boxes wins.
//

import SwiftUI

struct DotsBoxesView: View {
    @Environment(AppModel.self) private var app
    private let n = 3                        // boxes per side (4 dots per side)

    @State private var hEdges: Set<Int> = [] // (n+1) rows × n : index r*n + c
    @State private var vEdges: Set<Int> = [] // n rows × (n+1) : index r*(n+1) + c
    @State private var boxes: [Int] = Array(repeating: 0, count: 9)
    @State private var turn = 1
    @State private var moveTick = 0
    @State private var boxTick = 0

    private let p1 = Color(red: 0.30, green: 0.62, blue: 1.0)
    private let p2 = Color(red: 1.0, green: 0.54, blue: 0.24)

    private var done: Bool { hEdges.count == (n + 1) * n && vEdges.count == n * (n + 1) }
    private var s1: Int { boxes.filter { $0 == 1 }.count }
    private var s2: Int { boxes.filter { $0 == 2 }.count }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                tag("P1", s1, p1, active: !done && turn == 1)
                Spacer()
                Text(statusText).font(.system(size: 13, weight: .heavy)).foregroundStyle(.secondary)
                Spacer()
                tag("P2", s2, p2, active: !done && turn == 2)
            }

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let sp = side / CGFloat(n)
                board(sp: sp)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button { reset() } label: {
                Label("New game", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: boxTick) { _, _ in app.haptics }
    }

    private var statusText: String {
        if done {
            if s1 == s2 { return "Draw" }
            return s1 > s2 ? "P1 wins" : "P2 wins"
        }
        return turn == 1 ? "P1's turn" : "P2's turn"
    }

    private func tag(_ label: String, _ score: Int, _ color: Color, active: Bool) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 14, height: 14)
            Text("\(label) \(score)").font(.system(size: 13, weight: .black)).monospacedDigit()
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(active ? Theme.accent.opacity(0.16) : Color.clear, in: Capsule())
    }

    private func board(sp: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // owned boxes
            ForEach(Array(0..<9), id: \.self) { b in
                let br = b / n, bc = b % n
                if boxes[b] != 0 {
                    RoundedRectangle(cornerRadius: 6)
                        .fill((boxes[b] == 1 ? p1 : p2).opacity(0.28))
                        .frame(width: sp - 10, height: sp - 10)
                        .position(x: CGFloat(bc) * sp + sp / 2, y: CGFloat(br) * sp + sp / 2)
                }
            }
            // horizontal edges
            ForEach(Array(0..<((n + 1) * n)), id: \.self) { hi in
                let r = hi / n, c = hi % n
                Capsule()
                    .fill(hEdges.contains(hi) ? Color.primary : Color.primary.opacity(0.12))
                    .frame(width: sp - 10, height: 4)
                    .frame(width: sp, height: 26)
                    .contentShape(Rectangle())
                    .position(x: CGFloat(c) * sp + sp / 2, y: CGFloat(r) * sp)
                    .onTapGesture { playH(hi) }
            }
            // vertical edges
            ForEach(Array(0..<(n * (n + 1))), id: \.self) { vi in
                let r = vi / (n + 1), c = vi % (n + 1)
                Capsule()
                    .fill(vEdges.contains(vi) ? Color.primary : Color.primary.opacity(0.12))
                    .frame(width: 4, height: sp - 10)
                    .frame(width: 26, height: sp)
                    .contentShape(Rectangle())
                    .position(x: CGFloat(c) * sp, y: CGFloat(r) * sp + sp / 2)
                    .onTapGesture { playV(vi) }
            }
            // dots
            ForEach(Array(0..<((n + 1) * (n + 1))), id: \.self) { d in
                let r = d / (n + 1), c = d % (n + 1)
                Circle().fill(Color.primary.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .position(x: CGFloat(c) * sp, y: CGFloat(r) * sp)
            }
        }
    }

    // MARK: logic

    private func reset() {
        hEdges = []; vEdges = []
        boxes = Array(repeating: 0, count: 9)
        turn = 1
    }

    private func playH(_ hi: Int) {
        guard !done, !hEdges.contains(hi) else { return }
        hEdges.insert(hi)
        moveTick += 1
        finishTurn(claimed: claimBoxes())
    }

    private func playV(_ vi: Int) {
        guard !done, !vEdges.contains(vi) else { return }
        vEdges.insert(vi)
        moveTick += 1
        finishTurn(claimed: claimBoxes())
    }

    private func claimBoxes() -> Bool {
        var got = false
        for b in 0..<9 where boxes[b] == 0 {
            let br = b / n, bc = b % n
            let top = br * n + bc
            let bottom = (br + 1) * n + bc
            let left = br * (n + 1) + bc
            let right = br * (n + 1) + bc + 1
            if hEdges.contains(top), hEdges.contains(bottom),
               vEdges.contains(left), vEdges.contains(right) {
                boxes[b] = turn
                got = true
            }
        }
        if got { boxTick += 1 }
        return got
    }

    private func finishTurn(claimed: Bool) {
        if !claimed { turn = turn == 1 ? 2 : 1 }
    }
}
