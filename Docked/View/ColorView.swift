//
//  ColorView.swift
//  Docked
//
//  "Color" — simple tap-to-fill colouring scenes. Pick a colour, tap a shape.
//  Save your picture or move on to the next scene. Nothing to get wrong.
//

import SwiftUI
import UIKit

struct ColorView: View {
    @Environment(AppModel.self) private var app

    private let palette: [Color] = [
        Color(hex: "E0473E"), Color(hex: "F2883C"), Color(hex: "F2B90C"),
        Color(hex: "3ECF7A"), Color(hex: "3EA1E0"), Color(hex: "8B5CF6"),
        Color(hex: "F25CA2"), Color(hex: "6B4A2E"), Color(hex: "1C1917"), Color.white,
    ]

    @State private var picked: Color = Color(hex: "3EA1E0")
    @State private var sheet = 0
    @State private var fills: [Int: Color] = [:]
    @State private var fillTick = 0
    @State private var exportImage: Image?

    private var regions: [ColorRegion] { ColorSheets.all[sheet % ColorSheets.all.count] }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height) - 8
                artwork(side: s)
                    .frame(width: s, height: s)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: fills) { _, _ in refreshExport(side: 600) }
            }

            HStack(spacing: 0) {
                ForEach(Array(palette.enumerated()), id: \.offset) { pair in
                    Circle()
                        .fill(pair.element)
                        .frame(width: 24, height: 24)
                        .overlay(Circle().strokeBorder(.primary.opacity(picked == pair.element ? 0.9 : 0.12), lineWidth: 2.5))
                        .frame(maxWidth: .infinity)
                        .contentShape(Circle())
                        .onTapGesture { picked = pair.element }
                }
            }
            .padding(.vertical, 10)

            HStack(spacing: 14) {
                Button { fills = [:] } label: {
                    Label("Clear", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)

                Spacer(minLength: 24)

                if let exportImage {
                    ShareLink(item: exportImage, preview: SharePreview("Colouring", image: exportImage)) {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .heavy))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                    }
                }

                Button { sheet += 1; fills = [:] } label: {
                    Label("Next", systemImage: "arrow.right")
                        .font(.system(size: 14, weight: .heavy))
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: fillTick) { _, _ in app.haptics }
        .onAppear { refreshExport(side: 600) }
    }

    /// Warm paper tone instead of stark white — easier on the eyes against
    /// the app's dark chrome, and close enough to white that colours still
    /// read true.
    private static let paper = Color(hex: "F2EEE1")
    /// Every line gets a light halo behind a dark core so it stays crisp
    /// whether it's sitting on the pale paper or on a dark fill colour.
    private static let lineDark = Color(hex: "2B2620")

    private func artwork(side: CGFloat) -> some View {
        ZStack {
            ForEach(Array(regions.enumerated()), id: \.offset) { pair in
                pair.element.shape
                    .fill(fills[pair.offset] ?? Self.paper)
                    .overlay(pair.element.shape.stroke(.white.opacity(0.55), lineWidth: 3.5))
                    .overlay(pair.element.shape.stroke(Self.lineDark.opacity(0.85), lineWidth: 1.6))
                    .frame(width: pair.element.rect.width * side, height: pair.element.rect.height * side)
                    .position(x: pair.element.rect.midX * side, y: pair.element.rect.midY * side)
                    .onTapGesture { fills[pair.offset] = picked; fillTick += 1 }
            }
        }
        .frame(width: side, height: side)
        .background(Self.paper)
    }

    @MainActor private func refreshExport(side: CGFloat) {
        let renderer = ImageRenderer(content: artwork(side: side).allowsHitTesting(false))
        renderer.scale = 2
        if let ui = renderer.uiImage { exportImage = Image(uiImage: ui) }
    }
}

struct ColorRegion {
    var shape: AnyShape
    var rect: CGRect   // normalised 0…1 inside a square view box
}

private struct ColorTri: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

enum ColorSheets {
    // A handful of BIG, mostly non-overlapping regions per sheet — easy to hit
    // with a fingertip.
    static let all: [[ColorRegion]] = [house, flower, sailboat]

    private static func e(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(Ellipse()), rect: CGRect(x: x, y: y, width: w, height: h))
    }
    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(Rectangle()), rect: CGRect(x: x, y: y, width: w, height: h))
    }
    private static func tri(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(ColorTri()), rect: CGRect(x: x, y: y, width: w, height: h))
    }

    // A house on a sunny day — 7 regions.
    static let house: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.62),          // sky
        Self.rect(0, 0.60, 1, 0.40),       // ground
        Self.e(0.70, 0.05, 0.20, 0.20),    // sun
        Self.tri(0.15, 0.20, 0.70, 0.24),  // roof
        Self.rect(0.22, 0.42, 0.56, 0.34), // house body
        Self.rect(0.30, 0.48, 0.13, 0.13), // window
        Self.rect(0.45, 0.56, 0.16, 0.20), // door
    ]

    // A single big flower — 10 regions (5 roomy petals + centre).
    static let flower: [ColorRegion] = {
        var r: [ColorRegion] = [
            Self.rect(0, 0, 1, 0.68),            // sky
            Self.rect(0, 0.66, 1, 0.34),         // ground
            Self.rect(0.47, 0.40, 0.06, 0.34),   // stem
            Self.e(0.30, 0.50, 0.18, 0.11),      // left leaf
            Self.e(0.52, 0.44, 0.18, 0.11),      // right leaf
        ]
        let cx: CGFloat = 0.5, cy: CGFloat = 0.30, ring: CGFloat = 0.16, pet: CGFloat = 0.17
        for k in 0..<5 {
            let a = Double(k) / 5 * 2 * .pi - .pi / 2
            r.append(Self.e(cx + CGFloat(cos(a)) * ring - pet / 2,
                            cy + CGFloat(sin(a)) * ring - pet / 2, pet, pet))
        }
        r.append(Self.e(cx - 0.09, cy - 0.09, 0.18, 0.18))   // centre (on top)
        return r
    }()

    // A sailboat at sunset — 7 regions.
    static let sailboat: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.34),           // upper sky
        Self.rect(0, 0.32, 1, 0.25),        // lower sky
        Self.e(0.08, 0.07, 0.22, 0.22),     // sun
        Self.rect(0, 0.55, 1, 0.45),        // sea
        Self.rect(0.49, 0.48, 0.03, 0.22),  // mast
        Self.tri(0.50, 0.48, 0.19, 0.22),   // sail
        Self.rect(0.34, 0.68, 0.34, 0.07),  // hull
    ]
}
