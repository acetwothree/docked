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
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline))
            .opacity(locked ? 0.88 : 1)
            .overlay(alignment: .topTrailing) {
                Button(action: onToggleFav) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isFavorite ? Theme.accent : Color.secondary.opacity(0.5))
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
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(mod.title), Docked Plus" : mod.title)
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
        case .flow:    flow(s)
        case .merge:   merge(s)
        case .drop:    drop(s)
        case .marble:  maze(s)
        case .brawl:   brawl(s)
        case .spot:    spot(s)
        case .pop:     pop(s)
        case .click:   click(s)
        case .ksand:   sand(s)
        case .rings:   rings(s)
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
    }

    private func notes(_ s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: s * 0.1) {
            ForEach(Array([0.9, 0.65, 0.8, 0.45].enumerated()), id: \.offset) { _, w in
                Capsule().fill(Color.secondary.opacity(0.32)).frame(width: s * w, height: s * 0.07)
            }
        }
        .frame(width: s, height: s, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "pencil").font(.system(size: s * 0.24, weight: .bold))
                .foregroundStyle(Color(hex: "4A9CFF"))
        }
    }

    private func color(_ s: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(hex: "E0473E")).frame(width: s * 0.5).offset(x: -s * 0.18, y: -s * 0.08)
            Circle().fill(Color(hex: "F2B90C")).frame(width: s * 0.5).offset(x: s * 0.18, y: -s * 0.05)
            Circle().fill(Color(hex: "3ECF7A")).frame(width: s * 0.5).offset(x: 0, y: s * 0.22)
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: s * 0.26, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 2)
        }
    }

    private func blocks(_ s: CGFloat) -> some View {
        let n = 4
        let cell = s / CGFloat(n) - 3
        let filled: Set<Int> = [2, 5, 6, 9, 10]
        return VStack(spacing: 3) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<n, id: \.self) { c in
                        let on = filled.contains(r * n + c)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(on ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "8ECDF5"), Color(hex: "3EA1E0")],
                                                                    startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(Color.secondary.opacity(0.12)))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }

    private func flow(_ s: CGFloat) -> some View {
        ZStack {
            Path { p in p.move(to: CGPoint(x: s * 0.18, y: s * 0.22)); p.addLine(to: CGPoint(x: s * 0.18, y: s * 0.78)) }
                .stroke(Color(hex: "3ECF7A"), style: StrokeStyle(lineWidth: s * 0.09, lineCap: .round))
            Path { p in
                p.move(to: CGPoint(x: s * 0.55, y: s * 0.18))
                p.addLine(to: CGPoint(x: s * 0.86, y: s * 0.5))
                p.addLine(to: CGPoint(x: s * 0.55, y: s * 0.82))
            }
            .stroke(Color(hex: "F2B90C"), style: StrokeStyle(lineWidth: s * 0.09, lineCap: .round, lineJoin: .round))
            Circle().fill(Color(hex: "3ECF7A")).frame(width: s * 0.16).position(x: s * 0.18, y: s * 0.22)
            Circle().fill(Color(hex: "3ECF7A")).frame(width: s * 0.16).position(x: s * 0.18, y: s * 0.78)
            Circle().fill(Color(hex: "F2B90C")).frame(width: s * 0.16).position(x: s * 0.55, y: s * 0.18)
            Circle().fill(Color(hex: "F2B90C")).frame(width: s * 0.16).position(x: s * 0.55, y: s * 0.82)
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
            Circle().fill(Color.white)
                .frame(width: s * 0.2)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
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
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: "3ECF7A"))
                .frame(width: s * 0.3, height: s * 0.3)
        }
    }

    private func spot(_ s: CGFloat) -> some View {
        let dim: [(CGFloat, CGFloat)] = [(0.2, 0.25), (0.78, 0.22), (0.22, 0.78), (0.8, 0.72)]
        return ZStack {
            ForEach(Array(dim.enumerated()), id: \.offset) { _, pt in
                Circle().fill(Color.secondary.opacity(0.32)).frame(width: s * 0.22)
                    .position(x: pt.0 * s, y: pt.1 * s)
            }
            Circle().fill(Color(hex: "3ECF7A")).frame(width: s * 0.22).position(x: s * 0.5, y: s * 0.5)
            Circle().stroke(Color(hex: "3ECF7A"), lineWidth: s * 0.03).frame(width: s * 0.32)
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
                        Circle().fill(Color(hex: "C77DFF").opacity((r + c).isMultiple(of: 3) ? 0.25 : 0.55))
                            .frame(width: d, height: d)
                    }
                }
            }
        }
    }

    private func click(_ s: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(hex: "C77DFF").opacity(0.22)).frame(width: s * 0.8)
            Circle().fill(Color(hex: "C77DFF")).frame(width: s * 0.52)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            Text("+1").font(.system(size: s * 0.2, weight: .black)).foregroundStyle(.white)
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
                .stroke(Color(hex: "C77DFF").opacity(0.55), style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.9, height: s * 0.06)
            }
        }
    }

    private func rings(_ s: CGFloat) -> some View {
        VStack(spacing: s * 0.05) {
            Capsule().fill(Color(hex: "E0473E")).frame(width: s * 0.78, height: s * 0.16)
            Capsule().fill(Color(hex: "F2B90C")).frame(width: s * 0.56, height: s * 0.16)
            Capsule().fill(Color(hex: "3ECF7A")).frame(width: s * 0.34, height: s * 0.16)
        }
    }

    // MARK: shared pieces

    private func numberTile(_ text: String, _ color: Color, _ w: CGFloat, _ h: CGFloat) -> some View {
        Text(text).font(.system(size: h * 0.5, weight: .black)).foregroundStyle(.white)
            .frame(width: w, height: h)
            .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func numberCircle(_ text: String, _ color: Color, _ d: CGFloat) -> some View {
        Text(text).font(.system(size: d * 0.42, weight: .black)).foregroundStyle(.white)
            .frame(width: d, height: d)
            .background(color, in: Circle())
    }
}
