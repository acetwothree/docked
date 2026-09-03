//
//  EditLayoutOverlay.swift
//  Docked
//
//  Tap-to-place layout editor. Fills the screen opaquely; the only things
//  shown are the six spots a video can sit and one line of instruction.
//  The targets are squeezed into whichever vertical half the current PiP
//  window is NOT covering, so a floating video can't hide the options.
//

import SwiftUI

struct EditLayoutOverlay: View {
    var size: CGSize
    var current: VideoLayout
    var onPick: (VideoLayout) -> Void
    var onCancel: () -> Void

    @State private var pulse = false

    private var targets: [LayoutSolver.EditTarget] {
        LayoutSolver.editTargets(size: size, current: current)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.backdrop
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            // instruction — sits just above the target band
            let firstY = targets.first?.rect.minY ?? size.height / 2
            VStack(spacing: 5) {
                Text("Tap where your video floats")
                    .font(.system(size: 17, weight: .heavy))
                Text("that's the only thing you set here")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .position(x: size.width / 2, y: max(48, firstY - 46))

            ForEach(targets) { t in
                target(t.layout, rect: t.rect)
            }

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Theme.paper, in: Circle())
                    .overlay(Circle().stroke(Theme.hairline))
                    .foregroundStyle(.primary)
            }
            .position(x: size.width - 30, y: 26)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func target(_ layout: VideoLayout, rect: CGRect) -> some View {
        let isCurrent = layout == current
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isCurrent ? Theme.accent : Theme.accent.opacity(0.12))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: isCurrent ? [CGFloat]() : [9, 7]))
            Text(layout.label + (isCurrent ? "  ✓" : ""))
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(isCurrent ? Color(red: 0.11, green: 0.08, blue: 0.02) : Theme.accent)
        }
        .frame(width: rect.width, height: rect.height)
        // hit region must be defined on the sized box, BEFORE .position, or
        // every target ends up covering the whole screen.
        .contentShape(Rectangle())
        .onTapGesture { onPick(layout) }
        .opacity(isCurrent ? 1 : (pulse ? 1 : 0.6))
        .position(x: rect.midX, y: rect.midY)
    }
}
