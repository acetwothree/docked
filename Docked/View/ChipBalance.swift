//
//  ChipBalance.swift
//  Docked
//
//  The chip-balance readout used across the Gambling activities. Counts up/down
//  on change and flashes green (gain) or red (loss) with a small shake.
//

import SwiftUI

struct ChipBalance: View {
    let coins: Int

    @State private var shown = 0
    @State private var flash: Color? = nil
    @State private var shake: CGFloat = 0

    var body: some View {
        Label("\(shown)", systemImage: "circle.fill")
            .font(.system(size: 12, weight: .heavy)).monospacedDigit()
            .foregroundStyle(flash ?? Color(hex: "F5C518"))
            .contentTransition(.numericText())
            .offset(x: shake)
            .onAppear { shown = coins }
            .onChange(of: coins) { old, new in
                let up = new > old
                withAnimation(.easeOut(duration: 0.45)) { shown = new }
                withAnimation(.easeOut(duration: 0.12)) { flash = up ? .green : .red }
                withAnimation(.spring(response: 0.18, dampingFraction: 0.35)) { shake = up ? 4 : -4 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { shake = 0 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeIn(duration: 0.4)) { flash = nil }
                }
            }
    }
}
