//
//  BlockTowerScene.swift
//  Docked
//
//  "Block Tower" — a small tetromino hovers well above the tower; drag to
//  slide it, lift to drop. The moment a piece lands and stops it FREEZES
//  solid with a quick highlight — the built tower can never topple after
//  that, only the piece in the air can still go wrong. Drop a piece clear
//  off the side and it's a loss.
//
//  Every 10 pieces a free flat platform locks onto the current tip to give
//  you a fresh surface. Faint height markers scroll by in the background.
//  A stone platform in the water is "the ground"; a piece that falls back to
//  it after the first couple ends the run.
//

import SpriteKit

final class BlockTowerScene: SKScene {
    var onScoreChange: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onLand: (() -> Void)?       // fired the instant a piece is dropped
    var onLock: (() -> Void)?       // fired when a piece freezes into place

    private(set) var score = 0
    private(set) var isOver = false

    private var current: SKNode?
    private var placed: [SKNode] = []
    private var floorTopY: CGFloat = 0
    private var cam: SKCameraNode!
    private var previewNode: SKNode?
    private var nextShape: TetrominoShape = .o

    private var camTargetY: CGFloat = 0
    private var awaitingSettle = false
    private var settledFrames = 0
    private var awaitSince: TimeInterval = 0
    private var lastPieceY: CGFloat = .greatestFiniteMagnitude

    private var milestoneDone = 0
    private var nextMarkerY: CGFloat = 0
    private var markerFloor = 0
    private var markers: [SKNode] = []

    private var hoverGap: CGFloat { size.height * 0.30 }
    private func cellSize() -> CGFloat { min(30, size.width * 0.125) }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -11)
        let camera = SKCameraNode()
        self.camera = camera
        cam = camera
        addChild(camera)
        reset()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard cam != nil else { return }
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            reset()
        }
    }

    func reset() {
        guard cam != nil, size.width > 10, size.height > 10 else { return }
        removeAllChildren()
        addChild(cam)
        placed = []
        markers = []
        current = nil
        score = 0
        isOver = false
        awaitingSettle = false
        settledFrames = 0
        awaitSince = 0
        milestoneDone = 0
        physicsWorld.speed = 1
        onScoreChange?(0)
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        camTargetY = size.height / 2

        buildGround()
        nextMarkerY = floorTopY + markerSpacing
        markerFloor = 10
        buildPreview()
        nextShape = TetrominoShape.allCases.randomElement()!
        refreshPreview()
        spawnPiece()
    }

    private var markerSpacing: CGFloat { cellSize() * 10 }

    // MARK: scenery

    private func buildGround() {
        floorTopY = size.height * 0.30

        let water = SKShapeNode(rectOf: CGSize(width: size.width * 3, height: size.height * 6))
        water.fillColor = SKColor(red: 0.36, green: 0.79, blue: 0.92, alpha: 1)
        water.strokeColor = .clear
        water.position = CGPoint(x: size.width / 2, y: size.height * 0.14 - size.height * 3)
        water.zPosition = -20
        addChild(water)

        let pedW = size.width * 0.22
        let pedestal = SKShapeNode(rectOf: CGSize(width: pedW, height: floorTopY), cornerRadius: 6)
        pedestal.fillColor = SKColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
        pedestal.strokeColor = SKColor.white.withAlphaComponent(0.15)
        pedestal.lineWidth = 1
        pedestal.position = CGPoint(x: size.width / 2, y: floorTopY / 2)
        pedestal.zPosition = -10
        addChild(pedestal)

        let platW = size.width * 0.55
        let platH: CGFloat = max(12, size.height * 0.03)
        let platform = SKShapeNode(rectOf: CGSize(width: platW, height: platH), cornerRadius: 3)
        platform.fillColor = SKColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 1)
        platform.strokeColor = SKColor.white.withAlphaComponent(0.25)
        platform.lineWidth = 1
        platform.position = CGPoint(x: size.width / 2, y: floorTopY - platH / 2)
        platform.zPosition = 1
        platform.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: platW, height: platH))
        platform.physicsBody?.isDynamic = false
        platform.physicsBody?.friction = 1
        addChild(platform)
    }

    /// A free, permanently-locked flat bar on top of the current tip.
    private func addMilestonePlatform(atY y: CGFloat, label: Int) {
        let w = cellSize() * 5.5
        let bar = SKShapeNode(rectOf: CGSize(width: w, height: cellSize() * 0.6), cornerRadius: 3)
        bar.fillColor = SKColor(red: 0.36, green: 0.40, blue: 0.47, alpha: 1)
        bar.strokeColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 0.9)
        bar.lineWidth = 2
        bar.position = CGPoint(x: size.width / 2, y: y)
        bar.zPosition = 8
        bar.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: w, height: cellSize() * 0.6))
        bar.physicsBody?.isDynamic = false
        bar.physicsBody?.friction = 1
        addChild(bar)
        placed.append(bar)                       // counts as solid tower

        let tag = SKLabelNode(text: "\(label)")
        tag.fontName = "AvenirNext-Bold"
        tag.fontSize = cellSize() * 0.7
        tag.fontColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        tag.verticalAlignmentMode = .center
        tag.position = CGPoint(x: size.width / 2 + w / 2 + cellSize(), y: y)
        tag.zPosition = 8
        addChild(tag)
    }

    // MARK: height markers

    private func extendMarkers() {
        let ceiling = cam.position.y + size.height
        var guardN = 0
        while nextMarkerY < ceiling && guardN < 20 {
            guardN += 1
            let line = SKShapeNode(rectOf: CGSize(width: size.width * 1.6, height: 1))
            line.fillColor = SKColor.white.withAlphaComponent(0.06)
            line.strokeColor = .clear
            line.position = CGPoint(x: size.width / 2, y: nextMarkerY)
            line.zPosition = -5
            addChild(line)

            let n = SKLabelNode(text: "\(markerFloor)")
            n.fontName = "AvenirNext-Bold"
            n.fontSize = cellSize() * 0.55
            n.fontColor = SKColor.white.withAlphaComponent(0.12)
            n.verticalAlignmentMode = .center
            n.position = CGPoint(x: cellSize() * 1.2, y: nextMarkerY)
            n.zPosition = -5
            addChild(n)

            markers.append(line); markers.append(n)
            nextMarkerY += markerSpacing
            markerFloor += 10
        }
        let floorCull = cam.position.y - size.height * 1.5
        markers.removeAll { m in
            if m.position.y < floorCull { m.removeFromParent(); return true }
            return false
        }
    }

    // MARK: preview

    private func buildPreview() {
        let node = SKNode()
        node.zPosition = 400
        cam.addChild(node)
        previewNode = node
    }

    private func refreshPreview() {
        guard let node = previewNode else { return }
        node.removeAllChildren()
        let cell = cellSize() * 0.42
        let cells = nextShape.cells
        let rows = nextShape.rowSpan, cols = nextShape.colSpan
        let ox = -CGFloat(cols) * cell / 2
        let oy = CGFloat(rows) * cell / 2
        for (r, c) in cells {
            let sq = SKShapeNode(rectOf: CGSize(width: cell - 1, height: cell - 1), cornerRadius: 2)
            sq.fillColor = TetrominoBuilder.palette[(score + 1) % TetrominoBuilder.palette.count]
            sq.strokeColor = SKColor.white.withAlphaComponent(0.3)
            sq.position = CGPoint(x: ox + CGFloat(c) * cell + cell / 2,
                                  y: oy - CGFloat(r) * cell - cell / 2)
            node.addChild(sq)
        }
        // top-right of the viewport
        node.position = CGPoint(x: size.width / 2 - cellSize() * 2.2,
                                y: size.height / 2 - cellSize() * 2.2)
    }

    // MARK: pieces

    private func currentStackTopY() -> CGFloat {
        placed.map { $0.calculateAccumulatedFrame().maxY }.max() ?? floorTopY
    }

    private func spawnPiece() {
        guard !isOver else { return }
        let cell = cellSize()
        let shape = nextShape
        nextShape = TetrominoShape.allCases.randomElement()!
        refreshPreview()

        let color = TetrominoBuilder.palette[score % TetrominoBuilder.palette.count]
        let node = TetrominoBuilder.makeNode(shape: shape, cell: cell, color: color)
        let h = CGFloat(shape.rowSpan) * cell
        node.position = CGPoint(x: size.width / 2, y: currentStackTopY() + hoverGap + h / 2)
        node.name = "hovering"
        node.zPosition = 100
        node.physicsBody?.isDynamic = false
        node.physicsBody?.friction = 1.0
        node.physicsBody?.restitution = 0
        node.physicsBody?.angularDamping = 0.55       // tips more readily
        node.physicsBody?.linearDamping = 0.02        // barely any air drag — it must fall
        addChild(node)
        current = node
    }

    func moveCurrent(toX x: CGFloat) {
        guard let node = current, !isOver else { return }
        let half = node.calculateAccumulatedFrame().width / 2
        node.position.x = min(max(x, half), size.width - half)
    }

    func dropCurrent() {
        guard let node = current, !isOver else { return }
        current = nil
        node.physicsBody?.isDynamic = true
        node.name = "placed"
        node.zPosition = 10
        placed.append(node)
        score += 1
        onScoreChange?(score)
        onLand?()
        awaitingSettle = true
        settledFrames = 0
        awaitSince = 0
        lastPieceY = .greatestFiniteMagnitude
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, cam != nil else { return }
        extendMarkers()

        if awaitingSettle, let piece = placed.last {
            if awaitSince == 0 { awaitSince = currentTime }
            let elapsed = currentTime - awaitSince
            let f = piece.calculateAccumulatedFrame()

            // Fell clear off the side or back down to the ground → loss.
            let offSide = f.maxX < 4 || f.minX > size.width - 4
            let onGround = f.minY < floorTopY + 4
            if placed.count > 2, offSide || onGround {
                endRun()
                return
            }

            // Settle by vertical travel between frames, NOT raw velocity — a
            // freshly-dropped piece reads ~0 velocity on its first frame before
            // gravity takes hold, which used to freeze it in mid-air.
            let movedY = lastPieceY == .greatestFiniteMagnitude
                ? CGFloat.greatestFiniteMagnitude
                : abs(f.midY - lastPieceY)
            lastPieceY = f.midY
            let spin = abs(piece.physicsBody?.angularVelocity ?? 0)
            let creeping = movedY < 0.25 && spin < 0.06
            settledFrames = creeping ? settledFrames + 1 : 0

            // Never lock in the first ~0.45s: the piece has to be allowed to fall.
            if elapsed > 0.45, settledFrames >= 8 || elapsed > 3.5 {
                lockPiece(piece)
                let m = (score / 10) * 10
                if m > milestoneDone {
                    addMilestonePlatform(atY: currentStackTopY() + cellSize() * 1.2, label: m)
                    milestoneDone = m
                }
                camTargetY = max(camTargetY,
                                 min(currentStackTopY() + size.height * 0.05, camTargetY + cellSize() * 4))
                awaitingSettle = false
                settledFrames = 0
                awaitSince = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
                    guard let self, !self.isOver, self.current == nil else { return }
                    self.spawnPiece()
                }
            }
        }

        camTargetY = max(camTargetY, size.height / 2)
        cam.position.y = max(cam.position.y, cam.position.y + (camTargetY - cam.position.y) * 0.12)

        // Backstop: any settled piece beyond the base that ends up on the
        // ground (e.g. a slow slide-off) also ends the run.
        if placed.count > 3,
           placed.dropFirst(3).contains(where: { $0.calculateAccumulatedFrame().minY < floorTopY + 4 }) {
            endRun()
        }
    }

    private func lockPiece(_ piece: SKNode) {
        piece.physicsBody?.isDynamic = false
        onLock?()
        let pulse = SKShapeNode(rect: piece.calculateAccumulatedFrame().insetBy(dx: -3, dy: -3), cornerRadius: 4)
        pulse.strokeColor = SKColor.white
        pulse.lineWidth = 3
        pulse.fillColor = .clear
        pulse.zPosition = 20
        pulse.alpha = 0.9
        addChild(pulse)
        pulse.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
    }

    private func endRun() {
        guard !isOver else { return }
        isOver = true
        physicsWorld.speed = 0
        onGameOver?()
        runLoseAnimation()
    }

    private func runLoseAnimation() {
        let flash = SKShapeNode(rectOf: CGSize(width: size.width * 2.4, height: size.height * 2.4))
        flash.fillColor = SKColor.red
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 500
        flash.position = .zero
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
