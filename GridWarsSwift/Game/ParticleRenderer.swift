@preconcurrency import SpriteKit

@MainActor
final class ParticleRenderer {
    let node = SKNode()

    private let sprites: [SKSpriteNode]

    init(capacity: Int = 2_048) {
        let texture = SKTexture(imageNamed: "particle")
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
        sprites = created
    }

    func render(_ simulation: ParticleSimulation, style: Int = 0) {
        for index in sprites.indices {
            let sprite = sprites[index]
            guard index < simulation.particles.count else {
                sprite.isHidden = true
                continue
            }
            let particle = simulation.particles[index]
            guard particle.activeFrames > 0 else {
                sprite.isHidden = true
                continue
            }

            let redMultiplier: CGFloat = style == 2 ? 1.5 : 1.25
            sprite.color = SKColor(
                red: min(255, CGFloat(particle.color.red) * redMultiplier) / 255,
                green: min(255, CGFloat(particle.color.green) * redMultiplier) / 255,
                blue: min(255, CGFloat(particle.color.blue) * redMultiplier) / 255,
                alpha: 1
            )
            sprite.isHidden = false

            switch style {
            case 2:
                sprite.position = CGPoint(
                    x: particle.position.x + particle.velocity.dx,
                    y: particle.position.y + particle.velocity.dy
                )
                sprite.size = CGSize(width: 16, height: 16)
                sprite.zRotation = 0
                sprite.alpha = 1
            default:
                let length = max(1, particle.velocity.length)
                sprite.position = CGPoint(
                    x: particle.position.x + particle.velocity.dx / 2,
                    y: particle.position.y + particle.velocity.dy / 2
                )
                sprite.size = CGSize(
                    width: max(3, length * (style == 3 ? 2.8 : 2)),
                    height: style == 1 || style == 3 ? 4 : 2
                )
                sprite.zRotation = atan2(particle.velocity.dy, particle.velocity.dx)
                sprite.alpha = style == 1 ? 0.9 : (style == 3 ? 0.8 : 1)
            }
        }
    }

    func hideAll() {
        for sprite in sprites { sprite.isHidden = true }
    }
}
