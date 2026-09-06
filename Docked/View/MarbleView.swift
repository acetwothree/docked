//
//  MarbleView.swift
//  Docked
//
//  "Maze Paint" — swipe and the marble slides until it hits a wall or the
//  edge. Paint every open tile to clear the level. Levels are real carved
//  mazes (recursive-backtracker + braiding), regenerated at load time until
//  one validates as "never stuck": every open tile paintable AND the slide
//  graph fully connected, so a hard-reset is never forced. Easier tiers braid
//  more (loopier, forgiving); harder tiers keep more dead ends. Grid size
//  grows with the level. Level persists.
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
    @State private var swipeTick = 0

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
        .sensoryFeedback(.selection, trigger: swipeTick) { _, _ in app.haptics }
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

            // Whole board — open tiles (painted or not) and walls — drawn in
            // ONE Canvas pass. Hundreds of individually-positioned Rectangles
            // inside a 3D-rotated ZStack was the source of the swipe lag;
            // Canvas has nothing to diff, so a move just repaints once.
            Canvas { ctx, _ in
                for i in openCells {
                    let c = center(i)
                    let r = CGRect(x: c.x - cell / 2, y: c.y - cell / 2,
                                   width: cell + 0.5, height: cell + 0.5)
                    ctx.fill(Path(r), with: .color(visited.contains(i) ? trail : Self.tileOpen))
                }
                for i in walls {
                    let c = center(i)
                    let base = CGRect(x: c.x - cell / 2 - 0.5, y: c.y - cell / 2 - 0.5,
                                      width: cell + 1, height: cell + 1)
                    ctx.fill(Path(base.offsetBy(dx: 0.5, dy: 0.5)), with: .color(Self.wallSide))
                    ctx.fill(Path(base), with: .color(Self.wallTop))
                }
            }
            .frame(width: side, height: side)

            Ellipse()
                .fill(Color.black.opacity(0.28))
                .frame(width: cell * 0.6, height: cell * 0.18)
                .position(x: mpos.x, y: mpos.y + cell * 0.32)
                .animation(.easeOut(duration: 0.12), value: pos)
            Circle()
                .fill(RadialGradient(colors: [.white, Color(hex: "C7CCD6")],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: cell * 0.5))
                .frame(width: cell * 0.72, height: cell * 0.72)
                .overlay(Circle().stroke(.black.opacity(0.08), lineWidth: 1))
                .position(mpos)
                .animation(.easeOut(duration: 0.12), value: pos)
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
        swipeTick += 1                       // every swipe gets a tick, moved or not
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
            ReviewPrompt.shared.recordDelight()
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

    // MARK: maze generation (recursive backtracker + braid)

    //  ── level generation ──────────────────────────────────────────────
    //
    //  Each level is a real carved maze: an iterative recursive-backtracker
    //  builds a 1-wide corridor tree over rooms at even/even cells (odd/odd
    //  cells stay as pillars), then "braiding" knocks out extra walls so
    //  dead ends become loops. Easier tiers braid heavily (very loopy,
    //  forgiving); harder tiers keep more dead ends. Every candidate is run
    //  through `isNeverStuck` — a layout only ships if every open tile is
    //  paintable AND the slide graph is fully connected (you can always get
    //  from any rest position back to any other, so a hard-reset is never
    //  forced). If a tier's target braid never validates we ease the braid
    //  up until it does. Movement + win logic are untouched.
    //
    private func load(_ n: Int) {
        let lvl = max(1, n)
        let tier = min(5, 1 + (lvl - 1) / 4)
        var dim = min(11, 6 + tier)                 // 7 … 11
        dim |= 1                                    // force odd → 7, 9, 9, 11, 11
        let mw = dim, mh = dim
        cols = mw; rows = mh
        let count = mw * mh

        let braidByTier: [Double] = [0, 1.0, 0.85, 0.7, 0.55, 0.42]
        let baseBraid = braidByTier[tier]

        var rng = SystemRandomNumberGenerator()
        var chosen = Self.carvedMaze(dim: dim, braid: 1.0, rng: &rng)
        for attempt in 0..<80 {
            // Ease the braid up on each retry so we always converge on a
            // valid, fully-connected layout; past halfway, force a fully
            // braided (dead-end-free) maze, which is always connected.
            let b = attempt >= 40 ? 1.0 : min(1.0, baseBraid + Double(attempt) * 0.02)
            let cand = Self.carvedMaze(dim: dim, braid: b, rng: &rng)
            chosen = cand
            if Self.isNeverStuck(mw: mw, mh: mh, isOpen: { !cand[$0] }) { break }
        }
        let wall = chosen

        var w = Set<Int>(); var o = Set<Int>()
        for i in 0..<count { if wall[i] { w.insert(i) } else { o.insert(i) } }
        walls = w
        openCells = o
        pos = 0
        visited = [0]
        cleared = false
    }

    /// Iterative recursive-backtracker over rooms at even/even cells, then a
    /// braid pass that opens one extra wall on `braid`-fraction of dead-end
    /// rooms. Returns `wall[y*dim + x]` (true = solid). `dim` must be odd.
    static func carvedMaze(dim: Int, braid: Double,
                           rng: inout SystemRandomNumberGenerator) -> [Bool] {
        func idx(_ x: Int, _ y: Int) -> Int { y * dim + x }
        var wall = [Bool](repeating: true, count: dim * dim)

        let rps = (dim + 1) / 2                     // rooms per side (x = 0, 2, 4 …)
        func rIdx(_ rx: Int, _ ry: Int) -> Int { ry * rps + rx }
        var seen = [Bool](repeating: false, count: rps * rps)
        let steps = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        var stack: [(Int, Int)] = [(0, 0)]
        seen[rIdx(0, 0)] = true
        wall[idx(0, 0)] = false

        while let (rx, ry) = stack.last {
            var options: [(nrx: Int, nry: Int, wx: Int, wy: Int)] = []
            for (dx, dy) in steps {
                let nrx = rx + dx, nry = ry + dy
                guard nrx >= 0, nrx < rps, nry >= 0, nry < rps, !seen[rIdx(nrx, nry)] else { continue }
                options.append((nrx, nry, 2 * rx + dx, 2 * ry + dy))
            }
            guard let pick = options.randomElement(using: &rng) else {
                stack.removeLast()
                continue
            }
            wall[idx(pick.wx, pick.wy)] = false             // carve the door
            wall[idx(2 * pick.nrx, 2 * pick.nry)] = false   // carve the room
            seen[rIdx(pick.nrx, pick.nry)] = true
            stack.append((pick.nrx, pick.nry))
        }

        guard braid > 0 else { return wall }
        for ry in 0..<rps {
            for rx in 0..<rps {
                let gx = 2 * rx, gy = 2 * ry
                var openN = 0
                var closed: [(Int, Int)] = []
                for (dx, dy) in steps {
                    let nrx = rx + dx, nry = ry + dy
                    guard nrx >= 0, nrx < rps, nry >= 0, nry < rps else { continue }
                    let wx = gx + dx, wy = gy + dy
                    if wall[idx(wx, wy)] { closed.append((wx, wy)) } else { openN += 1 }
                }
                if openN <= 1, !closed.isEmpty,
                   Double.random(in: 0..<1, using: &rng) < braid,
                   let d = closed.randomElement(using: &rng) {
                    wall[idx(d.0, d.1)] = false
                }
            }
        }
        return wall
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
