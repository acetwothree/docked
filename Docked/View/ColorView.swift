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
                let s = min(geo.size.width, geo.size.height)
                artwork(side: s)
                    .frame(width: s, height: s)
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

    private func artwork(side: CGFloat) -> some View {
        ZStack {
            ForEach(Array(regions.enumerated()), id: \.offset) { pair in
                pair.element.shape
                    .fill(fills[pair.offset] ?? Color.primary.opacity(0.05))
                    .overlay(pair.element.shape.stroke(Theme.ink.opacity(0.35), lineWidth: 1.5))
                    .frame(width: pair.element.rect.width * side, height: pair.element.rect.height * side)
                    .position(x: pair.element.rect.midX * side, y: pair.element.rect.midY * side)
                    .onTapGesture { fills[pair.offset] = picked; fillTick += 1 }
            }
        }
        .frame(width: side, height: side)
        .background(Color.white)
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
    static let all: [[ColorRegion]] = [garden, forest, sunset]

    private static func e(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(Ellipse()), rect: CGRect(x: x, y: y, width: w, height: h))
    }
    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(Rectangle()), rect: CGRect(x: x, y: y, width: w, height: h))
    }
    private static func tri(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(ColorTri()), rect: CGRect(x: x, y: y, width: w, height: h))
    }

    // A little garden: sky, ground, sun, two clouds, three flowers.
    static let garden: [ColorRegion] = {
        var r: [ColorRegion] = []
        r.append(Self.rect(0, 0, 1, 0.68))       // sky
        r.append(Self.rect(0, 0.66, 1, 0.34))    // ground
        r.append(Self.e(0.06, 0.05, 0.18, 0.18)) // sun
        r.append(Self.e(0.55, 0.08, 0.22, 0.10)) // cloud
        r.append(Self.e(0.72, 0.16, 0.20, 0.09)) // cloud
        let flowers: [(CGFloat, CGFloat, CGFloat)] = [(0.18, 0.42, 0.9), (0.46, 0.34, 1.05), (0.74, 0.44, 0.85)]
        for (fx, fy, size) in flowers {
            let pr: CGFloat = 0.07 * size
            r.append(Self.rect(fx + 0.005, fy + 0.10, 0.02, 0.24))         // stem
            r.append(Self.e(fx - 0.055, fy + 0.16, 0.13, 0.07))            // leaf
            for k in 0..<5 {
                let a = Double(k) / 5 * 2 * .pi
                r.append(Self.e(CGFloat(Double(fx) + cos(a) * 0.06) - pr,
                           CGFloat(Double(fy) + sin(a) * 0.06) - pr, pr * 2, pr * 2))
            }
            r.append(Self.e(fx - pr * 0.7, fy - pr * 0.7, pr * 1.4, pr * 1.4))  // centre
        }
        return r
    }()

    // A row of trees on a hill.
    static let forest: [ColorRegion] = {
        var r: [ColorRegion] = []
        r.append(Self.rect(0, 0, 1, 0.62))        // sky
        r.append(Self.e(-0.2, 0.5, 1.4, 0.9))     // hill
        r.append(Self.e(0.72, 0.05, 0.17, 0.17))  // sun
        for tx: CGFloat in [0.16, 0.42, 0.68] {
            r.append(Self.rect(tx - 0.03, 0.5, 0.06, 0.24))     // trunk
            r.append(Self.tri(tx - 0.13, 0.16, 0.26, 0.24))     // top
            r.append(Self.tri(tx - 0.15, 0.30, 0.30, 0.22))     // mid
            r.append(Self.tri(tx - 0.17, 0.42, 0.34, 0.20))     // bottom
        }
        return r
    }()

    // Sunset over water.
    static let sunset: [ColorRegion] = {
        var r: [ColorRegion] = []
        r.append(Self.rect(0, 0, 1, 0.22))
        r.append(Self.rect(0, 0.22, 1, 0.18))
        r.append(Self.rect(0, 0.40, 1, 0.14))
        r.append(Self.e(0.35, 0.34, 0.30, 0.30))   // sun
        r.append(Self.rect(0, 0.62, 1, 0.38))      // sea
        r.append(Self.tri(0.66, 0.66, 0.14, 0.10)) // sail
        r.append(Self.rect(0.63, 0.75, 0.12, 0.03))// boat
        r.append(Self.tri(0.12, 0.14, 0.08, 0.05)) // bird
        r.append(Self.tri(0.24, 0.10, 0.08, 0.05)) // bird
        return r
    }()
}
