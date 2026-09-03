//
//  ClickPenView.swift
//  Docked
//
//  A pocket clicker. Press anywhere — the plunger snaps on the way down (that's
//  the click: sound + hard haptic + the counter ticks), and eases back on
//  release. The lifetime count never resets. A tiny speaker button in the
//  corner mutes the click sound (the haptic stays).
//

import SwiftUI
import AudioToolbox

struct ClickPenView: View {
    @Environment(AppModel.self) private var app

    @State private var pressed = false
    @State private var downHaptic = 0
    @State private var upHaptic = 0
    @State private var pulse = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 20) {
                Spacer(minLength: 0)

                Text("\(app.clickPenCount)")
                    .font(.system(size: 66, weight: .black, design: .rounded))
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
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { down() } }
                    .onEnded { _ in up() }
            )

            muteButton
                .padding(14)
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: downHaptic)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: upHaptic)
    }

    private var muteButton: some View {
        Button {
            app.clickerMuted.toggle()
        } label: {
            Image(systemName: app.clickerMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(app.clickerMuted ? "Unmute click sound" : "Mute click sound")
    }

    private var clicker: some View {
        ZStack {
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
        .animation(.spring(response: 0.14, dampingFraction: 0.5), value: pressed)
        .accessibilityLabel("Click. \(app.clickPenCount) clicks.")
    }

    private func down() {
        pressed = true
        app.clickPenCount += 1
        downHaptic += 1
        pulse += 1
        if !app.clickerMuted { AudioServicesPlaySystemSound(1104) }  // crisp "tock"
    }

    private func up() {
        pressed = false
        upHaptic += 1
    }
}
