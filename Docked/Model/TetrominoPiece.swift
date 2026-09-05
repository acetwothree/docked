//
//  TetrominoPiece.swift
//  Docked
//
//  Shared tetromino cell shapes + a SpriteKit builder that turns one into a
//  single node made of `cell`-sized squares with ONE compound physics body
//  covering exactly that silhouette — a genuine tetromino, not a plain
//  rectangle standing in for one. Used by both Hex Fall and Block Tower.
//

import SpriteKit

enum TetrominoShape: CaseIterable {
    case i, o, t, s, z, j, l

    /// Cells as (row, col) offsets, row 0 at the top.
    var cells: [(row: Int, col: Int)] {
        switch self {
        case .i: [(0, 0), (0, 1), (0, 2), (0, 3)]
        case .o: [(0, 0), (0, 1), (1, 0), (1, 1)]
        case .t: [(0, 0), (0, 1), (0, 2), (1, 1)]
        case .s: [(0, 1), (0, 2), (1, 0), (1, 1)]
        case .z: [(0, 0), (0, 1), (1, 1), (1, 2)]
        case .j: [(0, 0), (1, 0), (1, 1), (1, 2)]
        case .l: [(0, 2), (1, 0), (1, 1), (1, 2)]
        }
    }

    var rowSpan: Int { (cells.map(\.row).max() ?? 0) + 1 }
    var colSpan: Int { (cells.map(\.col).max() ?? 0) + 1 }

    /// The 2-row-tall shapes — every one except I. Stacking only these keeps
    /// a run of pieces at a uniform height, which is what makes a packed row
    /// snap together neatly instead of leaving gaps under shorter pieces.
    static var twoRow: [TetrominoShape] { [.o, .t, .s, .z, .j, .l] }
}

enum TetrominoBuilder {
    /// One node made of `cell`-sized squares in the given shape's silhouette,
    /// centred on its own origin, with a single compound physics body.
    static func makeNode(shape: TetrominoShape, cell: CGFloat, color: SKColor, gap: CGFloat = 1.5) -> SKNode {
        let node = SKNode()
        let rows = shape.rowSpan, cols = shape.colSpan
        let originX = -CGFloat(cols) * cell / 2
        let originY = CGFloat(rows) * cell / 2
        var bodies: [SKPhysicsBody] = []
        for (r, c) in shape.cells {
            let cx = originX + CGFloat(c) * cell + cell / 2
            let cy = originY - CGFloat(r) * cell - cell / 2
            let sub = SKShapeNode(rectOf: CGSize(width: cell - gap, height: cell - gap), cornerRadius: 3)
            sub.fillColor = color
            sub.strokeColor = SKColor.white.withAlphaComponent(0.25)
            sub.lineWidth = 1
            sub.position = CGPoint(x: cx, y: cy)
            node.addChild(sub)
            bodies.append(SKPhysicsBody(rectangleOf: CGSize(width: cell, height: cell), center: CGPoint(x: cx, y: cy)))
        }
        let compound = SKPhysicsBody(bodies: bodies)
        compound.friction = 0.88
        compound.restitution = 0.02
        compound.density = 1
        compound.angularDamping = 0.45
        compound.linearDamping = 0.15
        node.physicsBody = compound
        return node
    }

    static let palette: [SKColor] = [
        SKColor(red: 0.88, green: 0.28, blue: 0.24, alpha: 1),
        SKColor(red: 0.95, green: 0.54, blue: 0.24, alpha: 1),
        SKColor(red: 0.95, green: 0.73, blue: 0.05, alpha: 1),
        SKColor(red: 0.24, green: 0.81, blue: 0.48, alpha: 1),
        SKColor(red: 0.24, green: 0.63, blue: 0.88, alpha: 1),
        SKColor(red: 0.55, green: 0.36, blue: 0.97, alpha: 1),
    ]

    static func polygonPath(sides: Int, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<sides {
            // No rotational offset — for a hexagon this puts flat edges at
            // top and bottom (vertices at the sides) instead of balancing on
            // a single point.
            let angle = Double(i) / Double(sides) * 2 * .pi
            let pt = CGPoint(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
