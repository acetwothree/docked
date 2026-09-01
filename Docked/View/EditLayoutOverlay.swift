//
//  EditLayoutOverlay.swift
//  Docked
//
//  Tap-to-place layout editor. Dims the screen and lights up the six spots a
//  video can sit — four corners and two centre bands — right where they'll
//  appear. Tap one to apply; tap ✕ or the backdrop to cancel.
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
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            ForEach(LayoutSolver.editTargets(size: size)) { t in
                target(t.layout, rect: t.rect)
            }

            // Instruction, centred in the free band.
            let cy = instructionY
            VStack(spacing: 5) {
                Text("Tap where your video floats")
                    .font(.system(size: 16, weight: .heavy))
                Text("everything else stays usable")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 8, y: 2)
            .position(x: size.width / 2, y: cy)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.5), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.15)))
                    .foregroundStyle(.white)
            }
            .position(x: size.width - 24, y: 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var instructionY: CGFloat {
        // middle of the content band for the current layout
        let s = LayoutSolver.solve(current, size: size)
        return min(max(s.content.midY, 120), size.height - 120)
    }

    private func target(_ layout: VideoLayout, rect: CGRect) -> some View {
        let isCurrent = layout == current
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCurrent ? Theme.accent : Theme.accent.opacity(0.10))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: isCurrent ? [CGFloat]() : [8, 6]))
            Text(layout.label + (isCurrent ? "  ✓" : ""))
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(isCurrent ? Color(red: 0.11, green: 0.08, blue: 0.02) : Theme.accent)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(isCurrent ? Color.clear : Color.black.opacity(0.35), in: Capsule())
        }
        .frame(width: rect.width, height: rect.height)
        .opacity(isCurrent ? 1 : (pulse ? 1 : 0.5))
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .onTapGesture { onPick(layout) }
    }
}
