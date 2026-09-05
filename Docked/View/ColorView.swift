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

/// Apex at the bottom instead of the top — an ice-cream cone, mostly.
private struct ColorTriDown: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

enum ColorSheets {
    // A handful of BIG, mostly non-overlapping regions per sheet — easy to hit
    // with a fingertip.
    static let all: [[ColorRegion]] = [house, flower, sailboat, cat, car, rocket, icecream, butterfly, robot]

    private static func e(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(Ellipse()), rect: CGRect(x: x, y: y, width: w, height: h))
    }
    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(Rectangle()), rect: CGRect(x: x, y: y, width: w, height: h))
    }
    private static func tri(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(ColorTri()), rect: CGRect(x: x, y: y, width: w, height: h))
    }
    private static func triDown(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(ColorTriDown()), rect: CGRect(x: x, y: y, width: w, height: h))
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

    // A sailboat on calm water — 5 regions, contiguous sky/sea (no seams).
    static let sailboat: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.56),           // sky
        Self.e(0.08, 0.06, 0.22, 0.22),     // sun
        Self.rect(0, 0.56, 1, 0.44),        // sea
        Self.rect(0.30, 0.56, 0.40, 0.10),  // hull, sitting on the waterline
        Self.tri(0.46, 0.28, 0.22, 0.30),   // sail
    ]

    // A cat face — 8 regions.
    static let cat: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.6),            // sky
        Self.rect(0, 0.58, 1, 0.42),        // ground
        Self.e(0.28, 0.22, 0.44, 0.42),     // head
        Self.tri(0.26, 0.06, 0.18, 0.22),   // left ear
        Self.tri(0.56, 0.06, 0.18, 0.22),   // right ear
        Self.e(0.38, 0.42, 0.10, 0.10),     // left eye
        Self.e(0.54, 0.42, 0.10, 0.10),     // right eye
        Self.tri(0.46, 0.52, 0.08, 0.07),   // nose
    ]

    // A little car — 6 regions.
    static let car: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.55),           // sky
        Self.rect(0, 0.53, 1, 0.47),        // road
        Self.rect(0.10, 0.42, 0.80, 0.24),  // body
        Self.rect(0.30, 0.26, 0.40, 0.18),  // cabin
        Self.e(0.18, 0.60, 0.20, 0.20),     // left wheel
        Self.e(0.62, 0.60, 0.20, 0.20),     // right wheel
    ]

    // A rocket blasting off — 7 regions.
    static let rocket: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.7),            // sky
        Self.rect(0, 0.68, 1, 0.32),        // ground
        Self.rect(0.36, 0.18, 0.28, 0.48),  // body
        Self.tri(0.32, 0.02, 0.36, 0.18),   // nose cone
        Self.tri(0.16, 0.52, 0.22, 0.22),   // left fin
        Self.tri(0.62, 0.52, 0.22, 0.22),   // right fin
        Self.e(0.40, 0.30, 0.20, 0.20),     // window
    ]

    // An ice-cream cone — 5 regions.
    static let icecream: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // background
        Self.triDown(0.36, 0.55, 0.28, 0.38), // cone
        Self.e(0.28, 0.32, 0.44, 0.30),     // bottom scoop
        Self.e(0.32, 0.12, 0.36, 0.26),     // top scoop
        Self.e(0.45, 0.05, 0.10, 0.10),     // cherry
    ]

    // A butterfly — 6 regions.
    static let butterfly: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // background
        Self.rect(0.47, 0.22, 0.06, 0.56),  // body
        Self.e(0.10, 0.14, 0.36, 0.32),     // top-left wing
        Self.e(0.54, 0.14, 0.36, 0.32),     // top-right wing
        Self.e(0.16, 0.44, 0.28, 0.26),     // bottom-left wing
        Self.e(0.56, 0.44, 0.28, 0.26),     // bottom-right wing
    ]

    // A friendly robot — 10 regions.
    static let robot: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.6),            // sky
        Self.rect(0, 0.58, 1, 0.42),        // ground
        Self.e(0.45, 0.0, 0.10, 0.10),      // antenna ball
        Self.rect(0.485, 0.08, 0.03, 0.08), // antenna
        Self.rect(0.30, 0.16, 0.40, 0.26),  // head
        Self.e(0.38, 0.24, 0.09, 0.09),     // left eye
        Self.e(0.53, 0.24, 0.09, 0.09),     // right eye
        Self.rect(0.26, 0.44, 0.48, 0.32),  // body
        Self.rect(0.10, 0.46, 0.14, 0.24),  // left arm
        Self.rect(0.76, 0.46, 0.14, 0.24),  // right arm
    ]
}
