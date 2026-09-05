//
//  GameGridView.swift
//  Docked
//
//  The home screen: a two-column, vertically scrolling grid of every game,
//  each card showing a little illustration of what its gameplay looks like.
//  Tapping a card opens the game; RootView draws the back arrow that returns
//  here. This fills all of the screen below the TV cabinet.
//

import SwiftUI

struct GameGridView: View {
    var hasPlus: Bool
    var favorites: [ActivityModule]
    var onPick: (ActivityModule) -> Void
    var onToggleFav: (ActivityModule) -> Void

    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(ActivityModule.allCases) { mod in
                    GameCard(
                        mod: mod,
                        isFavorite: favorites.contains(mod),
                        locked: mod.isPlus && !hasPlus,
                        onTap: { onPick(mod) },
                        onToggleFav: { onToggleFav(mod) }
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
    }
}

private struct GameCard: View {
    let mod: ActivityModule
    let isFavorite: Bool
    let locked: Bool
    let onTap: () -> Void
    let onToggleFav: () -> Void

    // A fixed dark "poster" background regardless of app theme — like the
    // reference game hub, punchy gradient illustrations need a moody card to
    // pop against, and a card that changed brightness with the theme made the
    // colours read muddier in light mode.
    private static let cardTop = Color(hex: "23262F")
    private static let cardBottom = Color(hex: "15171D")

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mod.title.uppercased())
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(mod.tint)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Capsule().fill(mod.tint).frame(width: 26, height: 3)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                GamePreview(mod: mod)
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 152)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Self.cardTop, Self.cardBottom], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.06)))
            .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
            .opacity(locked ? 0.9 : 1)
            .overlay(alignment: .topTrailing) {
                Button(action: onToggleFav) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isFavorite ? Theme.accent : Color.white.opacity(0.35))
                        .padding(10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .overlay(alignment: .bottomTrailing) {
                if locked {
                    Label("PLUS", systemImage: "lock.fill")
                        .font(.system(size: 9, weight: .black)).tracking(0.5)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(8)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(mod.title), Docked Plus" : mod.title)
    }
}

// MARK: - Shared glossy pieces

/// A gradient-filled, top-lit block — used everywhere a preview needs a
/// "physical" square or tile instead of a flat colour swatch.
private struct PopBlock: View {
    let colors: [Color]
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat = 6

    init(_ color: Color, width: CGFloat, height: CGFloat, corner: CGFloat = 6) {
        self.colors = [color.opacity(1), color.opacity(0.72)]
        self.width = width
        self.height = height
        self.corner = corner
    }

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) {
                Capsule().fill(.white.opacity(0.4))
                    .frame(width: max(0, width - corner * 1.4), height: max(1.2, height * 0.1))
                    .padding(.top, height * 0.08)
            }
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 0.75))
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1.5)
    }
}

/// Same idea, capsule-shaped (the ring stack, mostly).
private struct PopCapsule: View {
    let color: Color
    var width: CGFloat
    var height: CGFloat
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) {
                Capsule().fill(.white.opacity(0.4)).frame(width: width * 0.6, height: max(1.2, height * 0.22))
                    .padding(.top, height * 0.12)
            }
            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.75))
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1.5)
    }
}

/// A glossy little sphere — a highlight near the top-left and a grounding
/// shadow, so dots and balls read as objects instead of flat circles.
private struct PopSphere: View {
    let color: Color
    var size: CGFloat
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.92), color],
                                 center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: size * 0.75))
            .overlay(
                Circle().fill(RadialGradient(colors: [.white.opacity(0.65), .clear],
                                             center: UnitPoint(x: 0.3, y: 0.24), startRadius: 0, endRadius: size * 0.32))
            )
            .overlay(Circle().stroke(.black.opacity(0.12), lineWidth: 1))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1.5)
    }
}

/// A small illustration hinting at each game's play, drawn with plain shapes
/// so it costs nothing to ship (no image assets).
private struct GamePreview: View {
    let mod: ActivityModule

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            content(s)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder private func content(_ s: CGFloat) -> some View {
        switch mod {
        case .doodle:  doodle(s)
        case .notes:   notes(s)
        case .color:   color(s)
        case .zen:     blocks(s)
        case .merge:   merge(s)
        case .drop:    drop(s)
        case .marble:  maze(s)
        case .brawl:   brawl(s)
        case .spot:    spot(s)
        case .pop:     pop(s)
        case .click:   click(s)
        case .ksand:   sand(s)
        case .rings:   rings(s)
        case .sandfall: sandfall(s)
        }
    }

    private func doodle(_ s: CGFloat) -> some View {
        Path { p in
            let pts: [(CGFloat, CGFloat)] = [(0.08, 0.75), (0.28, 0.25), (0.42, 0.7), (0.58, 0.2), (0.74, 0.68), (0.92, 0.35)]
            for (i, pt) in pts.enumerated() {
                let cg = CGPoint(x: pt.0 * s, y: pt.1 * s)
                if i == 0 { p.move(to: cg) } else { p.addLine(to: cg) }
            }
        }
        .stroke(Color(hex: "4A9CFF"), style: StrokeStyle(lineWidth: max(3, s * 0.045), lineCap: .round, lineJoin: .round))
        .shadow(color: Color(hex: "4A9CFF").opacity(0.5), radius: 4)
    }

    private func notes(_ s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: s * 0.1) {
            ForEach(Array([0.9, 0.65, 0.8, 0.45].enumerated()), id: \.offset) { _, w in
                Capsule().fill(Color.white.opacity(0.28)).frame(width: s * w, height: s * 0.07)
            }
        }
        .frame(width: s, height: s, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "pencil").font(.system(size: s * 0.24, weight: .bold))
                .foregroundStyle(Color(hex: "4A9CFF"))
                .shadow(color: Color(hex: "4A9CFF").opacity(0.6), radius: 4)
        }
    }

    private func color(_ s: CGFloat) -> some View {
        ZStack {
            PopSphere(color: Color(hex: "E0473E"), size: s * 0.5).offset(x: -s * 0.18, y: -s * 0.08)
            PopSphere(color: Color(hex: "F2B90C"), size: s * 0.5).offset(x: s * 0.18, y: -s * 0.05)
            PopSphere(color: Color(hex: "3ECF7A"), size: s * 0.5).offset(x: 0, y: s * 0.22)
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: s * 0.26, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
        }
    }

    private func blocks(_ s: CGFloat) -> some View {
        let n = 4
        let cell = s / CGFloat(n) - 3
        let filled: [Int: Color] = [2: Color(hex: "3EA1E0"), 5: Color(hex: "3EA1E0"), 6: Color(hex: "F25CA2"),
                                    9: Color(hex: "F25CA2"), 10: Color(hex: "F2B90C")]
        return VStack(spacing: 3) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<n, id: \.self) { c in
                        if let color = filled[r * n + c] {
                            PopBlock(color, width: cell, height: cell, corner: 4)
                        } else {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
    }

    private func merge(_ s: CGFloat) -> some View {
        VStack(spacing: s * 0.06) {
            numberTile("4", Color(hex: "8B5CF6"), s * 0.5, s * 0.4)
            HStack(spacing: s * 0.05) {
                numberTile("32", Color(hex: "3EA1E0"), s * 0.34, s * 0.28)
                numberTile("2", Color(hex: "F25CA2"), s * 0.34, s * 0.28)
                numberTile("8", Color(hex: "F2B90C"), s * 0.34, s * 0.28)
            }
        }
    }

    private func drop(_ s: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: s * 0.08) {
            VStack(spacing: s * 0.05) {
                numberCircle("2", Color(hex: "3ECF7A"), s * 0.32)
                numberCircle("4", Color(hex: "3EA1E0"), s * 0.32)
            }
            numberCircle("8", Color(hex: "F2883C"), s * 0.4)
        }
    }

    private func maze(_ s: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: s * 0.16, y: s * 0.2))
                p.addLine(to: CGPoint(x: s * 0.16, y: s * 0.55))
                p.addLine(to: CGPoint(x: s * 0.56, y: s * 0.55))
                p.addLine(to: CGPoint(x: s * 0.56, y: s * 0.2))
                p.addLine(to: CGPoint(x: s * 0.86, y: s * 0.2))
                p.addLine(to: CGPoint(x: s * 0.86, y: s * 0.82))
                p.addLine(to: CGPoint(x: s * 0.36, y: s * 0.82))
            }
            .stroke(Color(hex: "E0473E"), style: StrokeStyle(lineWidth: s * 0.13, lineCap: .round, lineJoin: .round))
            .shadow(color: Color(hex: "E0473E").opacity(0.5), radius: 3)
            PopSphere(color: Color(hex: "E8EBF2"), size: s * 0.2)
                .position(x: s * 0.16, y: s * 0.2)
        }
    }

    private func brawl(_ s: CGFloat) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule().fill(Color(hex: "3ECF7A").opacity(0.5))
                    .frame(width: s * 0.06, height: s * 0.26)
                    .offset(y: -s * 0.32)
                    .rotationEffect(.degrees(Double(i) / 8 * 360))
            }
            PopBlock(Color(hex: "3ECF7A"), width: s * 0.3, height: s * 0.3)
        }
    }

    private func spot(_ s: CGFloat) -> some View {
        let dim: [(CGFloat, CGFloat)] = [(0.2, 0.25), (0.78, 0.22), (0.22, 0.78), (0.8, 0.72)]
        return ZStack {
            ForEach(Array(dim.enumerated()), id: \.offset) { _, pt in
                PopSphere(color: Color(hex: "6B7280"), size: s * 0.22).position(x: pt.0 * s, y: pt.1 * s)
            }
            PopSphere(color: Color(hex: "3ECF7A"), size: s * 0.24)
                .overlay {
                    HStack(spacing: s * 0.05) {
                        Circle().fill(.black.opacity(0.7)).frame(width: s * 0.03)
                        Circle().fill(.black.opacity(0.7)).frame(width: s * 0.03)
                    }
                    .offset(y: -s * 0.02)
                }
                .position(x: s * 0.5, y: s * 0.5)
            Circle().stroke(Color(hex: "3ECF7A"), lineWidth: s * 0.03).frame(width: s * 0.34)
                .position(x: s * 0.5, y: s * 0.5)
        }
    }

    private func pop(_ s: CGFloat) -> some View {
        let n = 4
        let d = s / CGFloat(n) - 4
        return VStack(spacing: 4) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<n, id: \.self) { c in
                        PopSphere(color: Color(hex: "C77DFF").opacity((r + c).isMultiple(of: 3) ? 0.55 : 0.9), size: d)
                    }
                }
            }
        }
    }

    private func click(_ s: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(hex: "C77DFF").opacity(0.2)).frame(width: s * 0.85)
            PopSphere(color: Color(hex: "C77DFF"), size: s * 0.55)
            Text("+1").font(.system(size: s * 0.2, weight: .black)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 1)
        }
    }

    private func sand(_ s: CGFloat) -> some View {
        VStack(spacing: s * 0.14) {
            ForEach(0..<4, id: \.self) { i in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addCurve(to: CGPoint(x: s * 0.9, y: 0),
                              control1: CGPoint(x: s * 0.3, y: i.isMultiple(of: 2) ? -s * 0.1 : s * 0.1),
                              control2: CGPoint(x: s * 0.6, y: i.isMultiple(of: 2) ? s * 0.1 : -s * 0.1))
                }
                .stroke(Color(hex: "C77DFF").opacity(0.6), style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.9, height: s * 0.06)
            }
        }
    }

    private func rings(_ s: CGFloat) -> some View {
        VStack(spacing: s * 0.05) {
            PopCapsule(color: Color(hex: "E0473E"), width: s * 0.78, height: s * 0.16)
            PopCapsule(color: Color(hex: "F2B90C"), width: s * 0.56, height: s * 0.16)
            PopCapsule(color: Color(hex: "3ECF7A"), width: s * 0.34, height: s * 0.16)
        }
    }

    private func sandfall(_ s: CGFloat) -> some View {
        VStack(spacing: s * 0.1) {
            HStack(spacing: 2) {
                PopBlock(Color(hex: "F2B90C"), width: s * 0.16, height: s * 0.16, corner: 3)
                PopBlock(Color(hex: "F2B90C"), width: s * 0.16, height: s * 0.16, corner: 3)
            }
            .offset(x: -s * 0.15)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach(Array(sandColors.enumerated()), id: \.offset) { _, c in
                    PopBlock(c, width: s * 0.14, height: s * 0.14, corner: 3)
                }
            }
        }
        .frame(width: s, height: s)
    }

    private var sandColors: [Color] {
        [Color(hex: "E0473E"), Color(hex: "F2883C"), Color(hex: "F2B90C"),
         Color(hex: "3ECF7A"), Color(hex: "3EA1E0"), Color(hex: "8B5CF6")]
    }

    // MARK: shared pieces

    private func numberTile(_ text: String, _ color: Color, _ w: CGFloat, _ h: CGFloat) -> some View {
        PopBlock(color, width: w, height: h)
            .overlay {
                Text(text).font(.system(size: h * 0.5, weight: .black)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
    }

    private func numberCircle(_ text: String, _ color: Color, _ d: CGFloat) -> some View {
        PopSphere(color: color, size: d)
            .overlay {
                Text(text).font(.system(size: d * 0.42, weight: .black)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
    }
}
