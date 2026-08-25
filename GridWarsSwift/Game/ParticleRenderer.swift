@preconcurrency import SpriteKit

@MainActor
final class ParticleRenderer {
    let node = SKNode()

    private var lines: [SKShapeNode]
    private var sprites: [SKSpriteNode]
    private var graphicsSetIndex = 0

    init(capacity: Int = 2_048) {
        let texture = OriginalGraphics.texture(named: "particle", setIndex: 0)
        var createdLines: [SKShapeNode] = []
        createdLines.reserveCapacity(capacity)
        for _ in 0..<capacity {
            let line = SKShapeNode()
            line.blendMode = .add
            line.lineCap = .butt
            line.glowWidth = 0
            line.isHidden = true
            node.addChild(line)
            createdLines.append(line)
        }
        var created: [SKSpriteNode] = []
        created.reserveCapacity(capacity)
        for _ in 0..<capacity {
            let sprite = SKSpriteNode(texture: texture)
            sprite.blendMode = .add
            sprite.colorBlendFactor = 1
            sprite.isHidden = true
            node.addChild(sprite)
            created.append(sprite)
        }
        lines = createdLines
        sprites = created
    }

    func setGraphicsSet(_ setIndex: Int) {
        guard setIndex != graphicsSetIndex else { return }
        graphicsSetIndex = setIndex
        let texture = OriginalGraphics.texture(named: "particle", setIndex: setIndex)
        for sprite in sprites { sprite.texture = texture }
    }

    func render(_ simulation: ParticleSimulation, style: Int = 0) {
        ensureCapacity(simulation.activeCount)
        var visualIndex = 0
        for particle in simulation.particles where particle.activeFrames > 0 {
            let line = lines[visualIndex]
            let sprite = sprites[visualIndex]

            let color = boostedColor(particle.color, multiplier: style == 2 ? 1.5 : 1.25)

            switch style {
            case 0, 1:
                sprite.isHidden = true
                configureLine(line, particle: particle, color: color, style: style)
            case 2:
                line.isHidden = true
                sprite.color = color
                sprite.isHidden = false
                sprite.position = CGPoint(
                    x: particle.position.x + particle.velocity.dx,
                    y: particle.position.y + particle.velocity.dy
                )
                sprite.size = CGSize(width: 7.5, height: 7.5)
                sprite.zRotation = 0
                sprite.alpha = 1
            case 3:
                configureLine(line, particle: particle, color: color, style: style)
                sprite.color = color
                sprite.isHidden = false
                sprite.position = CGPoint(
                    x: particle.position.x + particle.velocity.dx,
                    y: particle.position.y + particle.velocity.dy
                )
                sprite.size = CGSize(
                    width: max(0.1, particle.velocity.length * 6),
                    height: 18
                )
                sprite.zRotation = atan(particle.velocity.dy / particle.velocity.dx)
                sprite.alpha = 0.25
            default:
                line.isHidden = true
                sprite.isHidden = true
            }
            visualIndex += 1
        }
        if visualIndex < sprites.count {
            for index in visualIndex..<sprites.count {
                lines[index].isHidden = true
                sprites[index].isHidden = true
            }
        }
    }

    func hideAll() {
        for line in lines { line.isHidden = true }
        for sprite in sprites { sprite.isHidden = true }
    }

    private func ensureCapacity(_ requestedCapacity: Int) {
        guard requestedCapacity > sprites.count else { return }
        let texture = OriginalGraphics.texture(named: "particle", setIndex: graphicsSetIndex)
        for _ in sprites.count..<requestedCapacity {
            let line = SKShapeNode()
            line.blendMode = .add
            line.lineCap = .butt
            line.glowWidth = 0
            line.isHidden = true
            node.insertChild(line, at: lines.count)
            lines.append(line)

            let sprite = SKSpriteNode(texture: texture)
            sprite.blendMode = .add
            sprite.colorBlendFactor = 1
            sprite.isHidden = true
            node.addChild(sprite)
            sprites.append(sprite)
        }
    }

    private func configureLine(
        _ line: SKShapeNode,
        particle: ParticleState,
        color: SKColor,
        style: Int
    ) {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(
            to: CGPoint(
                x: particle.velocity.dx * 2,
                y: particle.velocity.dy * 2
            )
        )
        line.path = path
        line.position = style != 2
            ? OriginalLineRasterRule.scenePixelCenter(particle.position)
            : particle.position
        line.strokeColor = color
        line.lineWidth = style == 0 ? 1 : 2
        line.alpha = style == 0
            ? 1
            : OriginalBlendRule.spriteKitAdditiveNodeAlpha(
                sourceAlpha: style == 1 ? 0.9 : 0.8
            )
        line.isHidden = false
    }

    private func boostedColor(_ color: ParticleColor, multiplier: CGFloat) -> SKColor {
        SKColor(
            red: CGFloat(min(255, Int(CGFloat(color.red) * multiplier))) / 255,
            green: CGFloat(min(255, Int(CGFloat(color.green) * multiplier))) / 255,
            blue: CGFloat(min(255, Int(CGFloat(color.blue) * multiplier))) / 255,
            alpha: 1
        )
    }
}
