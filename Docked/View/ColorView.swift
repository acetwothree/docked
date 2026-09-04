//
//  ColorView.swift
//  Docked
//
//  "Color" — dead-simple colouring sheets. Pick a colour, tap a shape to fill
//  it. Tap Next for a fresh sheet. Nothing to get wrong.
//

import SwiftUI

struct ColorView: View {
    @Environment(AppModel.self) private var app

    private let palette: [Color] = [
        Color(hex: "E0473E"), Color(hex: "F2883C"), Color(hex: "F2B90C"),
        Color(hex: "3ECF7A"), Color(hex: "3EA1E0"), Color(hex: "8B5CF6"),
        Color(hex: "F25CA2"), Color(hex: "6B4A2E"), Color(hex: "1C1917"),
    ]

    @State private var picked: Color = Color(hex: "E0473E")
    @State private var sheet = 0
    @State private var fills: [Int: Color] = [:]
    @State private var fillTick = 0

    private var regions: [ColorRegion] { ColorSheets.all[sheet % ColorSheets.all.count] }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height)
                ZStack {
                    ForEach(Array(regions.enumerated()), id: \.offset) { pair in
                        pair.element.shape
                            .fill(fills[pair.offset] ?? Color.primary.opacity(0.06))
                            .overlay(pair.element.shape.stroke(Theme.ink.opacity(0.35), lineWidth: 1.5))
                            .frame(width: pair.element.rect.width * s, height: pair.element.rect.height * s)
                            .position(x: pair.element.rect.midX * s, y: pair.element.rect.midY * s)
                            .onTapGesture {
                                fills[pair.offset] = picked
                                fillTick += 1
                            }
                    }
                }
                .frame(width: s, height: s)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // swatches
            HStack(spacing: 7) {
                ForEach(Array(palette.enumerated()), id: \.offset) { pair in
                    Circle()
                        .fill(pair.element)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(.white.opacity(picked == pair.element ? 0.95 : 0.15), lineWidth: 2.5))
                        .onTapGesture { picked = pair.element }
                }
            }

            HStack {
                Button { fills = [:] } label: {
                    Label("Clear", systemImage: "arrow.counterclockwise").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button {
                    sheet += 1
                    fills = [:]
                } label: {
                    Label("Next sheet", systemImage: "arrow.right").font(.system(size: 14, weight: .heavy))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: fillTick) { _, _ in app.haptics }
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
    static let all: [[ColorRegion]] = [flower, house, rocket]

    static let flower: [ColorRegion] = {
        var r: [ColorRegion] = []
        // stem + leaves
        r.append(ColorRegion(shape: AnyShape(Capsule()), rect: CGRect(x: 0.47, y: 0.55, width: 0.06, height: 0.4)))
        r.append(ColorRegion(shape: AnyShape(Ellipse()), rect: CGRect(x: 0.30, y: 0.66, width: 0.20, height: 0.12)))
        r.append(ColorRegion(shape: AnyShape(Ellipse()), rect: CGRect(x: 0.50, y: 0.74, width: 0.20, height: 0.12)))
        // petals
        for k in 0..<6 {
            let a = Double(k) / 6 * 2 * .pi
            let cx = CGFloat(0.5 + cos(a) * 0.17)
            let cy = CGFloat(0.34 + sin(a) * 0.17)
            r.append(ColorRegion(shape: AnyShape(Ellipse()),
                                 rect: CGRect(x: cx - 0.10, y: cy - 0.10, width: 0.20, height: 0.20)))
        }
        // centre
        r.append(ColorRegion(shape: AnyShape(Circle()), rect: CGRect(x: 0.4, y: 0.24, width: 0.2, height: 0.2)))
        return r
    }()

    static let house: [ColorRegion] = [
        ColorRegion(shape: AnyShape(Rectangle()), rect: CGRect(x: 0.22, y: 0.42, width: 0.56, height: 0.44)),
        ColorRegion(shape: AnyShape(ColorTri()),  rect: CGRect(x: 0.16, y: 0.16, width: 0.68, height: 0.28)),
        ColorRegion(shape: AnyShape(Rectangle()), rect: CGRect(x: 0.44, y: 0.6, width: 0.14, height: 0.26)),
        ColorRegion(shape: AnyShape(Rectangle()), rect: CGRect(x: 0.28, y: 0.5, width: 0.12, height: 0.12)),
        ColorRegion(shape: AnyShape(Rectangle()), rect: CGRect(x: 0.6, y: 0.5, width: 0.12, height: 0.12)),
        ColorRegion(shape: AnyShape(Circle()),    rect: CGRect(x: 0.7, y: 0.08, width: 0.16, height: 0.16)),
    ]

    static let rocket: [ColorRegion] = [
        ColorRegion(shape: AnyShape(Capsule()),   rect: CGRect(x: 0.38, y: 0.24, width: 0.24, height: 0.5)),
        ColorRegion(shape: AnyShape(ColorTri()),  rect: CGRect(x: 0.38, y: 0.06, width: 0.24, height: 0.2)),
        ColorRegion(shape: AnyShape(ColorTri()),  rect: CGRect(x: 0.2, y: 0.56, width: 0.2, height: 0.22)),
        ColorRegion(shape: AnyShape(ColorTri()),  rect: CGRect(x: 0.6, y: 0.56, width: 0.2, height: 0.22)),
        ColorRegion(shape: AnyShape(Circle()),    rect: CGRect(x: 0.44, y: 0.34, width: 0.12, height: 0.12)),
        ColorRegion(shape: AnyShape(ColorTri()),  rect: CGRect(x: 0.4, y: 0.72, width: 0.2, height: 0.22)),
    ]
}
