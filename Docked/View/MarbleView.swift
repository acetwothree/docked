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
    /// True briefly while the marble is being slid back to the start because
    /// the last unpainted tiles are no longer reachable from where it is.
    @State private var repositioning = false

    private static let boardBG = Color(hex: "12141C")
    private static let tileOpen = Color(hex: "7486B4")
    private static let wallTop = Color(hex: "23262F")
    private static let wallSide = Color(hex: "0B0C11")

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

            Text(cleared ? "Cleared!"
                 : repositioning ? "No path back — sliding you home"
                 : "Swipe to roll · paint every tile")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(cleared ? Color.green
                                 : repositioning ? Color.orange : Color.secondary)
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
    /// blobs — no per-cell rounding, so touching walls never leave odd
    /// rounded nubs in the inner corners.
    private func wallCellView(_ i: Int, cell: CGFloat) -> some View {
        let c = i % cols, r = i / cols
        let cx = cell / 2 + CGFloat(c) * cell
        let cy = cell / 2 + CGFloat(r) * cell
        return ZStack {
            Rectangle().fill(Self.wallSide)
                .frame(width: cell + 1, height: cell + 1).offset(x: 1, y: 2)
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
            return
        }

        // Never let the player get stranded: if the tiles still unpainted
        // can't all be reached from where the marble now sits, slide it back
        // to the start (keeping everything already painted) — the maze is
        // always finishable from the start, so this can't loop forever.
        let ok = Self.paintableBySliding(mw: cols, mh: rows,
                                         isOpen: { openCells.contains($0) },
                                         start: pos, covered: visited)
        if !ok {
            repositioning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeOut(duration: 0.18)) { pos = 0 }
                visited.insert(0)
                repositioning = false
            }
        }
    }

    /// Resets the marble to the start of the SAME maze — no new layout is
    /// generated. Used by the reset button.
    private func restartLevel() {
        pos = 0
        visited = [0]
        cleared = false
    }

    // MARK: maze generation (recursive backtracker)

    private func load(_ n: Int) {
        let lvl = max(1, n)
        // Bigger grids sooner, and more braiding — braided cells are the
        // extra openings that turn dead ends into real "which way?" choices.
        let cx = min(4, 2 + lvl / 4)
        let cy = min(4, 2 + lvl / 5)
        let mw = cx * 2 + 1
        let mh = cy * 2 + 1
        let maxBraid = min(0.62, 0.09 * Double(lvl))

        var chosen: [Bool] = []
        var bestClusterSize = Int.max
        // Try a batch of layouts (later ones braid less, so a plain
        // always-solvable maze is the guaranteed fallback), keep every
        // solvable one, and pick whichever splits its walls into the
        // smallest largest cluster — the more fragmented the obstacles, the
        // harder the level reads without ever risking an unsolvable board.
        for attempt in 0..<22 {
            let braid = attempt < 20 ? maxBraid * (1 - Double(attempt) / 20) : 0
            let grid = Self.generate(mw: mw, mh: mh, braid: braid)
            guard Self.paintableBySliding(mw: mw, mh: mh, isOpen: { grid[$0] }, start: 0, covered: []) else {
                if chosen.isEmpty { chosen = grid }   // last-resort fallback if nothing solvable is found
                continue
            }
            let cluster = Self.maxWallClusterSize(grid, mw: mw, mh: mh)
            if cluster < bestClusterSize {
                bestClusterSize = cluster
                chosen = grid
            }
        }

        cols = mw
        rows = mh
        var w = Set<Int>(); var o = Set<Int>()
        for i in 0..<(mw * mh) { if chosen[i] { o.insert(i) } else { w.insert(i) } }
        walls = w
        openCells = o
        pos = 0
        visited = [0]
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

    /// Size of the biggest 4-connected group of wall cells — the smaller
    /// this is, the more the obstacles read as scattered pieces rather than
    /// one or two big blocks.
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
