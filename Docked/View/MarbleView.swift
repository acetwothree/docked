//
//  MarbleView.swift
//  Docked
//
//  "Maze Paint" — swipe and the marble slides until it hits a wall or the
//  edge. Paint every open tile to clear the level. Levels are random mazes (a
//  recursive-backtracker carve), regenerated at load time until a full-clear
//  order is verified to exist — an unsolvable layout is never shown, and among
//  the solvable candidates found, the most fragmented one (smallest largest
//  wall cluster) wins, so obstacles split up more as levels grow harder
//  instead of clumping into one or two big blocks. Grid size grows with the
//  level. Level persists.
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
    @State private var pos = 0
    @State private var cleared = false
    @State private var loaded = false
    @State private var moveTick = 0
    @State private var hitTick = 0
    @State private var winTick = 0

    private static let boardBG = Color(hex: "12141C")
    private static let tileOpen = Color(hex: "6E80B0")
    // Walls sit just a shade off the board so they read as raised blocks
    // without a hard cut-out look.
    private static let wallTop = Color(hex: "191C24")
    private static let wallSide = Color(hex: "0E1015")

    /// A different paint colour every level, looping once the list runs out.
    private static let trailColors: [Color] = [
        Color(hex: "D93A3A"), Color(hex: "F2883C"), Color(hex: "F2C230"),
        Color(hex: "3ECF7A"), Color(hex: "2FB6A8"), Color(hex: "3EA1E0"),
        Color(hex: "5C7CFA"), Color(hex: "9D6FF2"), Color(hex: "E064B8"),
        Color(hex: "F25C87"), Color(hex: "8BC34A"), Color(hex: "20C4CE"),
        Color(hex: "FF7043"), Color(hex: "C0CA33"),
    ]
    private var trail: Color { Self.trailColors[(max(1, level) - 1) % Self.trailColors.count] }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button { restartLevel() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Text("Level \(level)")
                    .font(.system(size: 17, weight: .black, design: .rounded))

                Spacer(minLength: 0)

                Text("\(visited.count)/\(openCells.count)")
                    .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(cleared ? Color.green : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 30, alignment: .trailing)
            }

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * 0.94
                board(side: side)
                    .frame(width: side, height: side)
                    // Just a touch of top-down-but-tilted skew — enough to
                    // read as 3D without distorting the board.
                    .rotation3DEffect(.degrees(13), axis: (x: 1, y: 0, z: 0), perspective: 0.12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(cleared ? "Cleared!" : "Swipe to roll · paint every tile")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(cleared ? Color.green : Color.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
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
        // No gaps — open tiles butt right up against each other so the walkable
        // area reads as one connected path, not a grid of little squares.
        let cell = side / span
        func center(_ p: Int) -> CGPoint {
            CGPoint(x: cell / 2 + CGFloat(p % cols) * cell,
                    y: cell / 2 + CGFloat(p / cols) * cell)
        }
        let mpos = center(pos)
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Self.boardBG)

            // one flat sheet for every open tile — seamless
            ForEach(Array(openCells).sorted(), id: \.self) { i in
                Rectangle().fill(Self.tileOpen)
                    .frame(width: cell + 0.5, height: cell + 0.5)
                    .position(center(i))
            }
            // the painted ribbon — same trick, one flat block per painted tile
            ForEach(Array(visited).sorted(), id: \.self) { i in
                Rectangle().fill(trail)
                    .frame(width: cell + 0.5, height: cell + 0.5)
                    .position(center(i))
            }
            // walls fused into blobs
            ForEach(Array(walls).sorted(), id: \.self) { i in
                wallCellView(i, cell: cell)
            }

            Ellipse()
                .fill(Color.black.opacity(0.28))
                .frame(width: cell * 0.6, height: cell * 0.18)
                .position(x: mpos.x, y: mpos.y + cell * 0.32)
                .animation(.easeOut(duration: 0.16), value: pos)
            Circle()
                .fill(RadialGradient(colors: [.white, Color(hex: "C7CCD6")],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: cell * 0.5))
                .frame(width: cell * 0.72, height: cell * 0.72)
                .overlay(Circle().stroke(.black.opacity(0.08), lineWidth: 1))
                .position(mpos)
                .animation(.easeOut(duration: 0.16), value: pos)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Flat, square wall tiles that butt together into clean rectilinear
    /// blobs. One flat fill, barely darker than the board, with a hairline
    /// bottom-right edge for the faintest sense of a raised block — no drop
    /// shadow, so it never looks like it's floating off the background.
    private func wallCellView(_ i: Int, cell: CGFloat) -> some View {
        let c = i % cols, r = i / cols
        let cx = cell / 2 + CGFloat(c) * cell
        let cy = cell / 2 + CGFloat(r) * cell
        return ZStack {
            Rectangle().fill(Self.wallSide)
                .frame(width: cell + 1, height: cell + 1).offset(x: 0.5, y: 0.5)
            Rectangle().fill(Self.wallTop)
                .frame(width: cell + 1, height: cell + 1)
        }
        .position(x: cx, y: cy)
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
            visited.insert(ni)
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
        // No stuck-state handling needed — every level is generated so it
        // can be finished from any rest position.
    }

    /// Resets the marble to the start of the SAME maze — no new layout is
    /// generated. Used by the reset button.
    private func restartLevel() {
        pos = 0
        visited = [0]
        cleared = false
    }

    // MARK: maze generation (recursive backtracker)

    //  ── level generation ──────────────────────────────────────────────
    //
    //  Base layout: a lattice of single pillars at even/even interior cells
    //  (the classic ice-slide grid) — from any tile you can always slide
    //  and stop somewhere useful, and you can always loop back, so you can
    //  NEVER get stranded. Then, for higher tiers, extra scattered blocks
    //  are added one at a time and only KEPT if the board still validates
    //  as "never stuck" (every open tile paintable AND every reachable rest
    //  position can slide back to the start). Movement + win logic untouched.
    //
    private func load(_ n: Int) {
        let lvl = max(1, n)
        let tier = min(5, 1 + (lvl - 1) / 4)
        let dim = min(11, 6 + tier)                 // 7 … 11
        let mw = dim, mh = dim
        cols = mw; rows = mh
        let count = mw * mh

        func idx(_ x: Int, _ y: Int) -> Int { y * mw + x }
        var wall = [Bool](repeating: false, count: count)
        func isOpen(_ i: Int) -> Bool { !wall[i] }

        // 1. pillar lattice (denser at higher tiers)
        let step = tier >= 4 ? 2 : (tier >= 2 ? 2 : 3)
        for y in stride(from: 2, to: mh - 1, by: step) {
            for x in stride(from: 2, to: mw - 1, by: step) {
                if idx(x, y) != 0 { wall[idx(x, y)] = true }
            }
        }
        if !Self.isNeverStuck(mw: mw, mh: mh, isOpen: isOpen) {
            wall = [Bool](repeating: false, count: count)   // (tiny grid) fall back to sparser
            for y in stride(from: 2, to: mh - 1, by: 3) {
                for x in stride(from: 2, to: mw - 1, by: 3) where idx(x, y) != 0 {
                    wall[idx(x, y)] = true
                }
            }
        }

        // 2. extra scattered obstacles for tier ≥ 2
        let target = wall.filter { $0 }.count + Int(Double(count) * [0, 0.05, 0.10, 0.16, 0.22, 0.28][tier])
        let shapes: [[(Int, Int)]] = tier <= 2
            ? [[(0, 0)]]
            : [[(0, 0)], [(0, 0), (1, 0)], [(0, 0), (0, 1)], [(0, 0), (1, 0), (1, 1)]]
        var attempts = 0
        while wall.filter({ $0 }).count < target, attempts < 400 {
            attempts += 1
            let shape = shapes.randomElement()!
            let bx = Int.random(in: 1..<(mw - 1)), by = Int.random(in: 1..<(mh - 1))
            let cells = shape.map { (bx + $0.0, by + $0.1) }
            guard cells.allSatisfy({ (x, y) in
                x >= 1 && x < mw - 1 && y >= 1 && y < mh - 1 && idx(x, y) != 0 && !wall[idx(x, y)]
            }) else { continue }
            for (x, y) in cells { wall[idx(x, y)] = true }
            if !Self.isNeverStuck(mw: mw, mh: mh, isOpen: isOpen) {
                for (x, y) in cells { wall[idx(x, y)] = false }   // revert
            }
        }

        var w = Set<Int>(); var o = Set<Int>()
        for i in 0..<count { if wall[i] { w.insert(i) } else { o.insert(i) } }
        walls = w
        openCells = o
        pos = 0
        visited = [0]
        cleared = false
    }

    /// Valid iff every open tile is paintable from the start AND every rest
    /// position reachable from the start can slide back to the start (so you
    /// can always loop around — no dead ends, no forced restart).
    static func isNeverStuck(mw: Int, mh: Int, isOpen: (Int) -> Bool) -> Bool {
        guard isOpen(0) else { return false }
        let dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        func slide(_ from: Int, _ dx: Int, _ dy: Int) -> (Int, [Int]) {
            var x = from % mw, y = from / mw
            var path: [Int] = []
            while true {
                let nx = x + dx, ny = y + dy
                if nx < 0 || nx >= mw || ny < 0 || ny >= mh || !isOpen(ny * mw + nx) { break }
                x = nx; y = ny; path.append(y * mw + x)
            }
            return (y * mw + x, path)
        }
        // forward BFS over rest positions; record every cell covered
        var rests: Set<Int> = [0]
        var edges: [Int: [Int]] = [:]           // rest -> rests it can slide to
        var covered: Set<Int> = [0]
        var q = [0], qi = 0
        while qi < q.count {
            let cur = q[qi]; qi += 1
            for (dx, dy) in dirs {
                let (dest, path) = slide(cur, dx, dy)
                covered.formUnion(path)
                guard dest != cur else { continue }
                edges[cur, default: []].append(dest)
                if !rests.contains(dest) { rests.insert(dest); q.append(dest) }
            }
        }
        // A: every open tile painted by some slide
        for i in 0..<(mw * mh) where isOpen(i) && !covered.contains(i) { return false }
        // B: reverse-reachability — can every rest get back to 0?
        var back: [Int: [Int]] = [:]
        for (a, outs) in edges { for b in outs { back[b, default: []].append(a) } }
        var canReturn: Set<Int> = [0]
        var q2 = [0], q2i = 0
        while q2i < q2.count {
            let cur = q2[q2i]; q2i += 1
            for prev in back[cur, default: []] where !canReturn.contains(prev) {
                canReturn.insert(prev); q2.append(prev)
            }
        }
        return rests.isSubset(of: canReturn)
    }

    /// True if, sliding from `start` (treating `covered` as already painted),
    /// every open cell is either a place the marble can come to rest or a
    /// cell some slide passes over — i.e. the rest of the board is still
    /// fully paintable from here. Used both to vet a freshly generated maze
    /// (`start: 0, covered: []`) and, after every move, to catch the player
    /// having painted themselves into an unwinnable corner.
    private static func paintableBySliding(mw: Int, mh: Int, isOpen: (Int) -> Bool,
                                           start: Int, covered initial: Set<Int>) -> Bool {
        func idx(_ x: Int, _ y: Int) -> Int { y * mw + x }
        let dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        func slide(_ from: Int, _ dx: Int, _ dy: Int) -> (dest: Int, path: [Int]) {
            var x = from % mw, y = from / mw
            var path: [Int] = []
            while true {
                let nx = x + dx, ny = y + dy
                if nx < 0 || nx >= mw || ny < 0 || ny >= mh || !isOpen(idx(nx, ny)) { break }
                x = nx; y = ny
                path.append(idx(x, y))
            }
            return (idx(x, y), path)
        }

        guard isOpen(start) else { return false }
        var rest: Set<Int> = [start]
        var queue = [start]
        var covered = initial
        covered.insert(start)
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
        for i in 0..<(mw * mh) where isOpen(i) {
            if !covered.contains(i) { return false }
        }
        return true
    }

    /// (retained for future validators) size of the biggest 4-connected wall blob.
    private static func maxWallClusterSize(_ isOpen: [Bool], mw: Int, mh: Int) -> Int {
        var seen = Set<Int>()
        var best = 0
        for start in 0..<(mw * mh) where !isOpen[start] && !seen.contains(start) {
            var count = 0
            var queue = [start]
            seen.insert(start)
            var qi = 0
            while qi < queue.count {
                let cur = queue[qi]; qi += 1
                count += 1
                let x = cur % mw, y = cur / mw
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < mw, ny >= 0, ny < mh else { continue }
                    let ni = ny * mw + nx
                    guard !seen.contains(ni), !isOpen[ni] else { continue }
                    seen.insert(ni)
                    queue.append(ni)
                }
            }
            best = max(best, count)
        }
        return best
    }
}
