//
//  HexFallScene.swift
//  Docked
//
//  "Hex Fall" — a flat-top hexagon rests on top of a tall, narrow tower of
//  packed bricks. Tap bricks to delete them instantly (no animation); the
//  hexagon is the only real physics body, so it drops and rolls into
//  whatever gap you open. The tower is narrower than the screen — clear the
//  bricks under one side and the hexagon rolls off into empty air, and
//  that's a loss. A camera follows it down and fresh rows keep generating
//  below, so the only way a run ends is the hexagon leaving the screen
//  sideways or falling past everything.
//
//  Coordinates: standard SpriteKit (y up). Rows are stacked going DOWN
//  (each new row at a lower y than the last), the hexagon falls toward
//  lower y, and the camera's y only ever decreases.
//

import SpriteKit

final class HexFallScene: SKScene {
    var onScoreChange: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onTapHit: (() -> Void)?

    private(set) var score = 0
    private(set) var isOver = false

    /// Segments per row — a row's pieces always tile the full tower width.
    private let cols = 6

    private var cellW: CGFloat = 20
    private var rowH: CGFloat = 26
    private var towerX0: CGFloat = 0
    private var towerW: CGFloat = 0

    private var hexagon: SKShapeNode?
    private var bricks: [SKNode] = []
    /// The y of the NEXT row to be generated (decreases as the tower extends).
    private var nextRowY: CGFloat = 0
    private var startHexY: CGFloat = 0
    private var blocksDestroyed = 0
    private var cam: SKCameraNode!

    private static let palette: [SKColor] = [
        SKColor(red: 0.90, green: 0.30, blue: 0.26, alpha: 1),
        SKColor(red: 0.96, green: 0.56, blue: 0.26, alpha: 1),
        SKColor(red: 0.26, green: 0.82, blue: 0.50, alpha: 1),
        SKColor(red: 0.26, green: 0.64, blue: 0.90, alpha: 1),
        SKColor(red: 0.58, green: 0.38, blue: 0.98, alpha: 1),
    ]

    /// Unstable-row splits — segment widths in units, each summing to `cols`.
    private static let rowSplits: [[Int]] = [
        [6], [6], [3, 3], [2, 2, 2], [4, 2], [2, 4], [1, 3, 2], [2, 3, 1],
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
        guard cam != nil else { return }   // not presented yet — didMove will build
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            build()
        }
    }

    func reset() { build() }

    private func build() {
        guard cam != nil, size.width > 10, size.height > 10 else { return }

        for b in bricks { b.removeFromParent() }
        bricks.removeAll()
        hexagon?.removeFromParent()
        hexagon = nil
        score = 0
        blocksDestroyed = 0
        isOver = false
        physicsWorld.speed = 1
        onScoreChange?(0)

        towerW = size.width * 0.66
        towerX0 = (size.width - towerW) / 2
        cellW = towerW / CGFloat(cols)
        rowH = cellW * 0.92

        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // First row a little above centre; rows then march downward.
        nextRowY = size.height * 0.60
        let startRows = Int(size.height / rowH) + 4
        for i in 0..<startRows { addRow(forceStable: i == 0) }

        let hy = size.height * 0.60 + rowH * 1.6
        placeHexagon(atY: hy)
        startHexY = hy
    }

    // MARK: row generation — rows tile the full tower width, no gaps; the
    // player makes the gaps by tapping bricks out.

    private func addRow(forceStable: Bool = false) {
        let split = forceStable ? [cols] : Self.rowSplits.randomElement()!
        let color = Self.palette.randomElement()!
        let y = nextRowY

        var unit = 0
        for w in split {
            let segW = CGFloat(w) * cellW
            let midX = towerX0 + CGFloat(unit) * cellW + segW / 2
            let node = SKShapeNode(rectOf: CGSize(width: max(2, segW - 1.5), height: max(2, rowH - 1.5)),
                                   cornerRadius: 2)
            node.fillColor = color
            node.strokeColor = SKColor.white.withAlphaComponent(0.22)
            node.lineWidth = 1
            node.position = CGPoint(x: midX, y: y)
            node.zPosition = 1
            node.name = "brick"
            let body = SKPhysicsBody(rectangleOf: CGSize(width: segW, height: rowH))
            body.isDynamic = false
            body.friction = 0.9
            node.physicsBody = body
            addChild(node)
            bricks.append(node)
            unit += w
        }
        nextRowY -= rowH
    }

    private func placeHexagon(atY y: CGFloat) {
        let radius = cellW * 0.82
        let path = TetrominoBuilder.polygonPath(sides: 6, radius: radius)
        let hex = SKShapeNode(path: path)
        hex.fillColor = SKColor(red: 0.26, green: 0.64, blue: 0.90, alpha: 1)
        hex.strokeColor = .white
        hex.lineWidth = 2
        hex.position = CGPoint(x: size.width / 2, y: y)
        hex.zPosition = 50
        // A circle body (not `polygonFrom:`) — it still LOOKS like a hexagon,
        // but a circle collider can never trip SpriteKit's convex-polygon
        // validation, and it rolls predictably down the tower.
        let body = SKPhysicsBody(circleOfRadius: radius * 0.94)
        body.friction = 0.6
        body.restitution = 0.02
        body.density = 0.8
        body.angularDamping = 0.25
        body.linearDamping = 0.08
        body.allowsRotation = true
        hex.physicsBody = body
        addChild(hex)
        hexagon = hex
    }

    // MARK: input

    /// Converts a SwiftUI tap point (view space, y-down) into scene space,
    /// accounting for the camera's current y offset.
    func scenePoint(fromView p: CGPoint, viewSize: CGSize) -> CGPoint {
        let camPos = cam?.position ?? CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = p.x - viewSize.width / 2
        let dy = viewSize.height / 2 - p.y
        return CGPoint(x: camPos.x + dx, y: camPos.y + dy)
    }

    func handleTap(at point: CGPoint) {
        guard !isOver else { return }
        guard let node = nodes(at: point).first(where: { $0.name == "brick" }) else { return }
        node.removeFromParent()
        bricks.removeAll { $0 === node }
        blocksDestroyed += 1
        onTapHit?()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, cam != nil, let hex = hexagon else { return }

        // Camera trails the hexagon downward and never climbs back up.
        let desiredY = hex.position.y + size.height * 0.15
        let smoothed = cam.position.y + (desiredY - cam.position.y) * 0.09
        cam.position.y = min(cam.position.y, smoothed)

        // Keep about a screen of terrain ready below the view. `nextRowY`
        // only decreases, and each pass lowers it further, so this loop is
        // always bounded — it adds at most a handful of rows per frame.
        var guardCount = 0
        while nextRowY > cam.position.y - size.height && guardCount < 40 {
            addRow()
            guardCount += 1
        }
        // Drop rows that have scrolled well above the view.
        let cullY = cam.position.y + size.height * 0.9
        for b in bricks where b.position.y > cullY { b.removeFromParent() }
        bricks.removeAll { $0.parent == nil }

        // Loss: rolled off the side, or fell past all the terrain below.
        let offSide = hex.position.x < -cellW || hex.position.x > size.width + cellW
        let fellThrough = hex.position.y < cam.position.y - size.height * 0.75
        if offSide || fellThrough {
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
}
