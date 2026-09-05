//
//  BlockTowerScene.swift
//  Docked
//
//  "Block Tower" — a real tetromino piece hovers a short, fixed distance
//  above the top of the tower you're building; drag to slide it (two faint
//  vertical guide lines show where it'll come down), lift to drop it. Real
//  SpriteKit physics — slow and very forgiving — decides whether the stack
//  holds.
//
//  There's a visible stone platform sitting on a pedestal in the water near
//  the bottom: that's "the ground". The first couple of pieces get a free
//  pass while the base forms; after that, a run ends only when a piece
//  actually falls back down and touches that platform. Merely tipping while
//  still resting somewhere on the pile does not.
//
//  A camera keeps the top of the tower framed at roughly the middle of the
//  screen — you always see the highest piece plus a good stretch below it,
//  and the view glides up a little each time a piece lands. The camera only
//  ever rises.
//

import SpriteKit

final class BlockTowerScene: SKScene {
    var onScoreChange: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onLand: (() -> Void)?

    private(set) var score = 0
    private(set) var isOver = false

    private var current: SKNode?
    private var placed: [SKNode] = []
    private var floorTopY: CGFloat = 0
    private var guideLeft: SKShapeNode?
    private var guideRight: SKShapeNode?
    private var dashLine: SKShapeNode?
    private var cam: SKCameraNode!

    /// Fixed world-space gap from the tower top up to where a new piece hovers.
    private var hoverGap: CGFloat { size.height * 0.22 }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -4.2)   // slow + forgiving
        let camera = SKCameraNode()
        self.camera = camera
        cam = camera
        addChild(camera)
        reset()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard cam != nil else { return }   // not presented yet — didMove will build
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            reset()
        }
    }

    func reset() {
        guard cam != nil, size.width > 10, size.height > 10 else { return }
        removeAllChildren()
        addChild(cam)                       // removeAllChildren took the camera too
        placed = []
        current = nil
        score = 0
        isOver = false
        physicsWorld.speed = 1
        onScoreChange?(0)
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)

        buildGround()
        buildGuides()
        spawnPiece()
    }

    // MARK: scenery

    private func buildGround() {
        floorTopY = size.height * 0.30

        // Water — oversized so it always covers everything below the platform,
        // however far down the camera can see at the start.
        let water = SKShapeNode(rectOf: CGSize(width: size.width * 3, height: size.height * 6))
        water.fillColor = SKColor(red: 0.36, green: 0.79, blue: 0.92, alpha: 1)
        water.strokeColor = .clear
        water.position = CGPoint(x: size.width / 2, y: size.height * 0.14 - size.height * 3)
        water.zPosition = -20
        addChild(water)

        // Pedestal the platform stands on.
        let pedW = size.width * 0.22
        let pedH = floorTopY
        let pedestal = SKShapeNode(rectOf: CGSize(width: pedW, height: pedH), cornerRadius: 6)
        pedestal.fillColor = SKColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
        pedestal.strokeColor = SKColor.white.withAlphaComponent(0.15)
        pedestal.lineWidth = 1
        pedestal.position = CGPoint(x: size.width / 2, y: pedH / 2)
        pedestal.zPosition = -10
        addChild(pedestal)

        // The platform: visible, and the solid thing pieces land on.
        let platW = size.width * 0.55
        let platH: CGFloat = max(12, size.height * 0.03)
        let platform = SKShapeNode(rectOf: CGSize(width: platW, height: platH), cornerRadius: 3)
        platform.fillColor = SKColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 1)
        platform.strokeColor = SKColor.white.withAlphaComponent(0.25)
        platform.lineWidth = 1
        platform.position = CGPoint(x: size.width / 2, y: floorTopY - platH / 2)
        platform.zPosition = 1
        // Physics body spans wider than the visual so nothing squeaks past a corner.
        platform.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 2, height: platH))
        platform.physicsBody?.isDynamic = false
        platform.physicsBody?.friction = 1
        addChild(platform)
    }

    private func buildGuides() {
        let left = SKShapeNode()
        left.strokeColor = SKColor.white.withAlphaComponent(0.22)
        left.lineWidth = 2
        left.zPosition = 5
        left.isHidden = true
        addChild(left)
        guideLeft = left

        let right = SKShapeNode()
        right.strokeColor = SKColor.white.withAlphaComponent(0.22)
        right.lineWidth = 2
        right.zPosition = 5
        right.isHidden = true
        addChild(right)
        guideRight = right

        let dash = SKShapeNode()
        dash.strokeColor = SKColor.white.withAlphaComponent(0.3)
        dash.lineWidth = 1.5
        dash.zPosition = 5
        addChild(dash)
        dashLine = dash
    }

    /// Bigger blocks — easier to see and to place with intent.
    private func cellSize() -> CGFloat { min(42, size.width * 0.17) }

    private func currentStackTopY() -> CGFloat {
        placed.map { $0.calculateAccumulatedFrame().maxY }.max() ?? floorTopY
    }

    private func spawnPiece() {
        guard !isOver else { return }
        let cell = cellSize()
        let shape = TetrominoShape.allCases.randomElement()!
        let color = TetrominoBuilder.palette[score % TetrominoBuilder.palette.count]
        let node = TetrominoBuilder.makeNode(shape: shape, cell: cell, color: color)

        let h = CGFloat(shape.rowSpan) * cell
        let hoverY = currentStackTopY() + hoverGap + h / 2
        node.position = CGPoint(x: size.width / 2, y: hoverY)
        node.name = "hovering"
        node.zPosition = 100
        // Kinematic while hovering — must not react to gravity until released.
        node.physicsBody?.isDynamic = false
        node.physicsBody?.friction = 1.0
        node.physicsBody?.restitution = 0
        node.physicsBody?.angularDamping = 0.95
        node.physicsBody?.linearDamping = 0.5
        addChild(node)
        current = node

        // Dashed drop line, midway between the tower top and the hovering piece.
        let lineY = currentStackTopY() + hoverGap * 0.55
        let dash = CGMutablePath()
        var x = size.width * 0.06
        while x < size.width * 0.94 {
            dash.move(to: CGPoint(x: x, y: lineY))
            dash.addLine(to: CGPoint(x: min(x + 10, size.width * 0.94), y: lineY))
            x += 18
        }
        dashLine?.path = dash

        updateGuides()
    }

    /// Called continuously while dragging — the piece just follows x.
    func moveCurrent(toX x: CGFloat) {
        guard let node = current, !isOver else { return }
        let half = node.calculateAccumulatedFrame().width / 2
        node.position.x = min(max(x, half), size.width - half)
        updateGuides()
    }

    private func updateGuides() {
        guard let node = current else {
            guideLeft?.isHidden = true
            guideRight?.isHidden = true
            return
        }
        let f = node.calculateAccumulatedFrame()
        // Only draw the guide across the gap the piece will actually fall —
        // from just under it down to the current top of the pile — so a tall
        // tower doesn't get a full-height line painted over it.
        let bottomY = min(f.minY - 4, currentStackTopY())
        guideLeft?.isHidden = false
        guideRight?.isHidden = false
        for (guide, gx) in [(guideLeft, f.minX), (guideRight, f.maxX)] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: gx, y: bottomY))
            p.addLine(to: CGPoint(x: gx, y: f.minY))
            guide?.path = p
        }
    }

    func dropCurrent() {
        guard let node = current, !isOver else { return }
        current = nil
        guideLeft?.isHidden = true
        guideRight?.isHidden = true
        dashLine?.isHidden = true
        node.physicsBody?.isDynamic = true
        node.name = "placed"
        placed.append(node)
        score += 1
        onScoreChange?(score)
        onLand?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, !self.isOver else { return }
            self.dashLine?.isHidden = false
            self.spawnPiece()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, cam != nil else { return }

        // Camera keeps the top of the tower ~45% down the screen. It rises to
        // follow a growing tower and never drops back.
        let topY = currentStackTopY()
        let desiredY = max(size.height / 2, topY - size.height * 0.05)
        let stepped = cam.position.y + (desiredY - cam.position.y) * 0.08
        cam.position.y = max(cam.position.y, stepped)

        // Loss: a piece past the first couple actually falls back to the
        // platform. A wobble that resettles somewhere up the pile is fine.
        let hitGround = placed.count > 2 && placed.dropFirst(2).contains {
            $0.calculateAccumulatedFrame().minY < floorTopY + 4
        }
        if hitGround {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
            runLoseAnimation()
        }
    }

    /// A quick red flash + camera shake instead of the screen just freezing.
    /// SKActions keep running even with `physicsWorld.speed` at 0.
    private func runLoseAnimation() {
        let flash = SKShapeNode(rectOf: CGSize(width: size.width * 2.4, height: size.height * 2.4))
        flash.fillColor = SKColor.red
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 500
        flash.position = .zero            // camera-space centre of the viewport
        cam.addChild(flash)
        flash.run(.sequence([.fadeAlpha(to: 0.32, duration: 0.05),
                             .fadeAlpha(to: 0, duration: 0.5),
                             .removeFromParent()]))
        cam.run(.sequence([
            .moveBy(x: 7, y: 0, duration: 0.035), .moveBy(x: -14, y: 0, duration: 0.045),
            .moveBy(x: 12, y: 0, duration: 0.045), .moveBy(x: -8, y: 0, duration: 0.045),
            .moveBy(x: 3, y: 0, duration: 0.04), .moveBy(x: 0, y: 0, duration: 0.01),
        ]))
    }
}
