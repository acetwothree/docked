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
import StoreKit

struct GameGridView: View {
    var hasPlus: Bool
    var favorites: [ActivityModule]
    var onPick: (ActivityModule) -> Void
    var onToggleFav: (ActivityModule) -> Void

    @Environment(\.requestReview) private var requestReview

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

            moreCard
                .padding(.horizontal, 2)
                .padding(.top, 4)
                .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
    }

    private var moreCard: some View {
        VStack(spacing: 10) {
            Text("More activities coming soon")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.secondary)
            Button { requestReview() } label: {
                Label("Enjoying Docked? Leave a review", systemImage: "star.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline))
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
//
// `shadow` defaults to true for a single hero instance; pass false when many
// copies tile a grid (Color Blocks cells, bubble wrap, the sand pile) — each
// `.shadow()` is its own offscreen render pass, and dozens of them stacked up
// is what made the grid (and the TV stretch, which resizes this whole screen)
// feel laggy.

private struct PopBlock: View {
    let colors: [Color]
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat = 6
    var shadow: Bool = true

    init(_ color: Color, width: CGFloat, height: CGFloat, corner: CGFloat = 6, shadow: Bool = true) {
        self.colors = [color.opacity(1), color.opacity(0.72)]
        self.width = width
        self.height = height
        self.corner = corner
        self.shadow = shadow
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
            .shadow(color: .black.opacity(shadow ? 0.35 : 0), radius: shadow ? 2 : 0, y: shadow ? 1.5 : 0)
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
    var shadow: Bool = true
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
            .shadow(color: .black.opacity(shadow ? 0.35 : 0), radius: shadow ? 2 : 0, y: shadow ? 1.5 : 0)
    }
}

/// A small illustration hinting at each game's play, drawn with plain shapes
/// so it costs nothing to ship (no image assets). Flattened with
/// `.drawingGroup()` — one rasterized layer per card instead of a dozen+
/// separately-composited gradient/shadow shapes — so the grid scrolls and the
/// TV stretch resizes smoothly even with many cards on screen.
private struct GamePreview: View {
    let mod: ActivityModule

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            content(s)
                // Every icon positions its shapes with `.position(x: frac*s, …)`
                // assuming an s×s box with its own origin — without pinning that
                // box's frame explicitly here, the ZStack's *actual* content
                // bounds (the union of the shapes, not a full s×s square) is what
                // gets centered next, which silently drags off-center compositions
                // that aren't symmetric. Fixing the frame to s×s first, THEN
                // centering that in the card, is what actually centers them.
                .frame(width: s, height: s)
                .frame(width: geo.size.width, height: geo.size.height)
                .compositingGroup()
                .drawingGroup()
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
        case .crumble: sandfall(s)
        case .hexfall: hexfall(s)
        case .blocktower: blocktower(s)
        }
    }

    /// A little scribble spiral — reads as an actual doodle, and it's
    /// centred by construction (built around the box's own centre).
    private func doodle(_ s: CGFloat) -> some View {
        Path { p in
            let turns = 2.3
            let steps = 48
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let angle = Double(t) * turns * 2 * .pi
                let r = t * 0.38
                let cg = CGPoint(x: (0.5 + r * CGFloat(cos(angle))) * s,
                                 y: (0.5 + r * CGFloat(sin(angle))) * s)
                if i == 0 { p.move(to: cg) } else { p.addLine(to: cg) }
            }
        }
        .stroke(Color(hex: "4A9CFF"), style: StrokeStyle(lineWidth: max(3, s * 0.045), lineCap: .round, lineJoin: .round))
        .shadow(color: Color(hex: "4A9CFF").opacity(0.5), radius: 4)
    }

    private func notes(_ s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: s * 0.12) {
            ForEach(Array([0.86, 0.64, 0.76].enumerated()), id: \.offset) { _, w in
                Capsule().fill(Color.white.opacity(0.3)).frame(width: s * w, height: s * 0.09)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "pencil").font(.system(size: s * 0.3, weight: .bold))
                .foregroundStyle(Color(hex: "4A9CFF"))
                .shadow(color: Color(hex: "4A9CFF").opacity(0.6), radius: 4)
                .offset(x: s * 0.2, y: s * 0.26)
        }
    }

    private func color(_ s: CGFloat) -> some View {
        ZStack {
            PopSphere(color: Color(hex: "E0473E"), size: s * 0.48).offset(x: -s * 0.17, y: -s * 0.14)
            PopSphere(color: Color(hex: "F2B90C"), size: s * 0.48).offset(x: s * 0.17, y: -s * 0.14)
            PopSphere(color: Color(hex: "3ECF7A"), size: s * 0.48).offset(x: 0, y: s * 0.14)
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: s * 0.24, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
        }
    }

    /// Real tetromino-shaped groups tiling part of the grid, like an
    /// in-progress board — not scattered single squares.
    private func blocks(_ s: CGFloat) -> some View {
        let n = 4
        let cell = s / CGFloat(n) - 3
        let square = Color(hex: "3EA1E0")
        let lShape = Color(hex: "F25CA2")
        let line = Color(hex: "F2B90C")
        let filled: [Int: Color] = [
            0: square, 1: square, 4: square, 5: square,       // 2×2 block
            2: lShape, 3: lShape, 7: lShape,                  // L piece
            8: line, 9: line, 10: line,                       // I piece
        ]
        return VStack(spacing: 3) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<n, id: \.self) { c in
                        if let color = filled[r * n + c] {
                            PopBlock(color, width: cell, height: cell, corner: 4, shadow: false)
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
        VStack(spacing: s * 0.05) {
            numberTile("2", Color(hex: "3ECF7A"), s * 0.38, s * 0.27)
            HStack(spacing: s * 0.05) {
                numberTile("4", Color(hex: "3EA1E0"), s * 0.38, s * 0.27)
                numberTile("8", Color(hex: "8B5CF6"), s * 0.38, s * 0.27)
            }
            numberTile("16", Color(hex: "F25CA2"), s * 0.5, s * 0.27)
        }
    }

    private func drop(_ s: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: s * 0.06) {
            numberCircle("2", Color(hex: "3ECF7A"), s * 0.3)
            numberCircle("4", Color(hex: "3EA1E0"), s * 0.36)
            numberCircle("8", Color(hex: "F2883C"), s * 0.3)
        }
    }

    /// A diamond loop, centred by construction, with the ball at the top
    /// vertex — reads as a painted path without any directional bias.
    private func maze(_ s: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: s * 0.5, y: s * 0.16))
                p.addLine(to: CGPoint(x: s * 0.16, y: s * 0.5))
                p.addLine(to: CGPoint(x: s * 0.5, y: s * 0.84))
                p.addLine(to: CGPoint(x: s * 0.84, y: s * 0.5))
                p.closeSubpath()
            }
            .stroke(Color(hex: "E0473E"), style: StrokeStyle(lineWidth: s * 0.12, lineCap: .round, lineJoin: .round))
            .shadow(color: Color(hex: "E0473E").opacity(0.5), radius: 3)
            PopSphere(color: Color(hex: "E8EBF2"), size: s * 0.2)
                .position(x: s * 0.5, y: s * 0.16)
        }
    }

    private func brawl(_ s: CGFloat) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * 2 * .pi
                Capsule().fill(Color(hex: "3ECF7A").opacity(0.5))
                    .frame(width: s * 0.06, height: s * 0.22)
                    .rotationEffect(.degrees(Double(i) / 8 * 360))
                    .position(x: s * 0.5 + CGFloat(sin(a)) * s * 0.36,
                             y: s * 0.5 - CGFloat(cos(a)) * s * 0.36)
            }
            PopBlock(Color(hex: "3ECF7A"), width: s * 0.3, height: s * 0.3)
                .position(x: s * 0.5, y: s * 0.5)
        }
    }

    /// Same simple "creature" silhouette repeated so it's obvious what game
    /// this is — a circle body with two eyes — with one picked out by colour
    /// and a ring, the way the real game asks you to spot it.
    private func spot(_ s: CGFloat) -> some View {
        let dim: [(CGFloat, CGFloat)] = [(0.24, 0.28), (0.76, 0.28), (0.24, 0.76)]
        return ZStack {
            ForEach(Array(dim.enumerated()), id: \.offset) { _, pt in
                creature(Color(hex: "6B7280"), s: s * 0.3).position(x: pt.0 * s, y: pt.1 * s)
            }
            creature(Color(hex: "3ECF7A"), s: s * 0.34).position(x: s * 0.76, y: s * 0.76)
            Circle().stroke(Color(hex: "3ECF7A"), lineWidth: s * 0.025).frame(width: s * 0.46)
                .position(x: s * 0.76, y: s * 0.76)
        }
    }

    private func creature(_ color: Color, s: CGFloat) -> some View {
        PopSphere(color: color, size: s, shadow: false)
            .overlay {
                HStack(spacing: s * 0.22) {
                    Circle().fill(.black.opacity(0.75)).frame(width: s * 0.13)
                    Circle().fill(.black.opacity(0.75)).frame(width: s * 0.13)
                }
                .offset(y: -s * 0.02)
            }
    }

    /// A tight, uniform grid of small glossy bubbles — bubble wrap, not a
    /// scattered polka-dot pattern.
    private func pop(_ s: CGFloat) -> some View {
        let n = 5
        let d = s / CGFloat(n) - 2.5
        return VStack(spacing: 2.5) {
            ForEach(0..<n, id: \.self) { _ in
                HStack(spacing: 2.5) {
                    ForEach(0..<n, id: \.self) { _ in
                        Circle()
                            .fill(RadialGradient(colors: [.white.opacity(0.5), Color(hex: "C77DFF").opacity(0.35)],
                                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: d * 0.7))
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 0.75))
                            .frame(width: d, height: d)
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

    /// A dark wooden tray holding pale sand with raked grooves — high
    /// contrast so it actually reads as sand, not a flat purple pattern.
    private func sand(_ s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: "4A3826"))
                .frame(width: s * 0.94, height: s * 0.94)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "E8CFA0"), Color(hex: "D2AE72")],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.8, height: s * 0.8)
            VStack(spacing: s * 0.12) {
                ForEach(0..<4, id: \.self) { i in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addCurve(to: CGPoint(x: s * 0.64, y: 0),
                                  control1: CGPoint(x: s * 0.21, y: i.isMultiple(of: 2) ? -s * 0.08 : s * 0.08),
                                  control2: CGPoint(x: s * 0.43, y: i.isMultiple(of: 2) ? s * 0.08 : -s * 0.08))
                    }
                    .stroke(Color(hex: "9C7A46").opacity(0.8), style: StrokeStyle(lineWidth: s * 0.03, lineCap: .round))
                    .frame(width: s * 0.64, height: s * 0.05)
                }
            }
        }
    }

    /// A peg with rings actually stacked around it, big on the bottom —
    /// the classic tower puzzle, not three free-floating bars.
    private func rings(_ s: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.25))
                .frame(width: s * 0.05, height: s * 0.66)
            VStack(spacing: s * 0.04) {
                PopCapsule(color: Color(hex: "E0473E"), width: s * 0.7, height: s * 0.15)
                PopCapsule(color: Color(hex: "F2B90C"), width: s * 0.5, height: s * 0.15)
                PopCapsule(color: Color(hex: "3ECF7A"), width: s * 0.3, height: s * 0.15)
            }
        }
    }

    /// A falling piece above a mounded pile of colourful sand — not a flat row.
    private func sandfall(_ s: CGFloat) -> some View {
        VStack(spacing: s * 0.1) {
            HStack(spacing: 2) {
                PopBlock(Color(hex: "3EA1E0"), width: s * 0.16, height: s * 0.16, corner: 3)
                PopBlock(Color(hex: "3EA1E0"), width: s * 0.16, height: s * 0.16, corner: 3)
            }
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                pileRow(count: 2, size: s * 0.13)
                pileRow(count: 4, size: s * 0.13)
                pileRow(count: 6, size: s * 0.13)
            }
        }
        .frame(width: s, height: s)
    }

    private func pileRow(count: Int, size: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { i in
                PopBlock(sandColors[i % sandColors.count], width: size, height: size, corner: 2, shadow: false)
            }
        }
    }

    /// A hexagon balanced on a slightly toppled little tower — tap-to-clear.
    private func hexfall(_ s: CGFloat) -> some View {
        VStack(spacing: 1) {
            Polygon(sides: 6)
                .fill(Color(hex: "3EA1E0"))
                .overlay(Polygon(sides: 6).stroke(.white.opacity(0.3), lineWidth: 1.5))
                .frame(width: s * 0.36, height: s * 0.32)
                .rotationEffect(.degrees(6))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1.5)
            PopBlock(Color(hex: "F2B90C"), width: s * 0.4, height: s * 0.14, corner: 3, shadow: false)
                .rotationEffect(.degrees(6)).offset(x: s * 0.03)
            PopBlock(Color(hex: "E0473E"), width: s * 0.4, height: s * 0.14, corner: 3, shadow: false)
                .offset(x: -s * 0.05)
            PopBlock(Color(hex: "8B5CF6"), width: s * 0.44, height: s * 0.14, corner: 3, shadow: false)
        }
    }

    /// A taller, straight stack — the "keep it balanced" stacking game.
    private func blocktower(_ s: CGFloat) -> some View {
        VStack(spacing: 2) {
            PopBlock(Color(hex: "3ECF7A"), width: s * 0.26, height: s * 0.15, corner: 3, shadow: false)
            PopBlock(Color(hex: "3EA1E0"), width: s * 0.34, height: s * 0.15, corner: 3, shadow: false)
                .offset(x: s * 0.04)
            PopBlock(Color(hex: "F2B90C"), width: s * 0.4, height: s * 0.15, corner: 3, shadow: false)
                .offset(x: -s * 0.03)
            PopBlock(Color(hex: "F25CA2"), width: s * 0.46, height: s * 0.15, corner: 3, shadow: false)
            PopBlock(Color(hex: "8B5CF6"), width: s * 0.52, height: s * 0.15, corner: 3, shadow: false)
        }
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
