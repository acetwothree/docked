//
//  ColorView.swift
//  Docked
//
//  "Color" — a colour-by-number. Each region has one right colour; pick that
//  number from the palette and tap the regions carrying it. Fill them all and
//  the picture pops with a little burst, then the next scene loads.
//

import SwiftUI
import UIKit

struct ColorView: View {
    @Environment(AppModel.self) private var app

    /// Numbered palette. Index 0 == number 1.
    private let palette: [Color] = [
        Color(hex: "7EC8E3"),  // 1 sky blue
        Color(hex: "7CB342"),  // 2 green
        Color(hex: "F4C430"),  // 3 yellow
        Color(hex: "E24A3B"),  // 4 red
        Color(hex: "EF8C3A"),  // 5 orange
        Color(hex: "96603E"),  // 6 brown
        Color(hex: "F1E4C9"),  // 7 cream
        Color(hex: "EC8FBE"),  // 8 pink
        Color(hex: "8E6FD6"),  // 9 purple
        Color(hex: "8B96A3"),  // 10 grey
        Color(hex: "35B0A7"),  // 11 teal
        Color(hex: "3B4149"),  // 12 dark
    ]

    @State private var picked = 1
    @State private var sheet = 0
    /// region index -> the number the player painted it with
    @State private var fills: [Int: Int] = [:]
    @State private var fillTick = 0
    @State private var wrongTick = 0
    @State private var doneTick = 0
    @State private var celebrating = false
    @State private var exportImage: Image?

    private var regions: [ColorRegion] { ColorSheets.all[sheet % ColorSheets.all.count] }
    private var correctCount: Int { regions.indices.filter { fills[$0] == regions[$0].n }.count }
    /// Palette numbers that actually appear in this scene, in ascending order.
    private var activeNumbers: [Int] { Array(Set(regions.map(\.n))).sorted() }
    private func remaining(_ n: Int) -> Int {
        regions.indices.filter { regions[$0].n == n && fills[$0] != n }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height) - 8
                artwork(side: s)
                    .frame(width: s, height: s)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 5)
                    .scaleEffect(celebrating ? 1.03 : 1)
                    .overlay { if celebrating { burst(side: s) } }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: fills) { _, _ in
                        refreshExport(side: 600)
                        if !celebrating, correctCount == regions.count { finishSheet() }
                    }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(activeNumbers, id: \.self) { n in
                        swatch(n)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 12)

            HStack(spacing: 14) {
                Button { fills = [:] } label: {
                    Label("Clear", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)

                Spacer(minLength: 16)

                Text("\(correctCount)/\(regions.count)")
                    .font(.system(size: 13, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(correctCount == regions.count ? Color.green : Color.secondary)

                Spacer(minLength: 16)

                if let exportImage {
                    ShareLink(item: exportImage, preview: SharePreview("Colouring", image: exportImage)) {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 15, weight: .heavy))
                    }
                }

                Button { advance() } label: {
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
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: celebrating)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: fillTick) { _, _ in app.haptics }
        .sensoryFeedback(.warning, trigger: wrongTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: doneTick) { _, _ in app.haptics }
        .onAppear {
            if !activeNumbers.contains(picked) { picked = activeNumbers.first ?? 1 }
            refreshExport(side: 600)
        }
    }

    private static let paper = Color(hex: "F2EEE1")
    private static let lineDark = Color(hex: "2B2620")

    /// A big, obvious palette key: number over its colour, a bold ring +
    /// lift when selected, faded with a tick once that colour's done.
    private func swatch(_ n: Int) -> some View {
        let left = remaining(n)
        let selected = picked == n
        let lightChip = n == 3 || n == 7          // yellow / cream need dark text
        return Button { withAnimation(.easeOut(duration: 0.15)) { picked = n } } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(palette[n - 1])
                        .frame(width: selected ? 46 : 40, height: selected ? 46 : 40)
                        .overlay(Circle().strokeBorder(selected ? Color.primary : Color.primary.opacity(0.15),
                                                       lineWidth: selected ? 3 : 1.5))
                        .shadow(color: .black.opacity(selected ? 0.28 : 0), radius: 4, y: 2)
                    if left == 0 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(lightChip ? Color.black.opacity(0.6) : Color.white)
                    } else {
                        Text("\(n)")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(lightChip ? Color.black.opacity(0.75) : Color.white)
                    }
                }
                .frame(height: 48)
                Text(left == 0 ? "done" : "\(left)")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
            .opacity(left == 0 ? 0.5 : 1)
        }
        .buttonStyle(.plain)
    }

    private func artwork(side: CGFloat) -> some View {
        ZStack {
            ForEach(regions.indices, id: \.self) { i in
                regionCell(i, side: side)
            }
        }
        .frame(width: side, height: side)
        .background(Self.paper)
    }

    @ViewBuilder
    private func regionCell(_ i: Int, side: CGFloat) -> some View {
        let region = regions[i]
        let done = fills[i] == region.n
        let fillColor: Color = done ? palette[region.n - 1] : Self.paper
        let w = region.rect.width * side
        let h = region.rect.height * side
        // Chip in a corner for big background regions so it doesn't sit
        // under the subject; centred for normal-size regions.
        let big = region.rect.width * region.rect.height > 0.3
        let chipAlign: Alignment = big ? .topLeading : .center

        region.shape
            .fill(fillColor)
            .overlay(region.shape.stroke(Color.white.opacity(0.55), lineWidth: 3.5))
            .overlay(region.shape.stroke(Self.lineDark.opacity(0.85), lineWidth: 1.6))
            .overlay(alignment: chipAlign) {
                if !done { numberChip(region.n).padding(big ? 8 : 0) }
            }
            .frame(width: w, height: h)
            .position(x: region.rect.midX * side, y: region.rect.midY * side)
            .onTapGesture { tap(i, region) }
    }

    /// A small fixed-size pill so numbers stay readable and never balloon
    /// over a neighbouring region.
    private func numberChip(_ n: Int) -> some View {
        Text("\(n)")
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Self.lineDark.opacity(0.75))
            .frame(width: 20, height: 20)
            .background(Color.white.opacity(0.82), in: Circle())
            .overlay(Circle().stroke(Self.lineDark.opacity(0.18), lineWidth: 1))
    }

    private func tap(_ i: Int, _ region: ColorRegion) {
        guard !celebrating else { return }
        if picked == region.n {
            withAnimation(.easeOut(duration: 0.15)) { fills[i] = region.n }
            fillTick += 1
        } else {
            wrongTick += 1
        }
    }

    private func finishSheet() {
        celebrating = true
        doneTick += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { advance() }
    }

    private func advance() {
        celebrating = false
        sheet += 1
        fills = [:]
        picked = (ColorSheets.all[sheet % ColorSheets.all.count].map(\.n).min()) ?? 1
    }

    /// A quick confetti-ish pop when a scene is completed.
    private func burst(side: CGFloat) -> some View {
        ZStack {
            ForEach(0..<14, id: \.self) { k in
                let a = Double(k) / 14 * 2 * .pi
                Circle()
                    .fill(palette[k % palette.count])
                    .frame(width: 10, height: 10)
                    .offset(x: CGFloat(cos(a)) * side * (celebrating ? 0.42 : 0.05),
                            y: CGFloat(sin(a)) * side * (celebrating ? 0.42 : 0.05))
                    .opacity(celebrating ? 0 : 1)
                    .animation(.easeOut(duration: 0.7).delay(0.02 * Double(k)), value: celebrating)
            }
        }
        .allowsHitTesting(false)
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
    var n: Int         // the correct palette number (1-based)
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
    static let all: [[ColorRegion]] = [
        house, flower, sailboat, cat, car, rocket, icecream, butterfly, robot,
        fish, sun, tree, balloon, snowman, ghost, mushroom, crown, apple, planet,
    ]

    private static func e(_ n: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(Ellipse()), rect: CGRect(x: x, y: y, width: w, height: h), n: n)
    }
    private static func rect(_ n: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(Rectangle()), rect: CGRect(x: x, y: y, width: w, height: h), n: n)
    }
    private static func tri(_ n: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(ColorTri()), rect: CGRect(x: x, y: y, width: w, height: h), n: n)
    }
    private static func triDown(_ n: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> ColorRegion {
        ColorRegion(shape: AnyShape(ColorTriDown()), rect: CGRect(x: x, y: y, width: w, height: h), n: n)
    }

    // 1 blue · 2 green · 3 yellow · 4 red · 5 orange · 6 brown · 7 cream
    // 8 pink · 9 purple · 10 grey · 11 teal · 12 dark

    static let house: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 0.62),
        Self.rect(2, 0, 0.60, 1, 0.40),
        Self.e(3, 0.70, 0.05, 0.20, 0.20),
        Self.tri(4, 0.15, 0.20, 0.70, 0.24),
        Self.rect(7, 0.22, 0.42, 0.56, 0.34),
        Self.rect(1, 0.30, 0.48, 0.13, 0.13),
        Self.rect(6, 0.45, 0.56, 0.16, 0.20),
    ]

    static let flower: [ColorRegion] = {
        var r: [ColorRegion] = [
            Self.rect(1, 0, 0, 1, 0.68),
            Self.rect(2, 0, 0.66, 1, 0.34),
            Self.rect(2, 0.47, 0.40, 0.06, 0.34),
            Self.e(2, 0.30, 0.50, 0.18, 0.11),
            Self.e(2, 0.52, 0.44, 0.18, 0.11),
        ]
        let cx: CGFloat = 0.5, cy: CGFloat = 0.30, ring: CGFloat = 0.16, pet: CGFloat = 0.17
        for k in 0..<5 {
            let a = Double(k) / 5 * 2 * .pi - .pi / 2
            r.append(Self.e(8, cx + CGFloat(cos(a)) * ring - pet / 2,
                            cy + CGFloat(sin(a)) * ring - pet / 2, pet, pet))
        }
        r.append(Self.e(3, cx - 0.09, cy - 0.09, 0.18, 0.18))
        return r
    }()

    static let sailboat: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 0.56),
        Self.e(3, 0.08, 0.06, 0.22, 0.22),
        Self.rect(11, 0, 0.56, 1, 0.44),
        Self.rect(6, 0.30, 0.56, 0.40, 0.10),
        Self.tri(7, 0.46, 0.28, 0.22, 0.30),
    ]

    static let cat: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 0.58),
        Self.rect(2, 0, 0.56, 1, 0.44),
        Self.e(5, 0.27, 0.24, 0.46, 0.44),
        Self.tri(5, 0.28, 0.07, 0.19, 0.22),
        Self.tri(5, 0.53, 0.07, 0.19, 0.22),
        Self.e(12, 0.36, 0.44, 0.10, 0.10),
        Self.e(12, 0.54, 0.44, 0.10, 0.10),
        Self.triDown(8, 0.46, 0.55, 0.08, 0.07),
    ]

    static let car: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 0.55),
        Self.rect(10, 0, 0.53, 1, 0.47),
        Self.rect(4, 0.10, 0.42, 0.80, 0.24),
        Self.rect(1, 0.30, 0.26, 0.40, 0.18),
        Self.e(12, 0.18, 0.60, 0.20, 0.20),
        Self.e(12, 0.62, 0.60, 0.20, 0.20),
    ]

    static let rocket: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 0.7),
        Self.rect(2, 0, 0.68, 1, 0.32),
        Self.rect(10, 0.36, 0.18, 0.28, 0.48),
        Self.tri(4, 0.32, 0.02, 0.36, 0.18),
        Self.tri(4, 0.16, 0.52, 0.22, 0.22),
        Self.tri(4, 0.62, 0.52, 0.22, 0.22),
        Self.e(1, 0.40, 0.30, 0.20, 0.20),
    ]

    static let icecream: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 1),
        Self.triDown(6, 0.36, 0.55, 0.28, 0.38),
        Self.e(7, 0.28, 0.32, 0.44, 0.30),
        Self.e(8, 0.32, 0.12, 0.36, 0.26),
        Self.e(4, 0.45, 0.05, 0.10, 0.10),
    ]

    static let butterfly: [ColorRegion] = [
        Self.rect(3, 0, 0, 1, 1),
        Self.rect(12, 0.47, 0.20, 0.06, 0.56),
        Self.e(9, 0.12, 0.16, 0.35, 0.30),
        Self.e(9, 0.53, 0.16, 0.35, 0.30),
        Self.e(8, 0.18, 0.46, 0.29, 0.26),
        Self.e(8, 0.53, 0.46, 0.29, 0.26),
    ]

    static let robot: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 0.6),
        Self.rect(2, 0, 0.58, 1, 0.42),
        Self.rect(10, 0.30, 0.20, 0.40, 0.26),
        Self.e(3, 0.38, 0.28, 0.09, 0.09),
        Self.e(3, 0.53, 0.28, 0.09, 0.09),
        Self.rect(10, 0.26, 0.48, 0.48, 0.32),
        Self.rect(10, 0.10, 0.50, 0.14, 0.24),
        Self.rect(10, 0.76, 0.50, 0.14, 0.24),
    ]

    static let fish: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 1),
        Self.e(5, 0.14, 0.34, 0.50, 0.34),
        Self.tri(5, 0.58, 0.30, 0.24, 0.20),
        Self.triDown(5, 0.58, 0.50, 0.24, 0.20),
        Self.e(12, 0.22, 0.42, 0.09, 0.09),
        Self.e(3, 0.28, 0.60, 0.18, 0.10),
    ]

    static let sun: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 1),
        Self.e(3, 0.30, 0.30, 0.40, 0.40),
        Self.tri(5, 0.43, 0.03, 0.14, 0.16),
        Self.triDown(5, 0.43, 0.81, 0.14, 0.16),
        Self.tri(5, 0.10, 0.12, 0.14, 0.14),
        Self.triDown(5, 0.76, 0.74, 0.14, 0.14),
    ]

    static let tree: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 0.72),
        Self.rect(2, 0, 0.70, 1, 0.30),
        Self.rect(6, 0.45, 0.42, 0.10, 0.34),
        Self.e(2, 0.24, 0.18, 0.52, 0.34),
        Self.e(2, 0.14, 0.32, 0.36, 0.28),
        Self.e(2, 0.50, 0.32, 0.36, 0.28),
    ]

    static let balloon: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 1),
        Self.e(4, 0.28, 0.10, 0.44, 0.50),
        Self.triDown(6, 0.44, 0.56, 0.12, 0.10),
        Self.rect(6, 0.49, 0.64, 0.02, 0.30),
        Self.e(7, 0.32, 0.20, 0.14, 0.16),
    ]

    static let snowman: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 0.62),
        Self.rect(7, 0, 0.60, 1, 0.40),
        Self.e(7, 0.30, 0.52, 0.40, 0.34),
        Self.e(7, 0.34, 0.30, 0.32, 0.28),
        Self.e(7, 0.38, 0.12, 0.24, 0.22),
        Self.e(12, 0.43, 0.18, 0.05, 0.05),
        Self.e(12, 0.52, 0.18, 0.05, 0.05),
    ]

    static let ghost: [ColorRegion] = [
        Self.rect(9, 0, 0, 1, 1),
        Self.e(7, 0.24, 0.14, 0.52, 0.64),
        Self.e(12, 0.36, 0.30, 0.10, 0.13),
        Self.e(12, 0.54, 0.30, 0.10, 0.13),
        Self.e(12, 0.44, 0.48, 0.12, 0.10),
    ]

    static let mushroom: [ColorRegion] = [
        Self.rect(2, 0, 0, 1, 1),
        Self.e(4, 0.16, 0.16, 0.68, 0.42),
        Self.rect(7, 0.38, 0.46, 0.24, 0.38),
        Self.e(7, 0.28, 0.24, 0.13, 0.11),
        Self.e(7, 0.56, 0.30, 0.11, 0.09),
        Self.e(7, 0.44, 0.19, 0.09, 0.08),
    ]

    static let crown: [ColorRegion] = [
        Self.rect(1, 0, 0, 1, 1),
        Self.rect(3, 0.18, 0.52, 0.64, 0.22),
        Self.tri(3, 0.16, 0.28, 0.20, 0.28),
        Self.tri(3, 0.40, 0.20, 0.20, 0.36),
        Self.tri(3, 0.64, 0.28, 0.20, 0.28),
        Self.e(4, 0.29, 0.56, 0.09, 0.09),
        Self.e(11, 0.62, 0.56, 0.09, 0.09),
    ]

    static let apple: [ColorRegion] = [
        Self.rect(7, 0, 0, 1, 1),
        Self.e(4, 0.20, 0.28, 0.34, 0.50),
        Self.e(4, 0.46, 0.28, 0.34, 0.50),
        Self.rect(6, 0.48, 0.12, 0.04, 0.18),
        Self.e(2, 0.52, 0.12, 0.18, 0.11),
    ]

    static let planet: [ColorRegion] = [
        Self.rect(12, 0, 0, 1, 1),
        Self.e(10, 0.08, 0.40, 0.84, 0.20),
        Self.e(9, 0.28, 0.28, 0.44, 0.44),
        Self.e(8, 0.36, 0.38, 0.12, 0.12),
        Self.e(8, 0.54, 0.50, 0.10, 0.10),
        Self.e(3, 0.14, 0.14, 0.06, 0.06),
    ]
}
