//
//  HexFallScene.swift
//  Docked
//
//  "Hex Fall" — a real hexagon rests on top of a tower built from
//  interlocking tetromino pieces (O, I, L, J) that tile a rectangular column
//  with no gaps. Each piece is ONE connected shape with a thick outline so
//  you can tell touching same-colour pieces apart. Tap a piece to delete it
//  instantly; any piece left with nothing under it stops being static and
//  falls under gravity. The hexagon is a genuine six-sided collider, so an
//  uneven tap tips it, it rolls, and it can tumble right off the edge of the
//  (narrower-than-screen) tower — which is the loss. The camera trails it
//  down, never back up, and fresh bands keep generating below.
//
//  Grid: `col` is 0..<cols; `row` is a global row that only grows downward.
//  A "band" is 2 rows tall and holds three tetrominoes tiling a cols×2 block.
//

import SpriteKit

final class HexFallScene: SKScene {
    var onScoreChange: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onTapHit: (() -> Void)?

    private(set) var score = 0
    private(set) var isOver = false

    private let cols = 6

    private var cellW: CGFloat = 20
    private var rowH: CGFloat = 20
    private var towerX0: CGFloat = 0
    private var towerW: CGFloat = 0
    private var firstRowY: CGFloat = 0

    private struct GridCell { let row: Int; let col: Int }
    private struct Brick {
        let id: Int
        var cells: [GridCell]
        let node: SKNode
    }
    private var bricks: [Int: Brick] = [:]
    private var debris: [SKNode] = []            // pieces that have gone dynamic
    private var occ: [Int: Int] = [:]           // row*100+col -> brick id
    private var nextBrickID = 0
    private var nextBandRow = 0
    private var deepestRow = 0

    private var hexagon: SKShapeNode?
    private var startHexY: CGFloat = 0
    private var blocksDestroyed = 0
    private var cam: SKCameraNode!

    private static let palette: [SKColor] = [
        SKColor(red: 0.90, green: 0.30, blue: 0.26, alpha: 1),
        SKColor(red: 0.96, green: 0.56, blue: 0.26, alpha: 1),
        SKColor(red: 0.96, green: 0.78, blue: 0.20, alpha: 1),
        SKColor(red: 0.26, green: 0.82, blue: 0.50, alpha: 1),
        SKColor(red: 0.26, green: 0.64, blue: 0.90, alpha: 1),
        SKColor(red: 0.58, green: 0.38, blue: 0.98, alpha: 1),
    ]

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -9)
        let camera = SKCameraNode()
        self.camera = camera
        cam = camera
        addChild(camera)
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard cam != nil else { return }
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            build()
        }
    }

    func reset() { build() }

    private func build() {
        guard cam != nil, size.width > 10, size.height > 10 else { return }

        for (_, b) in bricks { b.node.removeFromParent() }
        for d in debris { d.removeFromParent() }
        bricks.removeAll(); debris.removeAll(); occ.removeAll()
        hexagon?.removeFromParent(); hexagon = nil
        nextBrickID = 0; nextBandRow = 0; deepestRow = 0
        score = 0; blocksDestroyed = 0; isOver = false
        physicsWorld.speed = 1
        onScoreChange?(0)

        towerW = size.width * 0.70
        towerX0 = (size.width - towerW) / 2
        cellW = towerW / CGFloat(cols)
        rowH = cellW
        firstRowY = size.height * 0.62

        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)

        let neededRows = Int(size.height / rowH) + 8
        while nextBandRow < neededRows { addBand() }

        let hy = firstRowY + rowH * 1.5
        placeHexagon(atY: hy)
        startHexY = hy
    }

    // MARK: tower generation

    private func bandPieces() -> [[(Int, Int)]] {
        let tilings: [[[(Int, Int)]]] = [
            [[(0, 0), (0, 1), (1, 0), (1, 1)], [(0, 2), (0, 3), (1, 2), (1, 3)]],   // O + O
            [[(0, 0), (0, 1), (0, 2), (0, 3)], [(1, 0), (1, 1), (1, 2), (1, 3)]],   // I + I
            [[(0, 0), (1, 0), (1, 1), (1, 2)], [(0, 1), (0, 2), (0, 3), (1, 3)]],   // L + J
        ]
        let sub = tilings.randomElement()!
        let o: [(Int, Int)] = [(0, 0), (0, 1), (1, 0), (1, 1)]
        if Bool.random() {
            return sub + [o.map { ($0.0, $0.1 + 4) }]
        } else {
            return [o] + sub.map { piece in piece.map { ($0.0, $0.1 + 2) } }
        }
    }

    private func addBand() {
        let topRow = nextBandRow
        for piece in bandPieces() {
            let id = nextBrickID; nextBrickID += 1
            let color = Self.palette.randomElement()!
            var cells: [GridCell] = []
            for (lr, lc) in piece {
                cells.append(GridCell(row: topRow + lr, col: lc))
                occ[(topRow + lr) * 100 + lc] = id
            }
            let node = makePieceNode(cells: cells, color: color)
            addChild(node)
            bricks[id] = Brick(id: id, cells: cells, node: node)
            deepestRow = max(deepestRow, cells.map(\.row).max() ?? topRow)
        }
        nextBandRow += 2
    }

    /// One connected shape for the whole tetromino (fill = union of its
    /// cells) plus a thick stroke that traces only the OUTER boundary, so
    /// two touching pieces of the same colour still read as separate. The
    /// container node sits at the piece's centroid; children and body parts
    /// are all relative to that, so it falls and rotates cleanly if it later
    /// goes dynamic.
    private func makePieceNode(cells: [GridCell], color: SKColor) -> SKNode {
        let node = SKNode()
        node.zPosition = 1
        let set = Set(cells.map { $0.row * 100 + $0.col })
        func has(_ r: Int, _ c: Int) -> Bool { set.contains(r * 100 + c) }

        func worldCenter(_ cell: GridCell) -> CGPoint {
            CGPoint(x: towerX0 + (CGFloat(cell.col) + 0.5) * cellW,
                    y: firstRowY - CGFloat(cell.row) * rowH)
        }
        let cs = cells.map(worldCenter)
        let origin = CGPoint(x: cs.map(\.x).reduce(0, +) / CGFloat(cs.count),
                             y: cs.map(\.y).reduce(0, +) / CGFloat(cs.count))
        node.position = origin

        func rect(_ cell: GridCell) -> CGRect {
            let wc = worldCenter(cell)
            return CGRect(x: wc.x - origin.x - cellW / 2, y: wc.y - origin.y - rowH / 2,
                          width: cellW, height: rowH)
        }

        // filled union
        let fill = CGMutablePath()
        for cell in cells { fill.addRect(rect(cell)) }
        let fillNode = SKShapeNode(path: fill)
        fillNode.fillColor = color
        fillNode.strokeColor = .clear
        fillNode.isAntialiased = false
        node.addChild(fillNode)

        // outer boundary only
        let border = CGMutablePath()
        for cell in cells {
            let r = rect(cell)
            if !has(cell.row - 1, cell.col) {                 // top edge (row-1 is up)
                border.move(to: CGPoint(x: r.minX, y: r.maxY)); border.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            }
            if !has(cell.row + 1, cell.col) {                 // bottom edge
                border.move(to: CGPoint(x: r.minX, y: r.minY)); border.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            }
            if !has(cell.row, cell.col - 1) {                 // left edge
                border.move(to: CGPoint(x: r.minX, y: r.minY)); border.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            }
            if !has(cell.row, cell.col + 1) {                 // right edge
                border.move(to: CGPoint(x: r.maxX, y: r.minY)); border.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            }
        }
        let borderNode = SKShapeNode(path: border)
        borderNode.strokeColor = SKColor.black.withAlphaComponent(0.55)
        borderNode.lineWidth = 3
        borderNode.lineCap = .square
        borderNode.isAntialiased = true
        node.addChild(borderNode)

        // compound body (static for now)
        var bodies: [SKPhysicsBody] = []
        for cell in cells {
            let r = rect(cell)
            bodies.append(SKPhysicsBody(rectangleOf: CGSize(width: cellW, height: rowH),
                                        center: CGPoint(x: r.midX, y: r.midY)))
        }
        let body = SKPhysicsBody(bodies: bodies)
        body.isDynamic = false
        body.friction = 0.9
        body.restitution = 0.0
        body.affectedByGravity = true
        node.physicsBody = body
        node.name = "brick"
        return node
    }

    private func placeHexagon(atY y: CGFloat) {
        let radius = cellW * 0.85
        let path = TetrominoBuilder.polygonPath(sides: 6, radius: radius)
        let hex = SKShapeNode(path: path)
        hex.fillColor = SKColor(red: 0.26, green: 0.64, blue: 0.90, alpha: 1)
        hex.strokeColor = .white
        hex.lineWidth = 2
        hex.position = CGPoint(x: size.width / 2, y: y)
        hex.zPosition = 50
        // Real hexagon collider so it can tip onto an edge or vertex and
        // topple instead of always sliding straight down.
        let body = SKPhysicsBody(polygonFrom: path)
        body.friction = 0.85
        body.restitution = 0.0
        body.density = 1.0
        body.angularDamping = 0.08
        body.linearDamping = 0.05
        hex.physicsBody = body
        addChild(hex)
        hexagon = hex
    }

    // MARK: input

    func scenePoint(fromView p: CGPoint, viewSize: CGSize) -> CGPoint {
        let camPos = cam?.position ?? CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = p.x - viewSize.width / 2
        let dy = viewSize.height / 2 - p.y
        return CGPoint(x: camPos.x + dx, y: camPos.y + dy)
    }

    func handleTap(at point: CGPoint) {
        guard !isOver else { return }
        // Exact hit test via the grid: which cell did the tap land in?
        let col = Int((point.x - towerX0) / cellW)
        guard col >= 0, col < cols else { return }
        let row = Int(((firstRowY - point.y) / rowH).rounded())
        guard row >= 0, let id = occ[row * 100 + col], bricks[id] != nil else { return }
        removeBrick(id)
        blocksDestroyed += 1
        onTapHit?()
        dropUnsupported()
    }

    private func removeBrick(_ id: Int) {
        guard let brick = bricks[id] else { return }
        for cell in brick.cells { occ.removeValue(forKey: cell.row * 100 + cell.col) }
        brick.node.removeFromParent()
        bricks.removeValue(forKey: id)
    }

    /// Any piece no longer connected down to the generation frontier through
    /// filled cells stops being static and just falls.
    private func dropUnsupported() {
        var supported = Set<Int>()
        var changed = true
        while changed {
            changed = false
            for (id, brick) in bricks where !supported.contains(id) {
                for cell in brick.cells {
                    if cell.row >= deepestRow - 1 { supported.insert(id); changed = true; break }
                    if let below = occ[(cell.row + 1) * 100 + cell.col], supported.contains(below) {
                        supported.insert(id); changed = true; break
                    }
                }
            }
        }
        let falling = bricks.keys.filter { !supported.contains($0) }
        for id in falling {
            guard let brick = bricks[id] else { continue }
            for cell in brick.cells { occ.removeValue(forKey: cell.row * 100 + cell.col) }
            brick.node.physicsBody?.isDynamic = true
            brick.node.physicsBody?.affectedByGravity = true
            brick.node.name = "debris"
            debris.append(brick.node)
            bricks.removeValue(forKey: id)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, cam != nil, let hex = hexagon else { return }

        // Keep the hexagon high on screen so most of the view is the tower
        // below it — the part you're working on.
        let desiredY = hex.position.y - size.height * 0.28
        let smoothed = cam.position.y + (desiredY - cam.position.y) * 0.09
        cam.position.y = min(cam.position.y, smoothed)

        var guardCount = 0
        while firstRowY - CGFloat(nextBandRow) * rowH > cam.position.y - size.height && guardCount < 30 {
            addBand(); guardCount += 1
        }

        // cull static bands + debris well above / below the view
        let topCull = cam.position.y + size.height
        let botCull = cam.position.y - size.height * 1.4
        let staleBricks = bricks.filter { worldY($0.value) > topCull }.map(\.key)
        for id in staleBricks {
            if let b = bricks[id] {
                for cell in b.cells { occ.removeValue(forKey: cell.row * 100 + cell.col) }
                b.node.removeFromParent()
            }
            bricks.removeValue(forKey: id)
        }
        debris.removeAll { d in
            if d.position.y > topCull || d.position.y < botCull { d.removeFromParent(); return true }
            return false
        }

        let rolledOff = hex.position.x < towerX0 - cellW * 0.5
            || hex.position.x > towerX0 + towerW + cellW * 0.5
        let fellThrough = hex.position.y < cam.position.y - size.height * 0.9
        if rolledOff || fellThrough {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
            return
        }

        let depth = max(0, Int((startHexY - hex.position.y) / rowH))
        let s = depth + blocksDestroyed
        if s != score { score = s; onScoreChange?(s) }
    }

    private func worldY(_ brick: Brick) -> CGFloat {
        let rows = brick.cells.map(\.row)
        let avg = CGFloat(rows.reduce(0, +)) / CGFloat(max(1, rows.count))
        return firstRowY - avg * rowH
    }
}
