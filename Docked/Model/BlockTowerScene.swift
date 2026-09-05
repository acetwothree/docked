//
//  BlockTowerScene.swift
//  Docked
//
//  "Block Tower" — a real tetromino piece hovers near the top; drag to slide
//  it (two faint guide lines show where it'll come down), release (or the
//  view's gesture) to drop it. Real SpriteKit physics — slow and very
//  forgiving, tuned for "satisfying to stack" over "punishing" — decides
//  whether the stack holds. The run only ends when a piece actually touches
//  the visible ground platform (any piece after the first two) — merely
//  tipping while still resting somewhere on the pile doesn't. A camera
//  follows the tower up as it grows, so the next piece always hovers well
//  above whatever's already been placed instead of getting cramped against
//  the top of the screen.
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
    private var floorTopY: CGFloat = 6
    private var guideLeft: SKShapeNode?
    private var guideRight: SKShapeNode?
    private var cam: SKCameraNode!

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -4.2)   // slower still — very forgiving
        let camera = SKCameraNode()
        self.camera = camera
        cam = camera
        addChild(camera)
        reset()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Guard against SwiftUI setting `scene.size` before SpriteKit has
        // actually presented the scene and called `didMove(to:)` (the moment
        // `cam` is created) — the same early-size-change trap that crashed
        // Hex Fall. `didMove` builds the board itself once it does fire.
        guard cam != nil else { return }
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            reset()
        }
    }

    func reset() {
        // `reset()` is public (the toolbar's reset button calls it directly)
        // and this force-unwraps `cam` further down — bail out if it's
        // somehow called before `didMove(to:)` has created the camera.
        guard cam != nil else { return }
        removeAllChildren()
        // The camera is a scene-graph node too — `removeAllChildren()` just
        // took it out along with everything else. Put it right back.
        addChild(cam)
        placed = []
        current = nil
        score = 0
        isOver = false
        onScoreChange?(0)
        physicsWorld.speed = 1
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        guard size.width > 10, size.height > 10 else { return }

        // A visible platform, not just an invisible collider — it's obvious
        // where "the real ground" is and when a piece has actually hit it.
        let platformH: CGFloat = 14
        let platform = SKShapeNode(rectOf: CGSize(width: size.width, height: platformH))
        platform.fillColor = SKColor(red: 0.16, green: 0.17, blue: 0.2, alpha: 1)
        platform.strokeColor = SKColor.white.withAlphaComponent(0.2)
        platform.lineWidth = 1
        platform.position = CGPoint(x: size.width / 2, y: platformH / 2)
        platform.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 2, height: platformH))
        platform.physicsBody?.isDynamic = false
        addChild(platform)
        floorTopY = platformH

        let left = SKShapeNode(rectOf: CGSize(width: 2, height: 10))
        left.fillColor = SKColor.white.withAlphaComponent(0.25)
        left.strokeColor = .clear
        left.zPosition = 5
        left.isHidden = true
        addChild(left)
        guideLeft = left
        let right = SKShapeNode(rectOf: CGSize(width: 2, height: 10))
        right.fillColor = SKColor.white.withAlphaComponent(0.25)
        right.strokeColor = .clear
        right.zPosition = 5
        right.isHidden = true
        addChild(right)
        guideRight = right

        spawnPiece()
    }

    /// Bigger blocks — easier to see and to place with intent.
    private func cellSize() -> CGFloat { min(34, size.width * 0.15) }

    private func spawnPiece() {
        let cell = cellSize()
        let shape = TetrominoShape.allCases.randomElement()!
        let color = TetrominoBuilder.palette[score % TetrominoBuilder.palette.count]
        let node = TetrominoBuilder.makeNode(shape: shape, cell: cell, color: color)
        // Hover near the top of the CAMERA's current viewport, not a fixed
        // point in the scene — as the camera pans up to follow a growing
        // tower, this keeps the next piece just as far above the pile every
        // time instead of getting squeezed against the screen's top edge.
        let h = CGFloat(shape.rowSpan) * cell
        let topEdge = cam.position.y + size.height / 2
        let hoverY = topEdge - h / 2 - 16
        node.position = CGPoint(x: size.width / 2, y: hoverY)
        node.name = "hovering"
        node.zPosition = 100
        // Kinematic while hovering — TetrominoBuilder's body is dynamic by
        // default (fine once dropped), but it must NOT fall or react to
        // gravity/collisions until the player releases it.
        node.physicsBody?.isDynamic = false
        node.physicsBody?.friction = 1.0
        node.physicsBody?.restitution = 0
        node.physicsBody?.angularDamping = 0.95
        node.physicsBody?.linearDamping = 0.5
        addChild(node)
        current = node
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
        let h = max(4, f.minY - floorTopY)
        let midY = floorTopY + h / 2
        guideLeft?.isHidden = false
        guideRight?.isHidden = false
        guideLeft?.path = CGPath(roundedRect: CGRect(x: -1, y: -h / 2, width: 2, height: h), cornerWidth: 1, cornerHeight: 1, transform: nil)
        guideLeft?.position = CGPoint(x: f.minX, y: midY)
        guideRight?.path = CGPath(roundedRect: CGRect(x: -1, y: -h / 2, width: 2, height: h), cornerWidth: 1, cornerHeight: 1, transform: nil)
        guideRight?.position = CGPoint(x: f.maxX, y: midY)
    }

    func dropCurrent() {
        guard let node = current, !isOver else { return }
        current = nil
        guideLeft?.isHidden = true
        guideRight?.isHidden = true
        // Switch the same compound body from kinematic (hovering) to
        // dynamic — that's what lets it actually fall now.
        node.physicsBody?.isDynamic = true
        node.name = "placed"
        placed.append(node)
        score += 1
        onScoreChange?(score)
        onLand?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.spawnNext()
        }
    }

    private func spawnNext() {
        guard !isOver else { return }
        spawnPiece()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, cam != nil else { return }

        // Camera smoothly pans UP as the tower grows, keeping the top of the
        // pile a comfortable distance below the hovering piece rather than
        // right up against the screen's top edge. It only ever rises.
        let highestTop = max(placed.map { $0.calculateAccumulatedFrame().maxY }.max() ?? floorTopY, floorTopY)
        let desiredY = max(size.height / 2, highestTop + size.height * 0.38)
        cam.position.y += (desiredY - cam.position.y) * 0.06

        // The only way this ends: a piece — beyond the first couple, which
        // get a free pass while the base is still forming — actually rests
        // on the ground platform. Merely tipping while still somewhere on
        // the pile is not a loss; real physics is forgiving enough to let a
        // wobble settle back down.
        let hitGround = placed.count > 2 && placed.dropFirst(2).contains {
            $0.calculateAccumulatedFrame().minY < floorTopY + 3
        }
        if hitGround {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
            runLoseAnimation()
        }
    }

    /// A quick, simple "something happened" beat instead of the screen just
    /// freezing solid — a red flash and a little camera shake. Runs via
    /// SKActions, which keep animating even with `physicsWorld.speed` at 0.
    private func runLoseAnimation() {
        let flash = SKShapeNode(rectOf: CGSize(width: size.width * 2.4, height: size.height * 2.4))
        flash.fillColor = SKColor.red
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 500
        flash.position = .zero   // camera-space: (0,0) is the center of the viewport
        cam.addChild(flash)
        flash.run(.sequence([.fadeAlpha(to: 0.32, duration: 0.05), .fadeAlpha(to: 0, duration: 0.5), .removeFromParent()]))

        cam.run(.sequence([
            .moveBy(x: 7, y: 0, duration: 0.035), .moveBy(x: -14, y: 0, duration: 0.045),
            .moveBy(x: 12, y: 0, duration: 0.045), .moveBy(x: -8, y: 0, duration: 0.045),
            .moveBy(x: 3, y: 0, duration: 0.04), .moveBy(x: 0, y: 0, duration: 0.01),
        ]))
    }
}
