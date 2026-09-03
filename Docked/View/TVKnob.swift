//
//  TVKnob.swift
//  Docked
//
//  A single tuning-dial button for the TV console. Turns a little on each press.
//

import SwiftUI

struct TVKnob: View {
    var icon: String
    var palette: TVPalette
    var action: () -> Void

    @State private var turn = 0.0

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { turn += 40 }
            action()
        } label: {
            ZStack {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [palette.hi, palette.mid, palette.deep],
                                             center: UnitPoint(x: 0.35, y: 0.3),
                                             startRadius: 1, endRadius: 20))
                        .overlay(Circle().strokeBorder(palette.key.opacity(0.6), lineWidth: 1))
                    Capsule()
                        .fill(palette.key)
                        .frame(width: 2.5, height: 8)
                        .offset(y: -9)
                }
                .rotationEffect(.degrees(turn))
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.key)
            }
            .frame(width: LayoutSolver.knobDiameter, height: LayoutSolver.knobDiameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
