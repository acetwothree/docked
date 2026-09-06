//
//  HexFallScene.swift
//  Docked
//
//  "Hex Fall" — a hexagon rests on top of a tall tower built from interlocking
//  tetromino pieces (O, I, L, J) that tile a rectangular column with no gaps.
//  Tap a piece to delete it instantly; anything that's now left with nothing
//  under it collapses away too, so the hexagon drops and rolls into the space
//  you opened. The tower is narrower than the screen — clear one side and the
//  hexagon rolls off the edge, and that's a loss. The camera trails the
//  hexagon downward (never back up) and fresh bands of tower keep generating
//  below, so a run only ends when the hexagon leaves the screen sideways or
//  falls past everything.
//
//  Grid: `gc` is the column (0..<cols). `gr` is a global row that only
//  increases downward. Each "band" is 2 rows tall and holds three tetromino
//  pieces that perfectly tile a cols×2 block. World y decreases as `gr` grows.
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

    private struct Brick {
        let id: Int
        let cells: [GridCell]        // .row (global, grows downward), .col
        let node: SKNode
    }
    private struct GridCell { let row: Int; let col: Int }
    private var bricks: [Int: Brick] = [:]
    /// (gr,gc) -> piece id, for support checks. Key = gr * 100 + gc.
    private var occ: [Int: Int] = [:]
    private var nextBrickID = 0
    private var nextBandRow = 0          // global row of the next band's top
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
        physicsWorld.gravity = CGVector(dx: 0, dy: -7)
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
        bricks.removeAll()
        occ.removeAll()
        hexagon?.removeFromParent()
        hexagon = nil
        nextBrickID = 0
        nextBandRow = 0
        deepestRow = 0
        score = 0
        blocksDestroyed = 0
        isOver = false
        physicsWorld.speed = 1
        onScoreChange?(0)

        towerW = size.width * 0.70
        towerX0 = (size.width - towerW) / 2
        cellW = towerW / CGFloat(cols)
        rowH = cellW
        firstRowY = size.height * 0.62

        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // Fill from the top down past the bottom of the view, plus a buffer.
        let neededRows = Int(size.height / rowH) + 8
        while nextBandRow < neededRows { addBand() }

        let hy = firstRowY + rowH * 1.4
        placeHexagon(atY: hy)
        startHexY = hy
    }

    // MARK: tower generation

    /// Three tetromino pieces (O, I, L or J) that tile a cols×2 block exactly.
    /// Each piece is a list of (localRow, localCol) with localRow in 0...1.
    private func bandPieces() -> [[(Int, Int)]] {
        // Each entry is one full tiling of a 2×4 sub-block into two tetrominoes.
        let tilings: [[[(Int, Int)]]] = [
            [[(0, 0), (0, 1), (1, 0), (1, 1)], [(0, 2), (0, 3), (1, 2), (1, 3)]],   // O + O
            [[(0, 0), (0, 1), (0, 2), (0, 3)], [(1, 0), (1, 1), (1, 2), (1, 3)]],   // I + I
            [[(0, 0), (1, 0), (1, 1), (1, 2)], [(0, 1), (0, 2), (0, 3), (1, 3)]],   // L + J
        ]
        let sub = tilings.randomElement()!                               // [[(Int, Int)]]
        let o: [(Int, Int)] = [(0, 0), (0, 1), (1, 0), (1, 1)]
        if Bool.random() {
            return sub + [o.map { ($0.0, $0.1 + 4) }]                    // 2×4 left, O right
        } else {
            return [o] + sub.map { piece in piece.map { ($0.0, $0.1 + 2) } }  // O left, 2×4 right
        }
    }

    private func addBand() {
        let topRow = nextBandRow
        for piece in bandPieces() {
            let id = nextBrickID; nextBrickID += 1
            let color = Self.palette.randomElement()!
            let container = SKNode()
            container.zPosition = 1
            var cells: [GridCell] = []
            for (lr, lc) in piece {
                let gr = topRow + lr, gc = lc
                cells.append(GridCell(row: gr, col: gc))
                occ[gr * 100 + gc] = id
                let cx = towerX0 + (CGFloat(gc) + 0.5) * cellW
                let cy = firstRowY - CGFloat(gr) * rowH
                let sq = SKShapeNode(rectOf: CGSize(width: cellW - 1.5, height: rowH - 1.5), cornerRadius: 2)
                sq.fillColor = color
                sq.strokeColor = SKColor.white.withAlphaComponent(0.22)
                sq.lineWidth = 1
                sq.position = CGPoint(x: cx, y: cy)
                sq.name = "b\(id)"
                let body = SKPhysicsBody(rectangleOf: CGSize(width: cellW, height: rowH))
                body.isDynamic = false
                body.friction = 0.9
                sq.physicsBody = body
                container.addChild(sq)
            }
            addChild(container)
            bricks[id] = Brick(id: id, cells: cells, node: container)
            deepestRow = max(deepestRow, cells.map(\.row).max() ?? topRow)
        }
        nextBandRow += 2
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
        // Circle collider — looks like a hexagon, rolls predictably, and can
        // never trip SpriteKit's convex-polygon validation.
        let body = SKPhysicsBody(circleOfRadius: radius * 0.92)
        body.friction = 0.55
        body.restitution = 0.02
        body.density = 0.8
        body.angularDamping = 0.22
        body.linearDamping = 0.06
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
        guard let hit = nodes(at: point).first(where: { ($0.name?.hasPrefix("b")) == true }),
              let name = hit.name, let id = Int(name.dropFirst()) else { return }
        removeBrick(id)
        blocksDestroyed += 1
        onTapHit?()
        collapseUnsupported()
    }

    private func removeBrick(_ id: Int) {
        guard let brick = bricks[id] else { return }
        for cell in brick.cells { occ.removeValue(forKey: cell.row * 100 + cell.col) }
        brick.node.removeFromParent()
        bricks.removeValue(forKey: id)
    }

    /// Any piece no longer connected to the generation frontier through a
    /// column of filled cells below it just falls away (removed instantly,
    /// same as a tapped one — no half-supported bricks left hanging).
    private func collapseUnsupported() {
        var supported = Set<Int>()
        var changed = true
        while changed {
            changed = false
            for (id, brick) in bricks where !supported.contains(id) {
                for cell in brick.cells {
                    if cell.row >= deepestRow - 1 {           // resting on the frontier
                        supported.insert(id); changed = true; break
                    }
                    if let below = occ[(cell.row + 1) * 100 + cell.col], supported.contains(below) {
                        supported.insert(id); changed = true; break
                    }
                }
            }
        }
        let doomed = bricks.keys.filter { !supported.contains($0) }
        for id in doomed {
            removeBrick(id)
            blocksDestroyed += 1
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, cam != nil, let hex = hexagon else { return }

        // Keep the hexagon high on screen so most of the view shows the tower
        // BELOW it — that's the part you're working on.
        let desiredY = hex.position.y - size.height * 0.28
        let smoothed = cam.position.y + (desiredY - cam.position.y) * 0.09
        cam.position.y = min(cam.position.y, smoothed)

        // Generate ahead of the camera; bounded per frame.
        var guardCount = 0
        while firstRowY - CGFloat(nextBandRow) * rowH > cam.position.y - size.height && guardCount < 30 {
            addBand()
            guardCount += 1
        }
        // Cull bands well above the view (using each piece's grid row, since
        // the container node sits at the origin and its cells carry the
        // absolute positions).
        let cullY = cam.position.y + size.height
        let stale = bricks.filter { worldY($0.value) > cullY }.map(\.key)
        for id in stale {
            if let brick = bricks[id] {
                for cell in brick.cells { occ.removeValue(forKey: cell.row * 100 + cell.col) }
                brick.node.removeFromParent()
            }
            bricks.removeValue(forKey: id)
        }

        // Rolled off the tower — its center is more than half a cell past
        // either tower edge (into the empty gutter beside it).
        let rolledOff = hex.position.x < towerX0 - cellW * 0.5
            || hex.position.x > towerX0 + towerW + cellW * 0.5
        // Backstop: somehow fell far past the camera (huge collapse void).
        let fellThrough = hex.position.y < cam.position.y - size.height * 0.9
        if rolledOff || fellThrough {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
            return
        }

        let depth = max(0, Int((startHexY - hex.position.y) / rowH))
        let s = depth + blocksDestroyed
        if s != score {
            score = s
            onScoreChange?(s)
        }
    }

    private func worldY(_ brick: Brick) -> CGFloat {
        let grs = brick.cells.map(\.row)
        let avg = CGFloat(grs.reduce(0, +)) / CGFloat(max(1, grs.count))
        return firstRowY - avg * rowH
    }
}
