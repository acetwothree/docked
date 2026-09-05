//
//  MarbleView.swift
//  Docked
//
//  "Maze Paint" — swipe and the marble slides until it hits a wall or the
//  edge. Paint every open tile to clear the level. Levels are random mazes (a
//  recursive-backtracker carve), so the corridors twist differently every
//  time and the marble stops at every junction — which means a full sweep is
//  always possible. Grid size grows with the level. Level persists.
//

import SwiftUI

struct MarbleView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.marble.level") private var level: Int = 1

    @State private var cols = 5
    @State private var rows = 5
    @State private var walls: Set<Int> = []
    @State private var openCells: Set<Int> = []
    @State private var visited: Set<Int> = []
    /// Order cells were painted, oldest first — the trailing ember dots fade
    /// out the further back they are from the marble.
    @State private var visitOrder: [Int] = []
    @State private var pos = 0
    @State private var cleared = false
    @State private var loaded = false
    @State private var moveTick = 0
    @State private var hitTick = 0
    @State private var winTick = 0

    private static let boardBG = Color(hex: "12141C")
    private static let tileLight = Color(hex: "8CA3D6")
    private static let tileDark = Color(hex: "5E6FA0")
    private static let wallTop = Color(hex: "23262F")
    private static let wallSide = Color(hex: "0B0C11")
    private static let trailRed = Color(hex: "D93A3A")

    private var difficulty: String {
        switch level {
        case ..<8: "EASY"
        case 8..<16: "MEDIUM"
        case 16..<26: "HARD"
        default: "EXTRA HARD"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button { load(level) } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                VStack(spacing: 3) {
                    Text(difficulty)
                        .font(.system(size: 10, weight: .black)).tracking(1.4)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                    Text("Level \(level)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                }

                Spacer(minLength: 0)

                Text("\(visited.count)/\(openCells.count)")
                    .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(cleared ? Color.green : Color.secondary)
                    .frame(width: 30)
            }

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                board(side: side)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(cleared ? "Cleared!" : "Swipe to roll · paint every tile")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(cleared ? Color.green : Color.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 14)
                .onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if abs(dx) > abs(dy) { roll(dx > 0 ? 1 : -1, 0) }
                    else { roll(0, dy > 0 ? 1 : -1) }
                }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: hitTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: winTick) { _, _ in app.haptics }
        .onAppear { if !loaded { load(level); loaded = true } }
    }

    private func board(side: CGFloat) -> some View {
        let span = CGFloat(max(cols, rows))
        let gap: CGFloat = 4
        let cell = (side - gap * (span + 1)) / span
        let count = cols * rows
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Self.boardBG)
            ForEach(Array(0..<count), id: \.self) { i in
                cellView(i, cell: cell, gap: gap)
            }
            ForEach(Array(visitOrder.enumerated()), id: \.offset) { pair in
                if pair.element != pos {
                    let age = visitOrder.count - 1 - pair.offset
                    let fade = max(0, 1 - CGFloat(age) * 0.12)
                    Circle()
                        .fill(Color(hex: "FF8A3D").opacity(0.85 * fade))
                        .frame(width: cell * 0.16, height: cell * 0.16)
                        .position(x: gap + cell / 2 + CGFloat(pair.element % cols) * (cell + gap),
                                  y: gap + cell / 2 + CGFloat(pair.element / cols) * (cell + gap))
                }
            }
            // marble — a light gloss sphere with a grounding shadow
            Ellipse()
                .fill(Color.black.opacity(0.28))
                .frame(width: cell * 0.6, height: cell * 0.18)
                .offset(y: cell * 0.32)
                .position(x: gap + cell / 2 + CGFloat(pos % cols) * (cell + gap),
                          y: gap + cell / 2 + CGFloat(pos / cols) * (cell + gap))
                .animation(.snappy(duration: 0.14), value: pos)
            Circle()
                .fill(RadialGradient(colors: [.white, Color(hex: "C7CCD6")],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: cell * 0.5))
                .frame(width: cell * 0.72, height: cell * 0.72)
                .overlay(Circle().stroke(.black.opacity(0.08), lineWidth: 1))
                .position(x: gap + cell / 2 + CGFloat(pos % cols) * (cell + gap),
                          y: gap + cell / 2 + CGFloat(pos / cols) * (cell + gap))
                .animation(.snappy(duration: 0.14), value: pos)
        }
    }

    @ViewBuilder
    private func cellView(_ i: Int, cell: CGFloat, gap: CGFloat) -> some View {
        let c = i % cols, r = i / cols
        let cx = gap + cell / 2 + CGFloat(c) * (cell + gap)
        let cy = gap + cell / 2 + CGFloat(r) * (cell + gap)
        if walls.contains(i) {
            // A raised black block: a darker "side" offset down-right peeking
            // out from behind the top face, for a bit of 3D depth.
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Self.wallSide)
                    .frame(width: cell, height: cell)
                    .offset(x: 1.5, y: 2)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Self.wallTop)
                    .frame(width: cell, height: cell)
            }
            .position(x: cx, y: cy)
        } else {
            let painted = visited.contains(i)
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(painted ? AnyShapeStyle(Self.trailRed)
                                  : AnyShapeStyle(LinearGradient(colors: [Self.tileLight, Self.tileDark],
                                                                startPoint: .top, endPoint: .bottom)))
                    .frame(width: cell, height: cell)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(.white.opacity(painted ? 0.12 : 0.22), lineWidth: 1)
                    .frame(width: cell, height: cell)
            }
            .position(x: cx, y: cy)
        }
    }

    // MARK: movement

    private func roll(_ dc: Int, _ dr: Int) {
        guard !cleared else { return }
        var c = pos % cols
        var r = pos / cols
        var moved = false
        var hitWall = false
        while true {
            let nc = c + dc, nr = r + dr
            if nc < 0 || nc >= cols || nr < 0 || nr >= rows { break }
            let ni = nr * cols + nc
            if walls.contains(ni) { hitWall = true; break }
            c = nc; r = nr
            if visited.insert(ni).inserted { visitOrder.append(ni) }
            moved = true
        }
        guard moved else { return }
        pos = r * cols + c
        moveTick += 1
        if hitWall { hitTick += 1 }
        if visited.count >= openCells.count {
            cleared = true
            winTick += 1
            let next = level + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                level = next
                load(next)
            }
        }
    }

    // MARK: maze generation (recursive backtracker)

    private func load(_ n: Int) {
        let lvl = max(1, n)
        let cx = min(3, 2 + lvl / 8)
        let cy = min(3, 2 + lvl / 12)
        let mw = cx * 2 + 1
        let mh = cy * 2 + 1
        let maxBraid = min(0.45, 0.06 * Double(lvl))

        var chosen: [Bool] = []
        // Regenerate until every open tile can be reached AND painted by
        // sliding. Later attempts braid less, so a plain (always-solvable)
        // maze is the guaranteed fallback.
        for attempt in 0..<22 {
            let braid = attempt < 20 ? maxBraid * (1 - Double(attempt) / 20) : 0
            let grid = Self.generate(mw: mw, mh: mh, braid: braid)
            if Self.paintableBySliding(grid, mw: mw, mh: mh) {
                chosen = grid
                break
            }
            chosen = grid   // keep last as a fallback
        }

        cols = mw
        rows = mh
        var w = Set<Int>(); var o = Set<Int>()
        for i in 0..<(mw * mh) { if chosen[i] { o.insert(i) } else { w.insert(i) } }
        walls = w
        openCells = o
        pos = 0
        visited = [0]
        visitOrder = [0]
        cleared = false
    }

    /// Recursive-backtracker carve from (0,0), then optional braiding.
    private static func generate(mw: Int, mh: Int, braid: Double) -> [Bool] {
        var isOpen = [Bool](repeating: false, count: mw * mh)
        func idx(_ x: Int, _ y: Int) -> Int { y * mw + x }

        var stack: [(Int, Int)] = [(0, 0)]
        isOpen[idx(0, 0)] = true
        let dirs = [(2, 0), (-2, 0), (0, 2), (0, -2)]
        while let top = stack.last {
            let (x, y) = top
            let options = dirs.compactMap { d -> (Int, Int)? in
                let nx = x + d.0, ny = y + d.1
                guard nx >= 0, nx < mw, ny >= 0, ny < mh, !isOpen[idx(nx, ny)] else { return nil }
                return (nx, ny)
            }
            if options.isEmpty { stack.removeLast(); continue }
            let (nx, ny) = options.randomElement()!
            isOpen[idx((x + nx) / 2, (y + ny) / 2)] = true
            isOpen[idx(nx, ny)] = true
            stack.append((nx, ny))
        }

        if braid > 0 {
            let ortho = [(1, 0), (-1, 0), (0, 1), (0, -1)]
            func openAt(_ x: Int, _ y: Int) -> Bool {
                x >= 0 && x < mw && y >= 0 && y < mh && isOpen[idx(x, y)]
            }
            func wouldMake2x2(_ x: Int, _ y: Int) -> Bool {
                for (ox, oy) in [(0, 0), (-1, 0), (0, -1), (-1, -1)] {
                    let cells = [(x + ox, y + oy), (x + ox + 1, y + oy),
                                 (x + ox, y + oy + 1), (x + ox + 1, y + oy + 1)]
                    if cells.allSatisfy({ (a, b) in (a == x && b == y) || openAt(a, b) }) { return true }
                }
                return false
            }
            for y in 1..<(mh - 1) {
                for x in 1..<(mw - 1) where !isOpen[idx(x, y)] {
                    guard Double.random(in: 0..<1) < braid else { continue }
                    let openNbrs = ortho.filter { openAt(x + $0.0, y + $0.1) }.count
                    guard openNbrs >= 2, !wouldMake2x2(x, y) else { continue }
                    isOpen[idx(x, y)] = true
                }
            }
        }
        return isOpen
    }

    /// True if, sliding from cell 0, every open cell is either a place the
    /// marble can come to rest or a cell some slide passes over — i.e. every
    /// tile is paintable.
    private static func paintableBySliding(_ isOpen: [Bool], mw: Int, mh: Int) -> Bool {
        func idx(_ x: Int, _ y: Int) -> Int { y * mw + x }
        let dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        func slide(_ from: Int, _ dx: Int, _ dy: Int) -> (dest: Int, path: [Int]) {
            var x = from % mw, y = from / mw
            var path: [Int] = []
            while true {
                let nx = x + dx, ny = y + dy
                if nx < 0 || nx >= mw || ny < 0 || ny >= mh || !isOpen[idx(nx, ny)] { break }
                x = nx; y = ny
                path.append(idx(x, y))
            }
            return (idx(x, y), path)
        }

        guard isOpen[0] else { return false }
        var rest: Set<Int> = [0]
        var queue = [0]
        var covered: Set<Int> = [0]
        var qi = 0
        while qi < queue.count {
            let cur = queue[qi]; qi += 1
            for (dx, dy) in dirs {
                let (dest, path) = slide(cur, dx, dy)
                for p in path { covered.insert(p) }
                if dest != cur, !rest.contains(dest) {
                    rest.insert(dest)
                    queue.append(dest)
                }
            }
        }
        for i in 0..<(mw * mh) where isOpen[i] {
            if !covered.contains(i) { return false }
        }
        return true
    }
}
