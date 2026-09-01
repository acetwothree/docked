//
//  ControlsCluster.swift
//  Docked
//
//  The two always-on buttons — move-video (opens the tap-to-place editor) and
//  settings. Repositioned by the layout solver: beside the video for corner
//  layouts (with a status chip), floating in a content corner otherwise.
//

import SwiftUI

struct ControlsCluster: View {
    @Environment(AppModel.self) private var app
    var solved: SolvedLayout
    var openSettings: () -> Void

    var body: some View {
        Group {
            if solved.controlsIsSideStrip {
                HStack(spacing: 6) {
                    buttons
                    chip
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 6) { buttons }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var buttons: some View {
        HStack(spacing: 6) {
            iconButton("rectangle.on.rectangle.angled") {
                withAnimation(.easeInOut(duration: 0.2)) { app.isEditingLayout.toggle() }
            }
            iconButton("gearshape.fill", action: openSettings)
        }
    }

    private var chip: some View {
        Text("Video: \(app.layout.label)\nTap ⧉ to move")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.hairline))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.hairline))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
    }
}
