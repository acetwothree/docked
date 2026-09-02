//
//  EditLayoutOverlay.swift
//  Docked
//
//  Tap-to-place layout editor. Fills the screen opaquely — the only things
//  visible are the six spots a video can sit (four corners, two centre
//  bands), one line of instruction, and a close button. Tap a spot to apply;
//  tap ✕ to cancel.
//

import SwiftUI

struct EditLayoutOverlay: View {
    var size: CGSize
    var current: VideoLayout
    var onPick: (VideoLayout) -> Void
    var onCancel: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.backdrop
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            ForEach(LayoutSolver.editTargets(size: size)) { t in
                target(t.layout, rect: t.rect)
            }

            VStack(spacing: 5) {
                Text("Tap where your video floats")
                    .font(.system(size: 16, weight: .heavy))
                Text("that's the only thing you set here")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .position(x: size.width / 2, y: size.height / 2)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Theme.paper, in: Circle())
                    .overlay(Circle().stroke(Theme.hairline))
                    .foregroundStyle(.primary)
            }
            .position(x: size.width - 26, y: 22)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func target(_ layout: VideoLayout, rect: CGRect) -> some View {
        let isCurrent = layout == current
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCurrent ? Theme.accent : Theme.accent.opacity(0.10))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: isCurrent ? [CGFloat]() : [8, 6]))
            Text(layout.label + (isCurrent ? "  ✓" : ""))
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundStyle(isCurrent ? Color(red: 0.11, green: 0.08, blue: 0.02) : Theme.accent)
        }
        .frame(width: rect.width, height: rect.height)
        .opacity(isCurrent ? 1 : (pulse ? 1 : 0.55))
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .onTapGesture { onPick(layout) }
    }
}
