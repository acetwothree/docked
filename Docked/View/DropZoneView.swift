//
//  DropZoneView.swift
//  Docked
//
//  The dashed "television frame" the user drags their Picture-in-Picture
//  window onto. Purely decorative — it marks the exclusion zone the layout
//  engine has already carved out.
//

import SwiftUI

struct DropZoneView: View {
    var layout: VideoLayout

    @State private var breathing = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.accent.opacity(0.06))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Theme.accent.opacity(0.85),
                    style: StrokeStyle(lineWidth: 2, dash: [9, 7])
                )

            VStack(spacing: 8) {
                Image(systemName: "pip.fill")
                    .font(.system(size: 26, weight: .semibold))
                Text("Float your video here")
                    .font(.footnote.weight(.semibold))
                Text(layout.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Theme.accent)
            .padding(8)
            .opacity(breathing ? 1.0 : 0.55)
        }
        .compositingGroup()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Video drop zone, \(layout.title)")
    }
}

#Preview {
    DropZoneView(layout: .largeTop)
        .frame(width: 320, height: 180)
        .padding()
}
