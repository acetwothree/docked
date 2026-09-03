//
//  TVConsoleView.swift
//  Docked
//
//  A retro control panel that sits under the video border in the top layout.
//  The two "knobs" are the Move and Settings buttons dressed up as tuning
//  dials, so the whole thing reads like the front of an old wood-cabinet TV.
//

import SwiftUI

struct TVConsoleView: View {
    var moveIcon: String
    var onMove: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // speaker-grille + brand plate
            HStack(spacing: 3) {
                ForEach(Array(0..<7), id: \.self) { _ in
                    Capsule()
                        .fill(Theme.TV.key.opacity(0.28))
                        .frame(width: 2)
                }
                Text("DOCKED")
                    .font(.system(size: 9, weight: .black)).tracking(1.5)
                    .foregroundStyle(Theme.TV.key.opacity(0.55))
                    .padding(.leading, 6)
            }
            .frame(maxHeight: .infinity)

            Spacer(minLength: 8)

            knob("TUNE", icon: moveIcon, action: onMove)
            knob("SET", icon: "gearshape.fill", action: onSettings)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Theme.TV.tan, Theme.TV.lo],
                           startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.TV.key.opacity(0.5)).frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.TV.key.opacity(0.8), lineWidth: 1.5)
        )
    }

    private func knob(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Theme.TV.hi, Theme.TV.mid, Theme.TV.deep],
                                             center: UnitPoint(x: 0.35, y: 0.3),
                                             startRadius: 1, endRadius: 20))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(Theme.TV.key.opacity(0.6), lineWidth: 1))
                    Capsule()
                        .fill(Theme.TV.key)
                        .frame(width: 2.5, height: 7)
                        .offset(y: -11)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.TV.key)
                }
                Text(label)
                    .font(.system(size: 7.5, weight: .heavy)).tracking(1)
                    .foregroundStyle(Theme.TV.key.opacity(0.7))
            }
            .frame(width: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label == "TUNE" ? "Move video" : "Settings")
    }
}
