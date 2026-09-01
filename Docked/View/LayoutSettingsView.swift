//
//  LayoutSettingsView.swift
//  Docked
//
//  The layout picker sheet. Two little phone diagrams with tappable target
//  zones laid out exactly where each of the six iOS PiP states appears —
//  four small corners, two full-width bars — plus a toggle for the guide.
//

import SwiftUI

struct LayoutSettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var app = app

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Pick where iPhone's floating video (Picture in Picture) will sit. Docked keeps every control, canvas and button out from under it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    section("Small video · corner") {
                        PhoneDiagram(kind: .corners, selection: $app.selectedLayout)
                    }

                    section("Large video · full width") {
                        PhoneDiagram(kind: .bars, selection: $app.selectedLayout)
                    }

                    Toggle("Show drop-zone guide", isOn: $app.showGuide)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(20)
            }
            .navigationTitle("Video Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        app.hasOnboarded = true
                        dismiss()
                    }
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
                .frame(maxWidth: .infinity)
        }
    }
}

/// A phone outline with tappable target zones for either the four corner
/// layouts or the two full-width bar layouts.
private struct PhoneDiagram: View {
    enum Kind { case corners, bars }

    var kind: Kind
    @Binding var selection: VideoLayout

    private let phoneWidth: CGFloat = 188
    private var phoneHeight: CGFloat { phoneWidth * 1.6 }
    private let inset: CGFloat = 12

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 2)

            switch kind {
            case .corners:
                let zoneW = (phoneWidth - inset * 3) / 2
                let zoneH = zoneW * 9 / 16
                zone(.smallTopLeft, zoneW, zoneH)
                    .position(x: inset + zoneW / 2, y: inset + zoneH / 2)
                zone(.smallTopRight, zoneW, zoneH)
                    .position(x: phoneWidth - inset - zoneW / 2, y: inset + zoneH / 2)
                zone(.smallBottomLeft, zoneW, zoneH)
                    .position(x: inset + zoneW / 2, y: phoneHeight - inset - zoneH / 2)
                zone(.smallBottomRight, zoneW, zoneH)
                    .position(x: phoneWidth - inset - zoneW / 2, y: phoneHeight - inset - zoneH / 2)

            case .bars:
                let barW = phoneWidth - inset * 2
                let barH = phoneHeight * 0.42
                zone(.largeTop, barW, barH)
                    .position(x: phoneWidth / 2, y: inset + barH / 2)
                zone(.largeBottom, barW, barH)
                    .position(x: phoneWidth / 2, y: phoneHeight - inset - barH / 2)
            }
        }
        .frame(width: phoneWidth, height: phoneHeight)
    }

    private func zone(_ layout: VideoLayout, _ w: CGFloat, _ h: CGFloat) -> some View {
        let selected = selection == layout
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Theme.accent.opacity(0.92) : Color.secondary.opacity(0.14))
            .frame(width: w, height: h)
            .overlay {
                Image(systemName: selected ? "checkmark" : layout.systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(selected ? Color.black.opacity(0.8) : Color.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(Theme.layoutAnimation) { selection = layout }
            }
            .accessibilityLabel(layout.title)
            .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    LayoutSettingsView()
        .environment(AppModel())
}
