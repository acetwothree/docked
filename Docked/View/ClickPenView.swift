//
//  ClickPenView.swift
//  Docked
//
//  A pocket clicker. Tap anywhere — the plunger snaps, a crisp tick plays,
//  the haptic fires and the lifetime count ticks up. It never resets.
//

import SwiftUI
import AudioToolbox

struct ClickPenView: View {
    @Environment(AppModel.self) private var app

    @State private var pressed = false
    @State private var pulse = 0
    @State private var haptic = 0

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            Text("\(app.clickPenCount)")
                .font(.system(size: 68, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.18), value: app.clickPenCount)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 24)

            Text("LIFETIME CLICKS")
                .font(.system(size: 10, weight: .heavy)).tracking(2.5)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            clicker
                .padding(.bottom, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { click() }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: haptic)
    }

    private var clicker: some View {
        ZStack {
            // expanding ring on each press
            Circle()
                .stroke(Theme.accent.opacity(0.35), lineWidth: 3)
                .frame(width: 150, height: 150)
                .scaleEffect(pressed ? 1.35 : 0.85)
                .opacity(pressed ? 0 : 0.9)
                .animation(.easeOut(duration: 0.45), value: pulse)

            Circle()
                .fill(Theme.accent.opacity(0.16))
                .frame(width: 176, height: 176)

            Circle()
                .fill(Theme.accent)
                .frame(width: 124, height: 124)
                .shadow(color: Theme.accent.opacity(0.55), radius: pressed ? 3 : 18, y: pressed ? 1 : 6)
                .scaleEffect(pressed ? 0.9 : 1)

            Image(systemName: "hand.tap.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.09, blue: 0.03))
                .scaleEffect(pressed ? 0.86 : 1)
                .offset(y: pressed ? 2 : 0)
        }
        .animation(.spring(response: 0.16, dampingFraction: 0.45), value: pressed)
        .accessibilityLabel("Click. \(app.clickPenCount) clicks.")
    }

    private func click() {
        app.clickPenCount += 1
        haptic += 1
        pulse += 1
        AudioServicesPlaySystemSound(1104)   // crisp keyboard "tock"
        pressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { pressed = false }
    }
}
