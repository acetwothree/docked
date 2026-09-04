//
//  PopView.swift
//  Docked
//
//  "Pop" — a sheet of big bubble-wrap bubbles. Tap one to pop it (spring +
//  haptic). When every bubble is popped the sheet re-inflates automatically.
//

import SwiftUI

struct PopView: View {
    @Environment(AppModel.self) private var app
    @State private var popped: Set<Int> = []
    @State private var resetting = false

    private let diameter: CGFloat = 66
    private let gap: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let topReserve: CGFloat = 26      // room for the "sheets cleared" line
            let cols = max(3, Int((geo.size.width - gap) / (diameter + gap)))
            let rows = max(3, Int((geo.size.height - topReserve - gap) / (diameter + gap)))
            let total = cols * rows
            let gridW = CGFloat(cols) * diameter + CGFloat(cols - 1) * gap
            let gridH = CGFloat(rows) * diameter + CGFloat(rows - 1) * gap
            let ox = (geo.size.width - gridW) / 2
            let oy = topReserve + (geo.size.height - topReserve - gridH) / 2

            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(Array(0..<total), id: \.self) { i in
                    let r = i / cols, c = i % cols
                    Bubble(popped: popped.contains(i))
                        .frame(width: diameter, height: diameter)
                        .position(x: ox + CGFloat(c) * (diameter + gap) + diameter / 2,
                                  y: oy + CGFloat(r) * (diameter + gap) + diameter / 2)
                        .onTapGesture { pop(i, total: total) }
                }

                Text("SHEETS CLEARED  \(app.popClearCount)")
                    .font(.system(size: 10, weight: .heavy)).tracking(1.5)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sensoryFeedback(.impact(weight: .medium), trigger: popped.count) { _, _ in app.haptics }
            .onChange(of: total) { _, _ in popped.removeAll() }
        }
    }

    private func pop(_ i: Int, total: Int) {
        guard !resetting, !popped.contains(i) else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) {
            _ = popped.insert(i)
        }
        if popped.count >= total {
            resetting = true
            app.popClearCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.35)) { popped.removeAll() }
                resetting = false
            }
        }
    }
}

private struct Bubble: View {
    var popped: Bool

    var body: some View {
        Circle()
            .fill(popped
                  ? AnyShapeStyle(Color.primary.opacity(0.06))
                  : AnyShapeStyle(RadialGradient(
                        colors: [Color(hex: "B7CEEA"), Color(hex: "6C90BE")],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 2, endRadius: 46)))
            .overlay {
                if popped {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 2)
                        .padding(5)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 14, height: 14)
                        .offset(x: -diameterHint * 0.16, y: -diameterHint * 0.16)
                }
            }
            .scaleEffect(popped ? 0.8 : 1)
            .shadow(color: .black.opacity(popped ? 0 : 0.22), radius: popped ? 0 : 3, y: 2)
    }

    // the highlight offset scales with the bubble; 66 is the fixed diameter.
    private var diameterHint: CGFloat { 66 }
}
