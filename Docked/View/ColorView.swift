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
    static let all: [[ColorRegion]] = [
        house, flower, sailboat, cat, car, rocket, icecream, butterfly, robot,
        fish, sun, tree, balloon, snowman, ghost, mushroom, crown, apple, planet,
    ]

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

    // A cat face — 8 regions, symmetric about the vertical centre line.
    static let cat: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.58),           // sky
        Self.rect(0, 0.56, 1, 0.44),        // ground
        Self.e(0.27, 0.24, 0.46, 0.44),     // head        x[0.27..0.73] → mid 0.50
        Self.tri(0.28, 0.07, 0.19, 0.22),   // left ear    x mid 0.375
        Self.tri(0.53, 0.07, 0.19, 0.22),   // right ear   x mid 0.625
        Self.e(0.36, 0.44, 0.10, 0.10),     // left eye    x mid 0.41
        Self.e(0.54, 0.44, 0.10, 0.10),     // right eye   x mid 0.59
        Self.triDown(0.46, 0.55, 0.08, 0.07), // nose      x mid 0.50
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

    // A butterfly — 6 regions. Body on the centre line; each wing pair
    // symmetric about it and touching the body at x 0.47 / 0.53.
    static let butterfly: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // background
        Self.rect(0.47, 0.20, 0.06, 0.56),  // body        x mid 0.50
        Self.e(0.12, 0.16, 0.35, 0.30),     // top-left wing     x[0.12..0.47]
        Self.e(0.53, 0.16, 0.35, 0.30),     // top-right wing    x[0.53..0.88]
        Self.e(0.18, 0.46, 0.29, 0.26),     // bottom-left wing  x[0.18..0.47]
        Self.e(0.53, 0.46, 0.29, 0.26),     // bottom-right wing x[0.53..0.82]
    ]

    // A friendly robot — 8 regions, no antenna, centred on the canvas.
    static let robot: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.6),            // sky
        Self.rect(0, 0.58, 1, 0.42),        // ground
        Self.rect(0.30, 0.20, 0.40, 0.26),  // head
        Self.e(0.38, 0.28, 0.09, 0.09),     // left eye
        Self.e(0.53, 0.28, 0.09, 0.09),     // right eye
        Self.rect(0.26, 0.48, 0.48, 0.32),  // body
        Self.rect(0.10, 0.50, 0.14, 0.24),  // left arm
        Self.rect(0.76, 0.50, 0.14, 0.24),  // right arm
    ]

    // A fish — 6 regions.
    static let fish: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // water
        Self.e(0.14, 0.34, 0.50, 0.34),     // body
        Self.tri(0.58, 0.30, 0.24, 0.20),   // tail (upper)
        Self.triDown(0.58, 0.50, 0.24, 0.20), // tail (lower)
        Self.e(0.22, 0.42, 0.09, 0.09),     // eye
        Self.e(0.28, 0.60, 0.18, 0.10),     // belly fin
    ]

    // A shining sun — 6 regions.
    static let sun: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // sky
        Self.e(0.30, 0.30, 0.40, 0.40),     // core
        Self.tri(0.43, 0.03, 0.14, 0.16),   // top ray
        Self.triDown(0.43, 0.81, 0.14, 0.16), // bottom ray
        Self.tri(0.10, 0.12, 0.14, 0.14),   // upper-left ray
        Self.triDown(0.76, 0.74, 0.14, 0.14), // lower-right ray
    ]

    // A leafy tree — 6 regions.
    static let tree: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.72),           // sky
        Self.rect(0, 0.70, 1, 0.30),        // ground
        Self.rect(0.45, 0.42, 0.10, 0.34),  // trunk
        Self.e(0.24, 0.18, 0.52, 0.34),     // crown (top)
        Self.e(0.14, 0.32, 0.36, 0.28),     // crown (left)
        Self.e(0.50, 0.32, 0.36, 0.28),     // crown (right)
    ]

    // A floating balloon — 5 regions.
    static let balloon: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // sky
        Self.e(0.28, 0.10, 0.44, 0.50),     // balloon
        Self.triDown(0.44, 0.56, 0.12, 0.10), // knot
        Self.rect(0.49, 0.64, 0.02, 0.30),  // string
        Self.e(0.32, 0.20, 0.14, 0.16),     // highlight
    ]

    // A snowman — 7 regions.
    static let snowman: [ColorRegion] = [
        Self.rect(0, 0, 1, 0.62),           // sky
        Self.rect(0, 0.60, 1, 0.40),        // snow ground
        Self.e(0.30, 0.52, 0.40, 0.34),     // bottom ball
        Self.e(0.34, 0.30, 0.32, 0.28),     // middle ball
        Self.e(0.38, 0.12, 0.24, 0.22),     // head
        Self.e(0.43, 0.18, 0.05, 0.05),     // left eye
        Self.e(0.52, 0.18, 0.05, 0.05),     // right eye
    ]

    // A little ghost — 5 regions.
    static let ghost: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // background
        Self.e(0.24, 0.14, 0.52, 0.64),     // body
        Self.e(0.36, 0.30, 0.10, 0.13),     // left eye
        Self.e(0.54, 0.30, 0.10, 0.13),     // right eye
        Self.e(0.44, 0.48, 0.12, 0.10),     // mouth
    ]

    // A toadstool — 6 regions.
    static let mushroom: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // background
        Self.e(0.16, 0.16, 0.68, 0.42),     // cap
        Self.rect(0.38, 0.46, 0.24, 0.38),  // stem
        Self.e(0.28, 0.24, 0.13, 0.11),     // spot (left)
        Self.e(0.56, 0.30, 0.11, 0.09),     // spot (right)
        Self.e(0.44, 0.19, 0.09, 0.08),     // spot (top)
    ]

    // A crown — 7 regions.
    static let crown: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // background
        Self.rect(0.18, 0.52, 0.64, 0.22),  // band
        Self.tri(0.16, 0.28, 0.20, 0.28),   // left point
        Self.tri(0.40, 0.20, 0.20, 0.36),   // middle point
        Self.tri(0.64, 0.28, 0.20, 0.28),   // right point
        Self.e(0.29, 0.56, 0.09, 0.09),     // left jewel
        Self.e(0.62, 0.56, 0.09, 0.09),     // right jewel
    ]

    // An apple — 5 regions.
    static let apple: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // background
        Self.e(0.20, 0.28, 0.34, 0.50),     // left lobe
        Self.e(0.46, 0.28, 0.34, 0.50),     // right lobe
        Self.rect(0.48, 0.12, 0.04, 0.18),  // stem
        Self.e(0.52, 0.12, 0.18, 0.11),     // leaf
    ]

    // A ringed planet — 6 regions.
    static let planet: [ColorRegion] = [
        Self.rect(0, 0, 1, 1),              // space
        Self.e(0.08, 0.40, 0.84, 0.20),     // ring (behind)
        Self.e(0.28, 0.28, 0.44, 0.44),     // planet
        Self.e(0.36, 0.38, 0.12, 0.12),     // crater (left)
        Self.e(0.54, 0.50, 0.10, 0.10),     // crater (right)
        Self.e(0.14, 0.14, 0.06, 0.06),     // star
    ]
}
