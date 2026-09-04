//
//  TVKnob.swift
//  Docked
//
//  A tuning-dial button for the TV console. It tilts on press and springs
//  straight back, so the knobs always sit aligned.
//

import SwiftUI

struct TVKnob: View {
    var icon: String
    var palette: TVPalette
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            pressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { pressed = false }
        } label: {
            ZStack {
                // The dial — this is the part that tilts on press.
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [palette.hi, palette.mid, palette.deep],
                                             center: UnitPoint(x: 0.35, y: 0.3),
                                             startRadius: 1, endRadius: 20))
                        .overlay(Circle().strokeBorder(palette.key.opacity(0.6), lineWidth: 1))
                    Capsule()
                        .fill(palette.key)
                        .frame(width: 2.5, height: 7)
                        .offset(y: -10)
                }
                .rotationEffect(.degrees(pressed ? 20 : 0))
                .animation(.spring(response: 0.32, dampingFraction: 0.5), value: pressed)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

                // Fixed centre label — a small dark chip so the glyph always
                // has the same contrast on every wood theme, and it stays dead
                // centre while the dial tilts underneath.
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        .frame(width: 20, height: 20)
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 0.5)
                }
            }
            .frame(width: LayoutSolver.knobDiameter, height: LayoutSolver.knobDiameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
