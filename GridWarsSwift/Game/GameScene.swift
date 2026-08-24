@preconcurrency import SpriteKit

#if os(iOS)
import UIKit
#endif

@MainActor
final class GameScene: SKScene, SKPhysicsContactDelegate {
    private enum Category {
        static let player: UInt32 = 1 << 0
        static let projectile: UInt32 = 1 << 1
        static let enemy: UInt32 = 1 << 2
        static let powerUp: UInt32 = 1 << 3
    }

    private enum EnemyKind: String, CaseIterable {
        case pinwheel
        case diamond
        case greenSquare
        case cube
        case seeker
        case blackHole
        case triangle
        case snake
        case interceptor
        case butterfly

        init(_ original: OriginalEnemyKind) {
            self = EnemyKind(rawValue: String(describing: original)) ?? .pinwheel
        }

        var textureName: String {
            switch self {
            case .pinwheel: "pinkpinwheel"
            case .diamond: "bluediamond"
            case .greenSquare: "greensquare"
            case .cube: "purplesquare1"
            case .seeker: "bluecircle"
            case .blackHole: "redcircle"
            case .triangle: "orangetriangle"
            case .snake: "snakehead"
            case .interceptor: "redclone"
            case .butterfly: "indigotriangle"
            }
        }

        var size: CGSize {
            switch self {
            case .blackHole: CGSize(width: 128, height: 128)
            default: CGSize(width: 64, height: 64)
            }
        }

        var health: Int {
            switch self {
            case .pinwheel, .diamond, .greenSquare, .cube, .seeker,
                 .blackHole, .triangle, .snake, .interceptor, .butterfly:
                1
            }
        }

        var initialMagnitude: ClosedRange<CGFloat> {
            switch self {
            case .pinwheel, .snake, .interceptor: 0.5...2
            case .cube: 0.25...2
            case .diamond, .triangle: 0.25...1
            case .greenSquare: 2...4
            case .seeker, .butterfly: 3...6
            case .blackHole: 0.05...0.5
            }
        }

        var score: Int {
            switch self {
            case .pinwheel: 25
            case .diamond: 50
            case .greenSquare, .cube, .snake, .interceptor: 100
            case .seeker, .butterfly: 10
            case .blackHole, .triangle: 150
            }
        }

        var original: OriginalEnemyKind {
            OriginalEnemyKind(rawValue: EnemyKind.allCases.firstIndex(of: self) ?? 0) ?? .pinwheel
        }
    }

    private let worldLayer = SKNode()
    private let gridLayer = SKNode()
    private let enemyLayer = SKNode()
    private let projectileLayer = SKNode()
    private let pickupLayer = SKNode()
    private let effectLayer = SKNode()
    private let hudLayer = SKNode()

    private let player = SKSpriteNode(imageNamed: "whiteplayer")
    private let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let statusLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let helpLabel = SKLabelNode(fontNamed: "Menlo")
    private let messageLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let bombButton = SKShapeNode(circleOfRadius: 38)
    private let movementStick = VirtualStickNode()
    private let aimingStick = VirtualStickNode()

    private var session = GameSession()
    private var configured = false
    private var pressedKeys = Set<UInt16>()
    private var pointerLocation = CGPoint(x: 512, y: 600)
    private var hasPointerLocation = false
    private var mouseIsFiring = false
    private var touchMovement = CGVector.zero
    private var touchAim = CGVector.zero
    private var touchIsFiring = false
    private var currentAim = CGVector(dx: 0, dy: 1)

    private var lastUpdateTime: TimeInterval = 0
    private var shotTimerFrames = 0
    private var playerInvulnerableUntil: TimeInterval = 0
    private var destroyedEnemyCount = 0
    private var fixedTimeAccumulator: TimeInterval = 0
    private var simulationFrame = GameDifficulty.medium.initialFrame
    private var bombCooldownFrames = 20
    private var spawnDirector = SpawnDirector()
    private var spawnRandom = SystemRandomNumberGenerator()

    #if os(iOS)
    private var movementTouch: UITouch?
    private var aimingTouch: UITouch?
    private var movementTouchOrigin = CGPoint.zero
    private var aimingTouchOrigin = CGPoint.zero
    #endif

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
        backgroundColor = .black
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        scaleMode = .aspectFit
        backgroundColor = .black
    }

    override func didMove(to view: SKView) {
        guard !configured else { return }
        configured = true

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = nil
        setupLayers()
        setupArena()
        setupPlayer()
        setupHUD()
        restartGame()
    }

    private func setupLayers() {
        addChild(worldLayer)
        worldLayer.addChild(gridLayer)
        worldLayer.addChild(enemyLayer)
        worldLayer.addChild(projectileLayer)
        worldLayer.addChild(pickupLayer)
        worldLayer.addChild(effectLayer)
        addChild(hudLayer)

        gridLayer.zPosition = -10
        enemyLayer.zPosition = 10
        projectileLayer.zPosition = 20
        pickupLayer.zPosition = 15
        effectLayer.zPosition = 30
        hudLayer.zPosition = 100
    }

    private func setupArena() {
        let path = CGMutablePath()
        let spacing: CGFloat = 48

        stride(from: CGFloat.zero, through: size.width, by: spacing).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        stride(from: CGFloat.zero, through: size.height, by: spacing).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }

        let grid = SKShapeNode(path: path)
        grid.name = "grid"
        grid.strokeColor = SKColor(red: 0.08, green: 0.28, blue: 1, alpha: 1)
        grid.lineWidth = 0.8
        grid.glowWidth = 1.4
        grid.alpha = 0.42
        gridLayer.addChild(grid)

        for _ in 0..<140 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.45...1.4))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.18...0.72)
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            gridLayer.addChild(star)
        }

        let border = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        border.strokeColor = SKColor(red: 0.15, green: 0.45, blue: 1, alpha: 0.75)
        border.lineWidth = 3
        border.glowWidth = 3
        gridLayer.addChild(border)
    }

    private func setupPlayer() {
        player.name = "player"
        player.size = CGSize(width: 64, height: 64)
        player.blendMode = .add
        player.zPosition = 5
        player.physicsBody = SKPhysicsBody(circleOfRadius: 15)
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.categoryBitMask = Category.player
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.contactTestBitMask = Category.enemy | Category.powerUp
        worldLayer.addChild(player)
    }

    private func setupHUD() {
        scoreLabel.fontSize = 21
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: 22, y: size.height - 18)
        scoreLabel.fontColor = .white
        hudLayer.addChild(scoreLabel)

        statusLabel.fontSize = 19
        statusLabel.horizontalAlignmentMode = .right
        statusLabel.verticalAlignmentMode = .top
        statusLabel.position = CGPoint(x: size.width - 22, y: size.height - 18)
        statusLabel.fontColor = SKColor(red: 0.35, green: 0.8, blue: 1, alpha: 1)
        hudLayer.addChild(statusLabel)

        helpLabel.fontSize = 13
        helpLabel.horizontalAlignmentMode = .left
        helpLabel.verticalAlignmentMode = .bottom
        helpLabel.position = CGPoint(x: 18, y: 14)
        helpLabel.fontColor = SKColor(white: 0.7, alpha: 1)
        #if os(macOS)
        helpLabel.text = "WASD bewegen · Maus/←↑↓→ feuern · Leertaste/Rechtsklick Bombe · R Neustart"
        #else
        helpLabel.text = "Linker Stick bewegt · rechter Stick feuert"
        #endif
        hudLayer.addChild(helpLabel)

        messageLabel.fontSize = 40
        messageLabel.numberOfLines = 3
        messageLabel.preferredMaxLayoutWidth = 800
        messageLabel.horizontalAlignmentMode = .center
        messageLabel.verticalAlignmentMode = .center
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        messageLabel.fontColor = .white
        messageLabel.zPosition = 20
        messageLabel.isHidden = true
        hudLayer.addChild(messageLabel)

        bombButton.position = CGPoint(x: size.width - 62, y: 72)
        bombButton.fillColor = SKColor(red: 0.1, green: 0.2, blue: 0.55, alpha: 0.65)
        bombButton.strokeColor = SKColor(red: 0.35, green: 0.75, blue: 1, alpha: 1)
        bombButton.lineWidth = 2
        bombButton.glowWidth = 2
        #if os(macOS)
        bombButton.isHidden = true
        #endif

        let bombText = SKLabelNode(fontNamed: "Menlo-Bold")
        bombText.text = "BOMB"
        bombText.fontSize = 12
        bombText.verticalAlignmentMode = .center
        bombText.fontColor = .white
        bombButton.addChild(bombText)
        hudLayer.addChild(bombButton)

        hudLayer.addChild(movementStick)
        hudLayer.addChild(aimingStick)
    }

    private func restartGame() {
        enemyLayer.removeAllChildren()
        projectileLayer.removeAllChildren()
        pickupLayer.removeAllChildren()
        effectLayer.removeAllChildren()

        session.restart()
        spawnDirector.reset()
        destroyedEnemyCount = 0
        lastUpdateTime = 0
        shotTimerFrames = 0
        playerInvulnerableUntil = 0
        fixedTimeAccumulator = 0
        simulationFrame = session.difficulty.initialFrame
        bombCooldownFrames = 20
        player.removeAllActions()
        player.alpha = 1
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        player.isHidden = false
        messageLabel.isHidden = true
        touchMovement = .zero
        touchAim = .zero
        touchIsFiring = false
        updateHUD()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        let deltaTime = min(0.1, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        updateGrid(at: currentTime)

        guard !session.isGameOver else { return }
        fixedTimeAccumulator += deltaTime
        while fixedTimeAccumulator >= 0.02 {
            simulateFrame()
            fixedTimeAccumulator -= 0.02
        }
    }

    private func simulateFrame() {
        let spawnResult = spawnDirector.advance(
            frame: simulationFrame,
            spawningIsBlocked: bombCooldownFrames > 0,
            using: &spawnRandom
        )
        if spawnResult.shouldIncreaseEnemySpeeds {
            session.increaseEnemySpeeds()
        }
        for command in spawnResult.commands {
            execute(command)
        }

        session.tick()
        bombCooldownFrames = max(0, bombCooldownFrames - 1)
        updatePlayer(deltaTime: 0.02)
        updateAim()
        fireIfNeeded()
        pullPlayerTowardBlackHoles()
        checkTriangleBondPlayerCollision()
        updateGenerators()
        updateEnemies(kinds: [
            .greenSquare, .pinwheel, .diamond, .cube, .seeker,
            .snake, .interceptor, .butterfly, .triangle,
        ])
        updateTrianglePairsAndBonds()
        updatePowerUps()
        updateEnemies(kinds: [.blackHole])
        updateProjectiles()
        simulationFrame += 1
    }

    private func updateGrid(at currentTime: TimeInterval) {
        gridLayer.childNode(withName: "grid")?.alpha = 0.34 + 0.1 * sin(currentTime * 1.3)
    }

    private func updatePlayer(deltaTime: TimeInterval) {
        let keyboard = keyboardMovement
        let combined = keyboard.length > 0 ? keyboard : touchMovement
        let movement = combined.length > 1 ? combined.normalized : combined
        let speed: CGFloat = 285
        let margin: CGFloat = 24

        player.position.x += movement.dx * speed * deltaTime
        player.position.y += movement.dy * speed * deltaTime
        player.position.x = min(size.width - margin, max(margin, player.position.x))
        player.position.y = min(size.height - margin, max(margin, player.position.y))
    }

    private func updateAim() {
        let arrowAim = keyboardAim
        if arrowAim.length > 0 {
            currentAim = arrowAim.normalized
        } else if touchAim.length > 0 {
            currentAim = touchAim.normalized
        } else if hasPointerLocation {
            let pointerAim = CGVector(
                dx: pointerLocation.x - player.position.x,
                dy: pointerLocation.y - player.position.y
            )
            if pointerAim.length > 2 {
                currentAim = pointerAim.normalized
            }
        }

        player.zRotation = atan2(currentAim.dy, currentAim.dx) - .pi / 2
    }

    private func fireIfNeeded() {
        shotTimerFrames = max(0, shotTimerFrames - 1)
        let shouldFire = mouseIsFiring || touchIsFiring || keyboardAim.length > 0
        guard shotTimerFrames == 0 else { return }
        shotTimerFrames = 4 + session.cannons / 2
        guard shouldFire else { return }

        let baseDirection = currentAim.normalized
        if session.cannons.isMultiple(of: 2) == false {
            spawnProjectile(direction: baseDirection, speed: CGFloat(session.shotSpeed) * 3.2)
        }
        if session.cannons > 1 {
            let angle: CGFloat = session.cannons.isMultiple(of: 2) ? 2 : 4
            spawnProjectile(direction: rotated(baseDirection, degrees: angle), speed: CGFloat(session.shotSpeed) * 3.15)
            spawnProjectile(direction: rotated(baseDirection, degrees: -angle), speed: CGFloat(session.shotSpeed) * 3.15)
        }
        if session.cannons > 3 {
            spawnProjectile(direction: rotated(baseDirection, degrees: 5), speed: CGFloat(session.shotSpeed) * 3.1)
            spawnProjectile(direction: rotated(baseDirection, degrees: -5), speed: CGFloat(session.shotSpeed) * 3.1)
        }
        if session.reverseShooterFrames > 0 {
            spawnProjectile(direction: rotated(baseDirection, degrees: 180), speed: CGFloat(session.shotSpeed) * 3)
        }
        if session.sideShooterFrames > 0 {
            spawnProjectile(direction: rotated(baseDirection, degrees: 90), speed: CGFloat(session.shotSpeed) * 3)
            spawnProjectile(direction: rotated(baseDirection, degrees: -90), speed: CGFloat(session.shotSpeed) * 3)
        }
        run(.playSoundFileNamed("shotborn.wav", waitForCompletion: false))
    }

    private func spawnProjectile(direction: CGVector, speed: CGFloat) {
        guard projectileLayer.children.count < 500 else { return }
        let projectile = SKSpriteNode(imageNamed: "yellowshot")
        projectile.name = "projectile"
        projectile.size = CGSize(width: 32, height: 32)
        projectile.blendMode = .add
        projectile.position = player.position
        projectile.zRotation = atan2(direction.dy, direction.dx)
        let velocity = direction * speed
        projectile.userData = NSMutableDictionary(dictionary: [
            "dx": velocity.dx,
            "dy": velocity.dy,
            "speed": speed,
        ])
        projectileLayer.addChild(projectile)
    }

    private func rotated(_ vector: CGVector, degrees: CGFloat) -> CGVector {
        let angle = degrees * .pi / 180
        return CGVector(
            dx: vector.dx * cos(angle) - vector.dy * sin(angle),
            dy: vector.dx * sin(angle) + vector.dy * cos(angle)
        )
    }

    @discardableResult
    private func spawnEnemy(
        kind: EnemyKind,
        at position: CGPoint,
        freezeFrames: Int,
        closeToPlayer: Bool = false
    ) -> SKNode? {
        let matchingEnemyCount = enemyLayer.children.filter {
            $0.name == "enemy" && $0.userData?["kind"] as? String == kind.rawValue
        }.count
        switch kind {
        case .cube where matchingEnemyCount > 100:
            return nil
        case .blackHole where matchingEnemyCount > 3:
            return nil
        case .snake:
            let snakeNodeCount = matchingEnemyCount + enemyLayer.children.filter { $0.name == "snakeTail" }.count
            if snakeNodeCount > 16 * 24 { return nil }
        case .interceptor:
            if matchingEnemyCount > 7
                || (matchingEnemyCount > 3 && Int.random(in: 0...100) > 50) {
                return nil
            }
        default:
            break
        }

        let enemy = SKSpriteNode(imageNamed: kind.textureName)
        enemy.name = "enemy"
        enemy.size = kind.size
        enemy.blendMode = .add
        enemy.position = safePosition(position, minimumPlayerDistance: closeToPlayer ? 40 : 160)
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: min(kind.size.width, kind.size.height) * 0.38)
        enemy.physicsBody?.affectedByGravity = false
        enemy.physicsBody?.allowsRotation = false
        enemy.physicsBody?.categoryBitMask = Category.enemy
        enemy.physicsBody?.collisionBitMask = 0
        enemy.physicsBody?.contactTestBitMask = Category.player | Category.projectile
        let enemyID = UUID().uuidString
        let initialRotation = Int.random(in: 0...359)
        let initialAngle = kind == .snake
            ? CGFloat(initialRotation) * .pi / 180
            : CGFloat.random(in: 0...(2 * .pi))
        let initialMagnitude = CGFloat.random(in: kind.initialMagnitude)
        let initialVelocity = CGVector(
            dx: cos(initialAngle) * initialMagnitude,
            dy: sin(initialAngle) * initialMagnitude
        )
        let interceptorTurn = turnToFace(
            velocity: initialVelocity,
            target: CGVector(
                dx: size.width / 2 - enemy.position.x,
                dy: size.height / 2 - enemy.position.y
            )
        )
        enemy.userData = NSMutableDictionary(dictionary: [
            "enemyID": enemyID,
            "kind": kind.rawValue,
            "health": kind.health,
            "speed": session.enemySpeeds[kind.original],
            "score": kind.score,
            "phase": Double.random(in: 0...(Double.pi * 2)),
            "freezeFrames": freezeFrames,
            "rotation": initialRotation,
            "dx": initialVelocity.dx,
            "dy": initialVelocity.dy,
            "cubeTier": 0,
            "blackHoleSize": kind == .blackHole ? 20.0 : 0.0,
            "blackHoleActive": false,
            "absorbCount": 0,
            "snakeHeading": Double(initialRotation),
            "snakeTurnDirection": Int.random(in: 0...1),
            "interceptorHeading": Double(initialRotation),
            "interceptorTurnRemaining": abs(interceptorTurn) < 16
                ? (interceptorTurn < 0 ? -16 : 16)
                : interceptorTurn,
            "seekerMean": 0,
        ])
        let aura = SKShapeNode(path: generatorPath(kind: kind, radius: 12))
        aura.name = "spawnAura"
        aura.fillColor = generatorColor(for: kind).withAlphaComponent(0.35)
        aura.strokeColor = generatorColor(for: kind)
        aura.lineWidth = 1
        aura.glowWidth = 2
        aura.zPosition = -1
        enemy.addChild(aura)
        enemyLayer.addChild(enemy)
        if kind == .snake {
            spawnSnakeSegments(for: enemy, freezeFrames: freezeFrames)
        }
        return enemy
    }

    private func execute(_ command: SpawnCommand) {
        switch command {
        case let .enemy(kind, freezeFrames, corner):
            spawnEnemy(
                kind: EnemyKind(kind),
                at: position(for: corner),
                freezeFrames: freezeFrames
            )
        case let .generator(kind, freezeFrames, corner, rate, generatorSize):
            spawnGenerator(
                kind: EnemyKind(kind),
                at: position(for: corner),
                freezeFrames: freezeFrames,
                rate: rate,
                generatorSize: generatorSize
            )
        }
    }

    private func position(for corner: SpawnCorner) -> CGPoint {
        let resolved: SpawnCorner
        switch corner {
        case .anyCorner:
            resolved = [.topLeft, .topRight, .bottomRight, .bottomLeft].randomElement() ?? .topLeft
        case .topCorners:
            resolved = Bool.random() ? .topLeft : .topRight
        case .rightCorners:
            resolved = Bool.random() ? .topRight : .bottomRight
        case .bottomCorners:
            resolved = Bool.random() ? .bottomRight : .bottomLeft
        case .diagonalTopLeftBottomRight:
            resolved = Bool.random() ? .topLeft : .bottomRight
        case .leftCorners:
            resolved = Bool.random() ? .topLeft : .bottomLeft
        case .diagonalTopRightBottomLeft:
            resolved = Bool.random() ? .topRight : .bottomLeft
        default:
            resolved = corner
        }

        switch resolved {
        case .topLeft:
            return CGPoint(x: CGFloat.random(in: 30...80), y: size.height - CGFloat.random(in: 30...80))
        case .topRight:
            return CGPoint(x: size.width - CGFloat.random(in: 30...80), y: size.height - CGFloat.random(in: 30...80))
        case .bottomRight:
            return CGPoint(x: size.width - CGFloat.random(in: 30...80), y: CGFloat.random(in: 30...80))
        case .bottomLeft:
            return CGPoint(x: CGFloat.random(in: 30...80), y: CGFloat.random(in: 30...80))
        case .nearPlayer:
            let angle = CGFloat.random(in: 0...(2 * .pi))
            return CGPoint(x: player.position.x + cos(angle) * 240, y: player.position.y + sin(angle) * 240)
        default:
            return CGPoint(
                x: CGFloat.random(in: 30...(size.width - 30)),
                y: CGFloat.random(in: 30...(size.height - 30))
            )
        }
    }

    private func safePosition(_ proposed: CGPoint, minimumPlayerDistance: CGFloat) -> CGPoint {
        var result = CGPoint(
            x: min(size.width - 20, max(20, proposed.x)),
            y: min(size.height - 20, max(20, proposed.y))
        )
        var vector = CGVector(dx: result.x - player.position.x, dy: result.y - player.position.y)
        if vector.length < minimumPlayerDistance {
            if vector.length < 0.001 { vector = CGVector(dx: 1, dy: 0) }
            let offset = vector.normalized * minimumPlayerDistance
            result = CGPoint(x: player.position.x + offset.dx, y: player.position.y + offset.dy)
            result.x = min(size.width - 20, max(20, result.x))
            result.y = min(size.height - 20, max(20, result.y))
        }
        return result
    }

    private func spawnGenerator(
        kind: EnemyKind,
        at position: CGPoint,
        freezeFrames: Int,
        rate: Int,
        generatorSize: Int
    ) {
        let visualRadius = 12 + CGFloat(generatorSize) / 4
        let generator = SKShapeNode(path: generatorPath(kind: kind, radius: visualRadius))
        generator.name = "generator"
        generator.position = safePosition(position, minimumPlayerDistance: 160)
        generator.fillColor = generatorColor(for: kind).withAlphaComponent(0.1 + CGFloat(generatorSize) / 256)
        generator.strokeColor = generatorColor(for: kind)
        generator.lineWidth = 1.5
        generator.glowWidth = 2
        generator.physicsBody = SKPhysicsBody(circleOfRadius: 12 + CGFloat(generatorSize) / 2)
        generator.physicsBody?.affectedByGravity = false
        generator.physicsBody?.allowsRotation = false
        generator.physicsBody?.categoryBitMask = Category.enemy
        generator.physicsBody?.collisionBitMask = 0
        generator.physicsBody?.contactTestBitMask = Category.player | Category.projectile
        generator.userData = NSMutableDictionary(dictionary: [
            "kind": kind.rawValue,
            "health": generatorSize,
            "score": 200,
            "freezeFrames": freezeFrames,
            "rate": rate,
            "rotation": Int.random(in: 0...359),
            "generatorSize": generatorSize,
        ])
        let inner = SKShapeNode(path: generatorPath(kind: kind, radius: 8))
        inner.name = "generatorInner"
        inner.strokeColor = generatorColor(for: kind)
        inner.lineWidth = 1
        inner.glowWidth = 1
        generator.addChild(inner)
        enemyLayer.addChild(generator)
        run(.playSoundFileNamed("cat.wav", waitForCompletion: false))
    }

    private func generatorPath(kind: EnemyKind, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        switch kind {
        case .pinwheel, .diamond:
            path.move(to: CGPoint(x: 0, y: radius))
            path.addLine(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -radius))
            path.addLine(to: CGPoint(x: -radius, y: 0))
            path.closeSubpath()
        case .greenSquare, .cube, .interceptor:
            path.addRect(CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        case .triangle, .butterfly:
            path.move(to: CGPoint(x: 0, y: radius))
            path.addLine(to: CGPoint(x: radius * 0.75, y: -radius * 0.42))
            path.addLine(to: CGPoint(x: -radius * 0.75, y: -radius * 0.42))
            path.closeSubpath()
        case .seeker, .blackHole, .snake:
            path.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        }
        return path
    }

    private func generatorColor(for kind: EnemyKind) -> SKColor {
        switch kind {
        case .pinwheel: SKColor(red: 1, green: 0.2, blue: 0.75, alpha: 1)
        case .diamond: SKColor(red: 0.2, green: 0.65, blue: 1, alpha: 1)
        case .greenSquare: SKColor(red: 0.2, green: 1, blue: 0.3, alpha: 1)
        case .cube: SKColor(red: 0.72, green: 0.25, blue: 1, alpha: 1)
        case .seeker: SKColor(red: 0.2, green: 0.55, blue: 1, alpha: 1)
        case .blackHole: SKColor(red: 1, green: 0.12, blue: 0.08, alpha: 1)
        case .triangle: SKColor(red: 1, green: 0.55, blue: 0.08, alpha: 1)
        case .snake: SKColor(red: 0.25, green: 1, blue: 0.5, alpha: 1)
        case .interceptor: SKColor(red: 1, green: 0.18, blue: 0.22, alpha: 1)
        case .butterfly: SKColor(red: 0.35, green: 0.3, blue: 1, alpha: 1)
        }
    }

    private func updateGenerators() {
        for generator in enemyLayer.children where generator.name == "generator" {
            var freezeFrames = (generator.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                generator.userData?["freezeFrames"] = freezeFrames
                continue
            }

            var rotation = (generator.userData?["rotation"] as? NSNumber)?.intValue ?? 0
            rotation += 1
            generator.userData?["rotation"] = rotation
            let rate = (generator.userData?["rate"] as? NSNumber)?.intValue ?? 100
            let health = (generator.userData?["health"] as? NSNumber)?.intValue ?? 1
            let kind = EnemyKind(rawValue: generator.userData?["kind"] as? String ?? "") ?? .pinwheel
            if let shape = generator as? SKShapeNode {
                let warning = (rotation + 8) % max(1, rate + 42 - health) < 8
                shape.strokeColor = warning ? .white : generatorColor(for: kind)
                (shape.childNode(withName: "generatorInner") as? SKShapeNode)?.strokeColor =
                    warning ? .white : generatorColor(for: kind)
            }
            let collisionRadiusSquared = pow(12 + CGFloat(health) / 2, 2) + 12 * 12
            if squaredDistance(generator.position, player.position) < collisionRadiusSquared,
               hitPlayer(at: generator.position) {
                destroyEnemy(generator, playSound: false, awardPoints: false)
                continue
            }
            guard rotation.isMultiple(of: max(1, rate + 42 - health)) else { continue }
            let offset = CGPoint(
                x: generator.position.x + CGFloat.random(in: -10...10),
                y: generator.position.y + CGFloat.random(in: -10...10)
            )
            let born = spawnEnemy(kind: kind, at: offset, freezeFrames: 5, closeToPlayer: true)
            if kind == .blackHole {
                born?.userData?["blackHoleSize"] = 10.0
            }
        }
    }

    private func updateEnemies(kinds: [EnemyKind]) {
        for requestedKind in kinds {
            let enemies = enemyLayer.children.filter {
                $0.name == "enemy" && $0.userData?["kind"] as? String == requestedKind.rawValue
            }
            for enemy in enemies {
            guard enemy.parent != nil else { continue }
            var freezeFrames = (enemy.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                enemy.userData?["freezeFrames"] = freezeFrames
                updateEnemyVisual(enemy, kind: requestedKind, rotation: (enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0)
                continue
            }

            let kind = EnemyKind(rawValue: enemy.userData?["kind"] as? String ?? "") ?? .pinwheel
            var maximumSpeed = CGFloat((enemy.userData?["speed"] as? NSNumber)?.doubleValue ?? 1)
            if kind == .seeker {
                maximumSpeed += CGFloat((enemy.userData?["seekerMean"] as? NSNumber)?.intValue ?? 0)
            }
            var velocity = CGVector(
                dx: CGFloat((enemy.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((enemy.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )
            var rotation = (enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0
            rotation += kind == .interceptor ? 16 : 1

            let movesBeforeSteering: Bool = switch kind {
            case .pinwheel, .diamond, .greenSquare, .cube, .seeker, .blackHole, .butterfly:
                true
            case .triangle, .snake, .interceptor:
                false
            }
            if movesBeforeSteering {
                enemy.position.x += velocity.dx
                enemy.position.y += velocity.dy
                let margin: CGFloat = switch kind {
                case .greenSquare: 12
                case .blackHole: 16
                default: 8
                }
                bounce(enemy, velocity: &velocity, margin: margin)
            }

            let towardPlayer = CGVector(
                dx: player.position.x - enemy.position.x,
                dy: player.position.y - enemy.position.y
            ).normalized

            switch kind {
            case .pinwheel:
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .diamond:
                if Bool.random() {
                    velocity = velocity + CGVector(
                        dx: CGFloat.random(in: -0.2...0.2),
                        dy: CGFloat.random(in: -0.2...0.2)
                    )
                }
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
                velocity = velocity + towardPlayer * 0.5
            case .greenSquare:
                velocity = velocity + towardPlayer
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .cube:
                velocity = velocity + towardPlayer * 2.5
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .seeker:
                velocity = velocity + towardPlayer * 4
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .blackHole:
                updateBlackHole(enemy, velocity: &velocity)
            case .triangle:
                updateTriangleVelocity(enemy, towardPlayer: towardPlayer, velocity: &velocity)
            case .snake:
                var heading = CGFloat((enemy.userData?["snakeHeading"] as? NSNumber)?.doubleValue ?? 0)
                var turnDirection = (enemy.userData?["snakeTurnDirection"] as? NSNumber)?.intValue ?? 0
                let headingRadians = heading * .pi / 180
                velocity = velocity + CGVector(
                    dx: cos(headingRadians) * maximumSpeed,
                    dy: sin(headingRadians) * maximumSpeed
                )
                heading += turnDirection == 0 ? 4 : -4
                if Int.random(in: 1...100) > 90 {
                    turnDirection = 1 - turnDirection
                }
                enemy.userData?["snakeHeading"] = heading
                enemy.userData?["snakeTurnDirection"] = turnDirection
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .interceptor:
                var heading = CGFloat((enemy.userData?["interceptorHeading"] as? NSNumber)?.doubleValue ?? 0)
                var turnRemaining = (enemy.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
                if CGFloat.random(in: 1...100) > 95 - maximumSpeed * 8 {
                    turnRemaining = turnToFace(
                        velocity: velocity,
                        target: CGVector(
                            dx: player.position.x - enemy.position.x,
                            dy: player.position.y - enemy.position.y
                        )
                    )
                }
                if turnRemaining != 0 {
                    let sign = turnRemaining < 0 ? -1 : 1
                    heading += CGFloat(4 * sign)
                    turnRemaining -= sign
                }
                let headingRadians = heading * .pi / 180
                let facing = CGVector(dx: cos(headingRadians), dy: sin(headingRadians))
                if abs(turnRemaining) < 20 {
                    velocity = velocity + facing * 2
                } else {
                    velocity = (velocity + facing) * (0.265 + maximumSpeed / 20)
                }
                enemy.userData?["interceptorHeading"] = heading
                enemy.userData?["interceptorTurnRemaining"] = turnRemaining
            case .butterfly:
                velocity = velocity + towardPlayer * 2
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            }

            guard enemy.parent != nil else { continue }

            if kind == .interceptor {
                enemy.position.x += velocity.dx
                enemy.position.y += velocity.dy
                if enemy.position.x < 16 || enemy.position.x > size.width - 16 {
                    enemy.position.x -= velocity.dx
                    enemy.position.y -= velocity.dy
                }
                if enemy.position.y < 16 || enemy.position.y > size.height - 16 {
                    enemy.position.x -= velocity.dx
                    enemy.position.y -= velocity.dy
                }
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
                guard enemy.parent != nil else { continue }
            }

            applySeparation(to: enemy, kind: kind, velocity: &velocity)
            let cappedSpeed = kind == .cube
                ? maximumSpeed - CGFloat((enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0) / 4
                : maximumSpeed
            if velocity.length > cappedSpeed {
                velocity = velocity.normalized * cappedSpeed
            }

            if !movesBeforeSteering, kind != .interceptor {
                enemy.position.x += velocity.dx
                enemy.position.y += velocity.dy
                let velocityBeforeBounce = velocity
                bounce(enemy, velocity: &velocity, margin: 8)
                if kind == .snake,
                   velocity.dx != velocityBeforeBounce.dx || velocity.dy != velocityBeforeBounce.dy {
                    let heading = CGFloat((enemy.userData?["snakeHeading"] as? NSNumber)?.doubleValue ?? 0)
                    enemy.userData?["snakeHeading"] = heading + 90
                }
            }

            if kind == .cube {
                let tier = (enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
                enemy.position.x += sin(CGFloat(rotation * (6 + tier)) * .pi / 180) * CGFloat(tier)
                enemy.position.y += cos(CGFloat(rotation * (6 + tier)) * .pi / 180) * CGFloat(tier)
            }

            if checkPlayerCollision(with: enemy, kind: kind) {
                continue
            }

            enemy.userData?["dx"] = velocity.dx
            enemy.userData?["dy"] = velocity.dy
            enemy.userData?["rotation"] = rotation
            updateEnemyVisual(enemy, kind: kind, rotation: rotation)
            if kind == .interceptor { updateInterceptorShieldVisual(enemy, velocity: velocity) }
            if kind == .snake {
                updateSnakeSegments(for: enemy, maximumSpeed: maximumSpeed)
            }
        }
        }
    }

    private func updateEnemyVisual(_ enemy: SKNode, kind: EnemyKind, rotation: Int) {
        let freezeFrames = (enemy.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
        if let aura = enemy.childNode(withName: "spawnAura") {
            if freezeFrames > 0 {
                aura.alpha = min(1, CGFloat(freezeFrames) / 40)
                aura.setScale(CGFloat(freezeFrames) / 5)
            } else {
                let pulse = CGFloat((rotation / 16) % 8) + 0.5
                aura.alpha = max(0, 0.5 - pulse / 8)
                aura.setScale(pulse)
            }
        }

        switch kind {
        case .pinwheel:
            enemy.zRotation = CGFloat(rotation * 4) * .pi / 180
        case .diamond:
            let phase = rotation % 256
            let scaleX: CGFloat
            let scaleY: CGFloat
            if phase > 127 {
                scaleY = CGFloat(phase > 190 ? 255 - phase : phase - 127)
                scaleX = 0
            } else {
                scaleX = CGFloat(phase > 63 ? 127 - phase : phase)
                scaleY = 0
            }
            enemy.xScale = 1 + scaleX / 80
            enemy.yScale = 1 + scaleY / 80
        case .greenSquare, .cube:
            enemy.zRotation = CGFloat(rotation) * .pi / 180
        case .seeker:
            enemy.zRotation = 0
        case .blackHole:
            var scale = 0.25 + CGFloat((enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20) / 64
            if (enemy.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false {
                var pulse = CGFloat((enemy.userData?["blackHolePulse"] as? NSNumber)?.doubleValue ?? 0)
                pulse += CGFloat((enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20) / 2
                enemy.userData?["blackHolePulse"] = pulse
                scale += cos(pulse * .pi / 180) / 6
            }
            enemy.setScale(scale)
            enemy.zRotation = 0
        case .triangle:
            enemy.zRotation = CGFloat(rotation * 2) * .pi / 180
            let attached = trianglePartner(of: enemy) != nil
            var second = enemy.childNode(withName: "triangleTwin") as? SKSpriteNode
            if attached, second == nil {
                second = SKSpriteNode(imageNamed: EnemyKind.triangle.textureName)
                second?.name = "triangleTwin"
                second?.size = EnemyKind.triangle.size
                second?.blendMode = .add
                enemy.addChild(second!)
            }
            second?.isHidden = !attached
            second?.zRotation = CGFloat(rotation * 2 + 180) * .pi / 180
        case .snake:
            let velocity = CGVector(
                dx: CGFloat((enemy.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((enemy.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )
            enemy.zRotation = atan2(velocity.dy, velocity.dx) + .pi / 2
        case .interceptor:
            let heading = CGFloat((enemy.userData?["interceptorHeading"] as? NSNumber)?.doubleValue ?? 0)
            enemy.zRotation = heading * .pi / 180 + .pi / 2
        case .butterfly:
            enemy.zRotation = CGFloat(rotation * 8) * .pi / 180
        }
    }

    private func turnToFace(velocity: CGVector, target: CGVector) -> Int {
        let targetAngle = atan2(target.dy, target.dx) * 180 / .pi
        let velocityAngle = atan2(velocity.dy, velocity.dx) * 180 / .pi
        var result = Int(targetAngle - velocityAngle)
        if result >= 180 {
            result = -(360 - result)
        } else if result <= -180 {
            result += 360
        }
        return abs(result) < 6 ? 0 : result
    }

    private func spawnSnakeSegments(for head: SKNode, freezeFrames: Int) {
        guard let headID = head.userData?["enemyID"] as? String else { return }
        for index in 0..<24 {
            let originalFrame = 23 - index
            let segment = SKSpriteNode(texture: snakeTailTexture(frame: originalFrame))
            segment.name = "snakeTail"
            segment.size = CGSize(width: 56, height: 56)
            segment.blendMode = .add
            segment.position = head.position
            segment.physicsBody = SKPhysicsBody(circleOfRadius: sqrt(CGFloat(81 + originalFrame)))
            segment.physicsBody?.affectedByGravity = false
            segment.physicsBody?.allowsRotation = false
            segment.physicsBody?.categoryBitMask = Category.enemy
            segment.physicsBody?.collisionBitMask = 0
            segment.physicsBody?.contactTestBitMask = Category.player | Category.projectile
            segment.userData = NSMutableDictionary(dictionary: [
                "snakeHeadID": headID,
                "segmentIndex": index,
                "originalFrame": originalFrame,
                "freezeFrames": freezeFrames,
                "dx": 0.0,
                "dy": 0.0,
            ])
            enemyLayer.addChild(segment)
        }
    }

    private func snakeTailTexture(frame: Int) -> SKTexture {
        let sheet = SKTexture(imageNamed: "snaketail")
        let column = frame % 8
        let rowFromTop = frame / 8
        let texture = SKTexture(
            rect: CGRect(
                x: CGFloat(column) / 8,
                y: CGFloat(2 - rowFromTop) / 3,
                width: 1.0 / 8.0,
                height: 1.0 / 3.0
            ),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }

    private func updateSnakeSegments(for head: SKNode, maximumSpeed: CGFloat) {
        guard let headID = head.userData?["enemyID"] as? String else { return }
        let segments = enemyLayer.children.compactMap { $0 as? SKSpriteNode }
            .filter {
                $0.name == "snakeTail" && $0.userData?["snakeHeadID"] as? String == headID
            }
            .sorted {
                (($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
                    < (($1.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
            }

        var precedingPosition = head.position
        for segment in segments {
            var freezeFrames = (segment.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                segment.userData?["freezeFrames"] = freezeFrames
                precedingPosition = segment.position
                continue
            }

            var velocity = SnakeSegmentRule.velocity(
                from: segment.position,
                toward: precedingPosition,
                maximumSpeed: maximumSpeed
            )
            segment.position.x += velocity.dx
            segment.position.y += velocity.dy
            bounce(segment, velocity: &velocity, margin: 8)
            segment.userData?["dx"] = velocity.dx
            segment.userData?["dy"] = velocity.dy
            segment.zRotation = atan2(velocity.dy, velocity.dx) - .pi / 2
            if squaredDistance(segment.position, player.position) < 24 * 24,
               hitPlayer(at: segment.position) {
                segment.removeFromParent()
                createExplosion(at: segment.position, color: .green)
                continue
            }
            precedingPosition = segment.position
        }
    }

    private func scheduleSnakeTailExplosion(for head: SKNode, awardPoints: Bool) {
        guard let headID = head.userData?["enemyID"] as? String else { return }
        let segments = enemyLayer.children.filter {
            $0.name == "snakeTail" && $0.userData?["snakeHeadID"] as? String == headID
        }
        let baseDelay = awardPoints ? 30.0 / 50.0 : 300.0 / 50.0
        for segment in segments {
            let index = (segment.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0
            segment.name = "snakeDying"
            segment.physicsBody?.categoryBitMask = 0
            let position = segment.position
            segment.run(.sequence([
                .wait(forDuration: baseDelay + Double(index) / 50.0),
                .run { [weak self, weak segment] in
                    guard let self, let segment, segment.parent != nil else { return }
                    self.createExplosion(at: position, color: .green)
                },
                .removeFromParent(),
            ]))
        }
    }

    private func updateTriangleVelocity(
        _ triangle: SKNode,
        towardPlayer: CGVector,
        velocity: inout CGVector
    ) {
        guard let partner = trianglePartner(of: triangle) else {
            triangle.userData?["trianglePartnerID"] = nil
            let distance = CGVector(
                dx: player.position.x - triangle.position.x,
                dy: player.position.y - triangle.position.y
            ).length
            if distance < 300 { velocity = velocity + towardPlayer }
            _ = applyBlackHoleInfluence(to: triangle, kind: .triangle, velocity: &velocity)
            return
        }

        let difference = CGVector(
            dx: partner.position.x - triangle.position.x,
            dy: partner.position.y - triangle.position.y
        )
        let distance = max(0.001, difference.length)
        if distance > 150 {
            velocity = velocity + difference / distance * 32
        } else if distance < 64 {
            velocity = velocity - difference / distance * 32
        }
        _ = applyBlackHoleInfluence(to: triangle, kind: .triangle, velocity: &velocity)
    }

    private func updateTrianglePairsAndBonds() {
        for bond in enemyLayer.children where bond.name == "triangleBond" {
            bond.removeFromParent()
        }

        let triangles = enemyLayer.children.filter {
            $0.name == "enemy"
                && $0.userData?["kind"] as? String == EnemyKind.triangle.rawValue
                && (($0.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0) == 0
        }
        for triangle in triangles where trianglePartner(of: triangle) == nil {
            guard let partner = triangles.first(where: {
                $0 !== triangle
                    && trianglePartner(of: $0) == nil
                    && CGVector(
                        dx: triangle.position.x - $0.position.x,
                        dy: triangle.position.y - $0.position.y
                    ).length < 32
            }) else { continue }
            attachTriangles(triangle, partner)
        }

        var drawnPairs = Set<String>()
        for triangle in triangles {
            guard let partner = trianglePartner(of: triangle),
                  let firstID = triangle.userData?["enemyID"] as? String,
                  let secondID = partner.userData?["enemyID"] as? String else { continue }
            let pairID = [firstID, secondID].sorted().joined(separator: "-")
            guard drawnPairs.insert(pairID).inserted else { continue }

            let strength = CGFloat((triangle.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                                   ?? Double(TriangleBondState.initialStrength))
            let path = CGMutablePath()
            path.move(to: triangle.position)
            path.addLine(to: partner.position)
            let bond = SKShapeNode(path: path)
            bond.name = "triangleBond"
            bond.strokeColor = SKColor(
                red: min(1, (20 + strength * 8) / 255),
                green: min(1, (220 - strength * 8) / 255),
                blue: 0,
                alpha: 1
            )
            bond.lineWidth = 2
            bond.glowWidth = 2
            bond.zPosition = -1
            enemyLayer.addChild(bond)

        }
    }

    private func checkTriangleBondPlayerCollision() {
        var checkedPairs = Set<String>()
        for triangle in enemies(of: .triangle) {
            guard let partner = trianglePartner(of: triangle),
                  let firstID = triangle.userData?["enemyID"] as? String,
                  let secondID = partner.userData?["enemyID"] as? String else { continue }
            let pairID = [firstID, secondID].sorted().joined(separator: "-")
            guard checkedPairs.insert(pairID).inserted else { continue }
            if distanceFromPoint(player.position, toLineFrom: triangle.position, to: partner.position) <= 12 {
                _ = hitPlayer(at: player.position)
                return
            }
        }
    }

    private func pullPlayerTowardBlackHoles() {
        for blackHole in enemies(of: .blackHole) {
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            let difference = CGVector(
                dx: blackHole.position.x - player.position.x,
                dy: blackHole.position.y - player.position.y
            )
            let distance = max(0.001, difference.length)
            if distance < blackHoleSize * 10 {
                let pull = difference / distance * (blackHoleSize / 30)
                player.position.x += pull.dx
                player.position.y += pull.dy
            }
        }
    }

    private func attachTriangles(_ first: SKNode, _ second: SKNode) {
        guard let firstID = first.userData?["enemyID"] as? String,
              let secondID = second.userData?["enemyID"] as? String else { return }
        first.userData?["trianglePartnerID"] = secondID
        first.userData?["triangleStrength"] = TriangleBondState.initialStrength
        second.userData?["trianglePartnerID"] = firstID
        second.userData?["triangleStrength"] = TriangleBondState.initialStrength
    }

    private func trianglePartner(of triangle: SKNode) -> SKNode? {
        guard let partnerID = triangle.userData?["trianglePartnerID"] as? String else { return nil }
        return enemyLayer.children.first {
            $0.parent != nil && $0.userData?["enemyID"] as? String == partnerID
        }
    }

    private func detachTriangle(_ triangle: SKNode) {
        if let partner = trianglePartner(of: triangle) {
            partner.userData?["trianglePartnerID"] = nil
            partner.userData?["triangleStrength"] = 0
        }
        triangle.userData?["trianglePartnerID"] = nil
        triangle.userData?["triangleStrength"] = 0
    }

    private func updateInterceptorShieldVisual(_ interceptor: SKNode, velocity: CGVector) {
        interceptor.childNode(withName: "interceptorShield")?.removeFromParent()
        let turnRemaining = (interceptor.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
        guard abs(turnRemaining) <= 4 else { return }

        let geometry = InterceptorShieldGeometry(center: interceptor.position, velocity: velocity)
        let path = CGMutablePath()
        path.move(to: CGPoint(
            x: geometry.rear.x - interceptor.position.x,
            y: geometry.rear.y - interceptor.position.y
        ))
        path.addLine(to: CGPoint(
            x: geometry.right.x - interceptor.position.x,
            y: geometry.right.y - interceptor.position.y
        ))
        path.addLine(to: CGPoint(
            x: geometry.left.x - interceptor.position.x,
            y: geometry.left.y - interceptor.position.y
        ))
        path.closeSubpath()
        let shield = SKShapeNode(path: path)
        shield.name = "interceptorShield"
        shield.strokeColor = SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.9)
        shield.lineWidth = 1.5
        shield.glowWidth = 2
        shield.zPosition = -1
        interceptor.addChild(shield)
    }

    private func blockProjectilesWithInterceptorShields() {
        let interceptors = enemyLayer.children.filter {
            $0.name == "enemy"
                && $0.userData?["kind"] as? String == EnemyKind.interceptor.rawValue
                && abs(($0.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0) <= 4
        }
        for projectile in projectileLayer.children where projectile.parent != nil {
            let isSuperShot = (projectile.userData?["superShot"] as? NSNumber)?.boolValue ?? false
            guard !isSuperShot else { continue }
            for interceptor in interceptors {
                let velocity = CGVector(
                    dx: CGFloat((interceptor.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                    dy: CGFloat((interceptor.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
                )
                let geometry = InterceptorShieldGeometry(center: interceptor.position, velocity: velocity)
                if geometry.contains(projectile.position) {
                    let position = projectile.position
                    projectile.removeFromParent()
                    createExplosion(at: position, color: .red)
                    break
                }
            }
        }
    }

    private func applySeparation(to enemy: SKNode, kind: EnemyKind, velocity: inout CGVector) {
        let radius: CGFloat
        let force: CGFloat
        switch kind {
        case .pinwheel: (radius, force) = (sqrt(20 * 20 + 20 * 20), 1)
        case .diamond: (radius, force) = (sqrt(30 * 30 + 20 * 20), 1)
        case .greenSquare: (radius, force) = (sqrt(30 * 30 + 24 * 24), 1)
        case .cube:
            let tier = (enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
            (radius, force) = (sqrt(CGFloat(30 * 30 + 20 * 20 - tier * 20)), 1)
        case .seeker: (radius, force) = (sqrt(24 * 24 + 20 * 20), 1)
        case .butterfly: (radius, force) = (sqrt(16 * 16 + 16 * 16), 0.125)
        case .interceptor: (radius, force) = (sqrt(20 * 20 + 20 * 20), 1)
        case .blackHole, .triangle, .snake: return
        }

        for other in enemyLayer.children where other !== enemy && other.name == "enemy" {
            guard other.userData?["kind"] as? String == kind.rawValue else { continue }
            let difference = CGVector(
                dx: other.position.x - enemy.position.x,
                dy: other.position.y - enemy.position.y
            )
            if difference.length < radius {
                velocity.dx -= difference.dx == 0 ? 0 : copysign(force, difference.dx)
                velocity.dy -= difference.dy == 0 ? 0 : copysign(force, difference.dy)
            }
        }
    }

    private func bounce(_ enemy: SKNode, velocity: inout CGVector, margin: CGFloat) {
        if enemy.position.x < margin {
            velocity.dx = abs(velocity.dx)
            enemy.position.x += velocity.dx
        } else if enemy.position.x > size.width - margin {
            velocity.dx = -abs(velocity.dx)
            enemy.position.x += velocity.dx
        }
        if enemy.position.y < margin {
            velocity.dy = abs(velocity.dy)
            enemy.position.y += velocity.dy
        } else if enemy.position.y > size.height - margin {
            velocity.dy = -abs(velocity.dy)
            enemy.position.y += velocity.dy
        }
    }

    @discardableResult
    private func applyBlackHoleInfluence(
        to enemy: SKNode,
        kind: EnemyKind,
        velocity: inout CGVector
    ) -> Bool {
        if kind == .triangle,
           let partner = trianglePartner(of: enemy),
           let enemyID = enemy.userData?["enemyID"] as? String,
           let partnerID = partner.userData?["enemyID"] as? String {
            guard enemyID < partnerID else { return false }
            for blackHole in enemies(of: .blackHole) {
                let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
                let difference = CGVector(
                    dx: blackHole.position.x - enemy.position.x,
                    dy: blackHole.position.y - enemy.position.y
                )
                let distance = max(0.001, difference.length)
                if distance < 100 + blackHoleSize * 10 {
                    velocity = velocity + difference / distance
                }
                if distance * distance < 12 * 12 + blackHoleSize * blackHoleSize * 4 {
                    let rotation = CGFloat((blackHole.userData?["rotation"] as? NSNumber)?.doubleValue ?? 0)
                    let radians = rotation * 2 * .pi / 180
                    var partnerVelocity = CGVector(
                        dx: CGFloat((partner.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                        dy: CGFloat((partner.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
                    )
                    partnerVelocity = partnerVelocity
                        - CGVector(dx: cos(radians) * 8, dy: sin(radians) * 8)
                    partner.userData?["dx"] = partnerVelocity.dx
                    partner.userData?["dy"] = partnerVelocity.dy
                    let strength = CGFloat((partner.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                                           ?? Double(TriangleBondState.initialStrength))
                    var bond = TriangleBondState(strength: strength)
                    bond.registerBlackHoleSpin()
                    partner.userData?["triangleStrength"] = bond.strength
                    if bond.isBroken {
                        detachTriangle(enemy)
                        destroyEnemy(enemy, playSound: false, awardPoints: false)
                        growBlackHole(blackHole, amount: 1)
                        return true
                    }
                }
            }
            return false
        }

        for blackHole in enemies(of: .blackHole) {
            guard (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false else { continue }
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            let difference = CGVector(
                dx: blackHole.position.x - enemy.position.x,
                dy: blackHole.position.y - enemy.position.y
            )
            let distance = max(0.001, difference.length)
            let pullRange: CGFloat
            let pullStrength: CGFloat
            let absorbDistance: CGFloat
            switch kind {
            case .pinwheel, .diamond, .greenSquare, .cube:
                pullRange = 75 + blackHoleSize * 8
                pullStrength = (1_200 - distance) / 512
                absorbDistance = 12 + blackHoleSize / 2
            case .seeker:
                pullRange = 75 + blackHoleSize * 6
                pullStrength = (700 - distance) / 1_024
                absorbDistance = blackHoleSize / 2
            case .butterfly:
                pullRange = 75 + blackHoleSize * 5
                pullStrength = (500 - distance) / 2_048
                absorbDistance = 12 + blackHoleSize
            case .snake:
                pullRange = 75 + blackHoleSize * 5
                pullStrength = (1_200 - distance) / 1_024
                absorbDistance = 12 + blackHoleSize / 2
            case .interceptor:
                pullRange = 75 + blackHoleSize * 8
                pullStrength = (1_200 - distance) / 512
                absorbDistance = 16 + blackHoleSize / 2
            case .triangle:
                pullRange = 25 + blackHoleSize * 5
                pullStrength = (500 - distance) / 1_024
                absorbDistance = blackHoleSize / 2
            case .blackHole:
                continue
            }
            guard distance < pullRange else { continue }
            velocity = velocity + difference / distance * pullStrength
            if distance < absorbDistance {
                destroyEnemy(enemy, playSound: false, awardPoints: false)
                growBlackHole(blackHole, amount: 1)
                return true
            }
        }
        return false
    }

    private func updateBlackHole(_ blackHole: SKNode, velocity: inout CGVector) {
        let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
        blackHole.setScale(max(0.25, 0.25 + blackHoleSize / 64))

        for otherBlackHole in enemyLayer.children where otherBlackHole !== blackHole
            && otherBlackHole.name == "enemy"
            && otherBlackHole.userData?["kind"] as? String == EnemyKind.blackHole.rawValue {
            let otherSize = CGFloat((otherBlackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            var difference = CGVector(
                dx: otherBlackHole.position.x - blackHole.position.x,
                dy: otherBlackHole.position.y - blackHole.position.y
            )
            let distance = max(0.001, difference.length)
            var magnitude = min(8, max(1, (otherSize - blackHoleSize) / 8))
            if magnitude.isNaN { magnitude = 1 }
            guard distance < otherSize * 2 + blackHoleSize * 2 + 64 else { continue }
            difference = difference / distance * magnitude
            if distance < otherSize + blackHoleSize {
                difference.dx = -difference.dx - difference.dy * 0.25
                difference.dy = -difference.dy - difference.dx * 0.25
            }
            velocity = velocity + difference
        }
    }

    private func growBlackHole(_ blackHole: SKNode, amount: CGFloat) {
        var blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
        let speedUp = min(5, 1 + CGFloat(simulationFrame / (50 * 60 * 6)))
        blackHoleSize += amount * speedUp
        blackHole.userData?["blackHoleSize"] = blackHoleSize
        blackHole.userData?["blackHoleActive"] = true
        let absorbed = (blackHole.userData?["absorbCount"] as? NSNumber)?.intValue ?? 0
        blackHole.userData?["absorbCount"] = absorbed + 1

        if blackHoleSize > 64 {
            let position = blackHole.position
            blackHole.removeFromParent()
            for index in 0..<16 {
                let angle = CGFloat(index) * 22.5 * .pi / 180
                let seeker = spawnEnemy(kind: .seeker, at: CGPoint(x: position.x + cos(angle) * 20, y: position.y + sin(angle) * 20), freezeFrames: 4, closeToPlayer: true)
                seeker?.userData?["seekerMean"] = 1
            }
            for index in 0..<18 {
                let angle = CGFloat(index) * 20 * .pi / 180
                spawnEnemy(kind: .butterfly, at: CGPoint(x: position.x + cos(angle) * 30, y: position.y + sin(angle) * 30), freezeFrames: 4, closeToPlayer: true)
            }
            createExplosion(at: position, color: .red)
        }
    }

    private func updateProjectiles() {
        for projectile in projectileLayer.children {
            guard projectile.parent != nil else { continue }
            var velocity = projectileVelocity(projectile)
            let originalSpeed = CGFloat((projectile.userData?["speed"] as? NSNumber)?.doubleValue
                                        ?? Double(velocity.length))
            var shouldRemove = false

            for _ in 0..<2 {
                projectile.position.x += velocity.dx / 2
                projectile.position.y += velocity.dy / 2

                if projectile.position.x < 0 || projectile.position.x > size.width - 1 {
                    projectile.position.x -= velocity.dx
                    if session.bouncyShotFrames == 0 {
                        shouldRemove = true
                    } else {
                        velocity.dx = -velocity.dx
                    }
                }
                if projectile.position.y < 0 || projectile.position.y > size.height - 1 {
                    projectile.position.y -= velocity.dy
                    if session.bouncyShotFrames == 0 {
                        shouldRemove = true
                    } else {
                        velocity.dy = -velocity.dy
                    }
                }

                projectile.userData?["dx"] = velocity.dx
                projectile.userData?["dy"] = velocity.dy
                if !shouldRemove {
                    let collided = checkProjectileCollisions(projectile)
                    if session.superShotFrames == 0 { shouldRemove = collided }
                }
                if !shouldRemove {
                    applyBlackHoles(toProjectile: projectile, velocity: &velocity)
                }

                let speed = velocity.length
                if speed > 0, speed < originalSpeed / 2 {
                    velocity.dx = velocity.dx / speed * (originalSpeed / 2)
                    velocity.dx = velocity.dx / speed * (originalSpeed / 2)
                }
                if shouldRemove {
                    let position = projectile.position
                    projectile.removeFromParent()
                    createExplosion(at: position, color: session.superShotFrames > 0 ? .cyan : .yellow)
                    break
                }
            }

            if projectile.parent != nil {
                projectile.userData?["dx"] = velocity.dx
                projectile.userData?["dy"] = velocity.dy
                projectile.zRotation = atan2(velocity.dy, velocity.dx)
            }
        }
    }

    private func projectileVelocity(_ projectile: SKNode) -> CGVector {
        CGVector(
            dx: CGFloat((projectile.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
            dy: CGFloat((projectile.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
        )
    }

    private func checkProjectileCollisions(_ projectile: SKNode) -> Bool {
        let position = projectile.position

        for blackHole in enemies(of: .blackHole) {
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            if squaredDistance(position, blackHole.position) < pow(12 + blackHoleSize / 2, 2) {
                damageEnemy(blackHole, projectile: projectile)
                return true
            }
        }
        for square in enemies(of: .greenSquare) {
            if squaredDistance(position, square.position) < 16 * 16 + 2 * 2 {
                damageEnemy(square, projectile: projectile)
                return true
            }
            runGreenSquare(square, awayFrom: projectile)
        }
        for pinwheel in enemies(of: .pinwheel) where squaredDistance(position, pinwheel.position) < 16 * 16 + 2 * 2 {
            damageEnemy(pinwheel, projectile: projectile)
            return true
        }
        for diamond in enemies(of: .diamond) where squaredDistance(position, diamond.position) < 18 * 18 + 3 * 3 {
            damageEnemy(diamond, projectile: projectile)
            return true
        }
        for cube in enemies(of: .cube) {
            let tier = (cube.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
            if squaredDistance(position, cube.position) < CGFloat(16 * 16 + 3 * 3 - tier * 3) {
                damageEnemy(cube, projectile: projectile)
                return true
            }
        }
        for seeker in enemies(of: .seeker) where squaredDistance(position, seeker.position) < 12 * 12 + 2 * 2 {
            damageEnemy(seeker, projectile: projectile)
            return true
        }
        for triangle in enemies(of: .triangle) where squaredDistance(position, triangle.position) < 12 * 12 + 2 * 2 {
            damageEnemy(triangle, projectile: projectile)
            return true
        }
        for generator in enemyLayer.children where generator.name == "generator" {
            let generatorSize = CGFloat((generator.userData?["health"] as? NSNumber)?.doubleValue ?? 0)
            if squaredDistance(position, generator.position) < 12 * 12 + generatorSize {
                damageEnemy(generator, projectile: projectile)
                return true
            }
        }

        let snakeNodes = enemyLayer.children.filter {
            $0.name == "snakeTail"
                || ($0.name == "enemy" && $0.userData?["kind"] as? String == EnemyKind.snake.rawValue)
        }
        for snakeNode in snakeNodes {
            let frame = snakeNode.name == "snakeTail"
                ? ((snakeNode.userData?["originalFrame"] as? NSNumber)?.intValue ?? 0)
                : 24
            if squaredDistance(position, snakeNode.position) < CGFloat(9 * 9 + frame) {
                damageEnemy(snakeNode, projectile: projectile)
                return true
            }
        }

        for interceptor in enemies(of: .interceptor) {
            let distance = squaredDistance(position, interceptor.position)
            guard distance < 64 * 64 else { continue }
            let turnRemaining = (interceptor.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
            if abs(turnRemaining) > 4 {
                if distance < 12 * 12 {
                    damageEnemy(interceptor, projectile: projectile)
                    return true
                }
            } else {
                let velocity = CGVector(
                    dx: CGFloat((interceptor.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                    dy: CGFloat((interceptor.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
                )
                if InterceptorShieldGeometry(center: interceptor.position, velocity: velocity).contains(position) {
                    return true
                }
                if distance < 12 * 12 {
                    damageEnemy(interceptor, projectile: projectile)
                    return true
                }
            }
        }
        for butterfly in enemies(of: .butterfly) where squaredDistance(position, butterfly.position) < 10 * 10 + 2 * 2 {
            damageEnemy(butterfly, projectile: projectile)
            return true
        }
        return false
    }

    private func enemies(of kind: EnemyKind) -> [SKNode] {
        enemyLayer.children.filter {
            $0.name == "enemy" && $0.userData?["kind"] as? String == kind.rawValue
        }
    }

    private func squaredDistance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return dx * dx + dy * dy
    }

    private func checkPlayerCollision(with enemy: SKNode, kind: EnemyKind) -> Bool {
        let radiusSquared: CGFloat
        switch kind {
        case .greenSquare, .pinwheel, .diamond, .snake, .interceptor, .triangle:
            radiusSquared = 24 * 24
        case .cube:
            let tier = (enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
            radiusSquared = CGFloat((12 - tier) * (12 - tier) + 12 * 12)
        case .seeker, .butterfly:
            radiusSquared = 12 * 12 + 12 * 12
        case .blackHole:
            let blackHoleSize = CGFloat((enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            radiusSquared = pow(12 + blackHoleSize / 2, 2) + 12 * 12
        }
        guard squaredDistance(enemy.position, player.position) < radiusSquared,
              hitPlayer(at: enemy.position) else { return false }
        destroyEnemy(enemy, playSound: false, awardPoints: false)
        return true
    }

    private func runGreenSquare(_ square: SKNode, awayFrom projectile: SKNode) {
        var squareVelocity = CGVector(
            dx: CGFloat((square.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
            dy: CGFloat((square.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
        )
        let shotVelocity = projectileVelocity(projectile)
        let danger = CGVector(
            dx: projectile.position.x - square.position.x + shotVelocity.dx * 4,
            dy: projectile.position.y - square.position.y + shotVelocity.dy * 4
        )
        let bulletBack = shotVelocity * -1
        let dangerDistance = max(0.001, danger.length)
        let bulletDistance = max(0.001, bulletBack.length)
        guard dangerDistance < 100 else { return }
        squareVelocity = squareVelocity
            - danger / dangerDistance * 30
            + bulletBack / bulletDistance * 30
        let maximumSpeed = CGFloat((square.userData?["speed"] as? NSNumber)?.doubleValue ?? 1) * 1.1
        if squareVelocity.length > maximumSpeed {
            squareVelocity = squareVelocity.normalized * maximumSpeed
        }
        square.userData?["dx"] = squareVelocity.dx
        square.userData?["dy"] = squareVelocity.dy
    }

    private func applyBlackHoles(toProjectile projectile: SKNode, velocity: inout CGVector) {
        for blackHole in enemies(of: .blackHole) {
            guard (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false else { continue }
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            let difference = CGVector(
                dx: blackHole.position.x - projectile.position.x,
                dy: blackHole.position.y - projectile.position.y
            )
            let distanceSquared = difference.dx * difference.dx + difference.dy * difference.dy
            guard distanceSquared < pow(75 + blackHoleSize * 5, 2), distanceSquared > 32 * 32 else { continue }
            let divisor = max(1, 26 - blackHoleSize / 4)
            velocity.dx -= difference.dx == 0 ? 0 : copysign(1 / divisor, difference.dx)
            velocity.dy -= difference.dy == 0 ? 0 : copysign(1 / divisor, difference.dy)
            projectile.userData?["dx"] = velocity.dx
            projectile.userData?["dy"] = velocity.dy
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        handleContact(contact)
    }

    private func handleContact(_ contact: SKPhysicsContact) {
        let first = contact.bodyA.categoryBitMask <= contact.bodyB.categoryBitMask
            ? contact.bodyA.node
            : contact.bodyB.node
        let second = contact.bodyA.categoryBitMask <= contact.bodyB.categoryBitMask
            ? contact.bodyB.node
            : contact.bodyA.node

        guard let first, let second else { return }
        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if categories == Category.projectile | Category.enemy {
            let projectile = first.physicsBody?.categoryBitMask == Category.projectile ? first : second
            let enemy = first.physicsBody?.categoryBitMask == Category.enemy ? first : second
            let isSuperShot = (projectile.userData?["superShot"] as? NSNumber)?.boolValue ?? false
            if !isSuperShot { projectile.removeFromParent() }
            damageEnemy(enemy, projectile: projectile)
        } else if categories == Category.player | Category.enemy {
            let enemy = first.physicsBody?.categoryBitMask == Category.enemy ? first : second
            if hitPlayer(at: contact.contactPoint) {
                if enemy.name == "snakeTail" {
                    enemy.removeFromParent()
                    createExplosion(at: enemy.position, color: .green)
                } else {
                    destroyEnemy(enemy, playSound: false, awardPoints: false)
                }
            }
        } else if categories == Category.player | Category.powerUp {
            let powerUp = first.physicsBody?.categoryBitMask == Category.powerUp ? first : second
            collect(powerUp)
        }
    }

    private func damageEnemy(_ enemy: SKNode, projectile: SKNode) {
        guard enemy.parent != nil else { return }
        if enemy.name == "snakeTail" {
            createExplosion(at: enemy.position, color: .green)
            return
        }
        guard enemy.name == "enemy" || enemy.name == "generator" else { return }
        let kind = EnemyKind(rawValue: enemy.userData?["kind"] as? String ?? "") ?? .pinwheel
        if kind == .interceptor, enemy.name == "enemy" {
            let turnRemaining = (enemy.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
            let velocity = CGVector(
                dx: CGFloat((enemy.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((enemy.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )
            if abs(turnRemaining) <= 4,
               InterceptorShieldGeometry(center: enemy.position, velocity: velocity).contains(projectile.position) {
                createExplosion(at: projectile.position, color: .red)
                return
            }
        }
        if kind == .triangle, enemy.name == "enemy", trianglePartner(of: enemy) != nil {
            let strength = CGFloat((enemy.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                                   ?? Double(TriangleBondState.initialStrength))
            var bond = TriangleBondState(strength: strength)
            let shotVelocity = projectileVelocity(projectile)
            let impulse = bond.registerProjectileHit(projectileVelocityPerFrame: shotVelocity)
            var velocity = CGVector(
                dx: CGFloat((enemy.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((enemy.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )
            velocity = velocity + impulse
            enemy.userData?["dx"] = velocity.dx
            enemy.userData?["dy"] = velocity.dy
            enemy.userData?["triangleStrength"] = bond.strength
            createExplosion(at: enemy.position, color: .orange)
            if bond.isBroken { detachTriangle(enemy) }
            return
        }
        if kind == .blackHole, enemy.name == "enemy" {
            var blackHoleSize = CGFloat((enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            enemy.userData?["blackHoleActive"] = true
            blackHoleSize -= 0.75
            enemy.userData?["blackHoleSize"] = blackHoleSize
            if blackHoleSize < 4 {
                let absorbed = (enemy.userData?["absorbCount"] as? NSNumber)?.intValue ?? 0
                enemy.userData?["score"] = 150 + absorbed * (absorbed + 1) / 3 * 5
                destroyEnemy(enemy)
            } else {
                run(.playSoundFileNamed("sunhit1.wav", waitForCompletion: false))
            }
            return
        }

        let health = (enemy.userData?["health"] as? NSNumber)?.intValue ?? 1
        if health > 1 {
            let newHealth = health - 1
            enemy.userData?["health"] = newHealth
            if enemy.name == "generator" {
                for event in session.registerScore(baseScore: 1) {
                    handleProgressionEvent(event)
                }
                updateGeneratorAppearance(enemy, kind: kind, health: newHealth)
                updateHUD()
            }
            enemy.run(.sequence([
                .fadeAlpha(to: 0.25, duration: 0.035),
                .fadeAlpha(to: 1, duration: 0.07),
            ]))
            run(.playSoundFileNamed("genhit1.wav", waitForCompletion: false))
        } else {
            destroyEnemy(enemy)
        }
    }

    private func updateGeneratorAppearance(_ generator: SKNode, kind: EnemyKind, health: Int) {
        guard let shape = generator as? SKShapeNode else { return }
        let radius = 12 + CGFloat(health) / 4
        shape.path = generatorPath(kind: kind, radius: radius)
        shape.fillColor = generatorColor(for: kind).withAlphaComponent(0.1 + CGFloat(health) / 256)
        shape.physicsBody = SKPhysicsBody(circleOfRadius: 12 + CGFloat(health) / 2)
        shape.physicsBody?.affectedByGravity = false
        shape.physicsBody?.allowsRotation = false
        shape.physicsBody?.categoryBitMask = Category.enemy
        shape.physicsBody?.collisionBitMask = 0
        shape.physicsBody?.contactTestBitMask = Category.player | Category.projectile
    }

    private func destroyEnemy(
        _ enemy: SKNode,
        playSound: Bool = true,
        awardPoints: Bool = true
    ) {
        guard enemy.parent != nil, enemy.name == "enemy" || enemy.name == "generator" else { return }
        let originalName = enemy.name
        let kind = EnemyKind(rawValue: enemy.userData?["kind"] as? String ?? "") ?? .pinwheel
        let cubeTier = (enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
        if kind == .triangle, originalName == "enemy" {
            detachTriangle(enemy)
        }
        if kind == .snake, originalName == "enemy" {
            scheduleSnakeTailExplosion(for: enemy, awardPoints: awardPoints)
        }
        enemy.name = "destroying"
        enemy.physicsBody?.categoryBitMask = 0
        let score = (enemy.userData?["score"] as? NSNumber)?.intValue ?? 100
        let position = enemy.position
        enemy.removeFromParent()

        let progressionEvents = awardPoints
            ? session.registerEnemyDestroyed(baseScore: score)
            : []
        if awardPoints { destroyedEnemyCount += 1 }
        createExplosion(at: position, color: .cyan)
        if awardPoints, kind == .cube, cubeTier == 0, originalName == "enemy" {
            for _ in 0..<3 {
                spawnEnemy(
                    kind: .cube,
                    at: CGPoint(x: position.x - 30, y: position.y + CGFloat.random(in: -30...30)),
                    freezeFrames: 2,
                    closeToPlayer: true
                )
                if let smallCube = enemyLayer.children.last {
                    smallCube.userData?["cubeTier"] = 4
                    smallCube.userData?["score"] = 50
                    (smallCube as? SKSpriteNode)?.texture = SKTexture(imageNamed: "purplesquare2")
                }
            }
        }
        for event in progressionEvents {
            handleProgressionEvent(event)
        }
        if playSound {
            run(.playSoundFileNamed("Explo1.wav", waitForCompletion: false))
        }
        updateHUD()
    }

    private func handleProgressionEvent(_ event: ProgressionEvent) {
        switch event {
        case let .multiplierIncreased(value):
            messageLabel.text = "\(value)X Multiplier"
            messageLabel.isHidden = false
            messageLabel.run(.sequence([.wait(forDuration: 0.7), .hide()]))
            run(.playSoundFileNamed("bonus2.wav", waitForCompletion: false))
        case let .spawnPowerUp(requestedKind):
            let kind = requestedKind ?? choosePowerUpKind()
            let position = CGPoint(
                x: CGFloat.random(in: 250...(size.width - 250)),
                y: CGFloat.random(in: 150...(size.height - 150))
            )
            spawnPowerUp(at: position, kind: kind)
            run(.playSoundFileNamed("bonusborn.wav", waitForCompletion: false))
        case .powerUpCollected:
            break
        }
    }

    private func choosePowerUpKind() -> PowerUpKind {
        var kind: PowerUpKind = Bool.random() ? .reverseShooter : .sideShooters
        if Int.random(in: 0...100) > 80 {
            kind = .shield
            if Int.random(in: 0...100) > 45 {
                kind = Bool.random() ? .superShots : .bouncyShots
            }
        }
        if session.shotSpeed < 5, Int.random(in: 1...session.shotSpeed) < 2 {
            kind = .fasterShots
        }
        if session.cannons < 4, Int.random(in: 1...session.cannons) == 1 {
            kind = .extraCannon
        }
        if kind.rawValue < 2, Int.random(in: 0...100) > 40 {
            if session.lives < 2 {
                kind = .extraPlayer
            } else if session.bombs < 2 {
                kind = .extraBomb
            }
        }
        return kind
    }

    private func spawnPowerUp(at position: CGPoint, kind: PowerUpKind) {
        let powerUp = SKNode()
        powerUp.name = "powerUp"
        powerUp.position = position
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: 14)
        powerUp.physicsBody?.affectedByGravity = false
        powerUp.physicsBody?.categoryBitMask = Category.powerUp
        powerUp.physicsBody?.collisionBitMask = 0
        powerUp.physicsBody?.contactTestBitMask = Category.player
        let direction = CGFloat.random(in: 0...(2 * .pi))
        let magnitude = CGFloat.random(in: 0.5...2)
        powerUp.userData = NSMutableDictionary(dictionary: [
            "kind": kind.rawValue,
            "lifeFrames": 0,
            "freezeFrames": 2,
            "dx": cos(direction) * magnitude,
            "dy": sin(direction) * magnitude,
        ])

        let icon = SKSpriteNode(texture: powerUpTexture(for: kind))
        icon.name = "powerUpIcon"
        icon.size = CGSize(width: 64, height: 64)
        icon.blendMode = .add
        powerUp.addChild(icon)

        let star = SKSpriteNode(imageNamed: "whitestar")
        star.name = "powerUpStar"
        star.size = CGSize(width: 98, height: 98)
        star.blendMode = .add
        star.zPosition = -1
        powerUp.addChild(star)
        pickupLayer.addChild(powerUp)
    }

    private func powerUpTexture(for kind: PowerUpKind) -> SKTexture {
        let frame: Int = switch kind {
        case .reverseShooter: 2
        case .sideShooters: 3
        case .extraCannon: 0
        case .fasterShots: 5
        case .extraPlayer: 6
        case .extraBomb: 8
        case .shield: 9
        case .superShots: 7
        case .bouncyShots: 10
        }
        let sheet = SKTexture(imageNamed: "powerups")
        let column = frame % 2
        let rowFromTop = frame / 2
        let texture = SKTexture(
            rect: CGRect(
                x: CGFloat(column) / 2,
                y: CGFloat(7 - rowFromTop) / 8,
                width: 1.0 / 2.0,
                height: 1.0 / 8.0
            ),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }

    private func updatePowerUps() {
        let powerUps = pickupLayer.children.filter { $0.name == "powerUp" }
        for powerUp in powerUps where powerUp.parent != nil {
            if squaredDistance(powerUp.position, player.position) < 20 * 20 + 16 * 16 {
                collect(powerUp)
                continue
            }
            var freezeFrames = (powerUp.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                powerUp.userData?["freezeFrames"] = freezeFrames
                continue
            }

            var lifeFrames = (powerUp.userData?["lifeFrames"] as? NSNumber)?.intValue ?? 0
            lifeFrames += 1
            powerUp.userData?["lifeFrames"] = lifeFrames
            let rawKind = (powerUp.userData?["kind"] as? NSNumber)?.intValue ?? 0
            let kind = PowerUpKind(rawValue: rawKind) ?? .reverseShooter
            var velocity = CGVector(
                dx: CGFloat((powerUp.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((powerUp.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )

            powerUp.position.x += velocity.dx
            powerUp.position.y += velocity.dy
            bounce(powerUp, velocity: &velocity, margin: 8)

            if updatePowerUpForBlackHoles(powerUp, velocity: &velocity) {
                continue
            }

            if Int.random(in: 0...100) > 96 {
                let towardPlayer = CGVector(
                    dx: player.position.x - powerUp.position.x,
                    dy: player.position.y - powerUp.position.y
                ).normalized
                velocity = velocity + towardPlayer
            }

            if kind.rawValue > 1, lifeFrames > 200,
               let other = powerUps.first(where: {
                   $0 !== powerUp && $0.parent != nil &&
                   ((($0.userData?["kind"] as? NSNumber)?.intValue ?? 0) > 1)
               }) {
                let towardOther = CGVector(
                    dx: other.position.x - powerUp.position.x,
                    dy: other.position.y - powerUp.position.y
                )
                if lifeFrames > 300 {
                    velocity.dx += towardOther.dx == 0 ? 0 : copysign(1.0 / 64.0, towardOther.dx)
                    velocity.dy += towardOther.dy == 0 ? 0 : copysign(1.0 / 64.0, towardOther.dy)
                    var otherVelocity = CGVector(
                        dx: CGFloat((other.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                        dy: CGFloat((other.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
                    )
                    otherVelocity.dx -= towardOther.dx == 0 ? 0 : copysign(1.0 / 64.0, towardOther.dx)
                    otherVelocity.dy -= towardOther.dy == 0 ? 0 : copysign(1.0 / 64.0, towardOther.dy)
                    other.userData?["dx"] = otherVelocity.dx
                    other.userData?["dy"] = otherVelocity.dy
                }
                if towardOther.length < 23 {
                    let position = powerUp.position
                    powerUp.removeFromParent()
                    other.removeFromParent()
                    spawnGenerator(
                        kind: .butterfly,
                        at: position,
                        freezeFrames: 20,
                        rate: 20,
                        generatorSize: 20
                    )
                    continue
                }
            } else if kind.rawValue < 2, lifeFrames > 400 {
                let position = powerUp.position
                powerUp.removeFromParent()
                spawnEnemy(kind: .butterfly, at: position, freezeFrames: 30, closeToPlayer: true)
                continue
            }

            if velocity.length > 4 { velocity = velocity.normalized * 4 }
            powerUp.userData?["dx"] = velocity.dx
            powerUp.userData?["dy"] = velocity.dy
            (powerUp.childNode(withName: "powerUpStar") as? SKSpriteNode)?.zRotation =
                CGFloat(lifeFrames * 6) * .pi / 180
            if let icon = powerUp.childNode(withName: "powerUpIcon") as? SKSpriteNode {
                icon.color = lifeFrames > 360 ? .purple : .white
                icon.colorBlendFactor = lifeFrames > 360 ? 0.55 : 0
            }
            if let star = powerUp.childNode(withName: "powerUpStar") as? SKSpriteNode {
                star.color = lifeFrames > 300 ? .purple : .white
                star.colorBlendFactor = lifeFrames > 300 ? 0.55 : 0
            }
        }
    }

    private func updatePowerUpForBlackHoles(_ powerUp: SKNode, velocity: inout CGVector) -> Bool {
        for blackHole in enemyLayer.children where blackHole.name == "enemy"
            && blackHole.userData?["kind"] as? String == EnemyKind.blackHole.rawValue
            && ((blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false) {
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            let difference = CGVector(
                dx: blackHole.position.x - powerUp.position.x,
                dy: blackHole.position.y - powerUp.position.y
            )
            let distance = max(0.001, difference.length)
            guard distance < 75 + blackHoleSize * 5 else { continue }
            velocity = velocity + difference.normalized * ((400 - distance) / 4_096)
            if distance < 12 + blackHoleSize {
                let position = powerUp.position
                powerUp.removeFromParent()
                createExplosion(at: position, color: .purple)
                growBlackHole(blackHole, amount: 1)
                return true
            }
        }
        return false
    }

    private func collect(_ powerUp: SKNode) {
        guard powerUp.parent != nil else { return }
        let position = powerUp.position
        powerUp.removeFromParent()
        let rawKind = (powerUp.userData?["kind"] as? NSNumber)?.intValue ?? PowerUpKind.extraBomb.rawValue
        let kind = PowerUpKind(rawValue: rawKind) ?? .extraBomb
        let events = session.collectPowerUp(kind)
        createExplosion(at: position, color: .white)
        run(.playSoundFileNamed("bonus1.wav", waitForCompletion: false))
        for event in events {
            if case let .powerUpCollected(_, message) = event {
                messageLabel.text = message
                messageLabel.isHidden = false
                messageLabel.run(.sequence([.wait(forDuration: 0.8), .hide()]))
            } else {
                handleProgressionEvent(event)
            }
        }
        updateHUD()
    }

    @discardableResult
    private func hitPlayer(at position: CGPoint) -> Bool {
        guard session.shieldFrames == 0, lastUpdateTime >= playerInvulnerableUntil else { return false }
        session.registerPlayerHit()
        updateHUD()
        createExplosion(at: position, color: .magenta)

        if session.isGameOver {
            player.isHidden = true
            mouseIsFiring = false
            touchIsFiring = false
            messageLabel.text = "GAME OVER\nPunkte: \(session.score)\nR oder Tippen zum Neustart"
            messageLabel.isHidden = false
            run(.playSoundFileNamed("gameover.wav", waitForCompletion: false))
            return true
        }

        playerInvulnerableUntil = lastUpdateTime + 2
        player.removeAllActions()
        let blink = SKAction.sequence([
            .fadeAlpha(to: 0.18, duration: 0.08),
            .fadeAlpha(to: 1, duration: 0.08),
        ])
        player.run(.repeat(blink, count: 10))
        return true
    }

    private func createExplosion(at position: CGPoint, color: SKColor) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = SKTexture(imageNamed: "particle")
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBirthRate = 240
        emitter.numParticlesToEmit = 26
        emitter.particleLifetime = 0.55
        emitter.particleLifetimeRange = 0.2
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 150
        emitter.particleSpeedRange = 80
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = 0.7
        emitter.particleScaleRange = 0.35
        emitter.particleScaleSpeed = -0.8
        effectLayer.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1), .removeFromParent()]))
    }

    private func updateHUD() {
        scoreLabel.text = String(format: "%09d   ×%d", session.score, session.multiplier)
        statusLabel.text = "LEBEN \(session.lives)   BOMBEN \(session.bombs)"
    }

    func setKey(_ keyCode: UInt16, pressed: Bool, isRepeat: Bool) {
        if pressed {
            pressedKeys.insert(keyCode)
        } else {
            pressedKeys.remove(keyCode)
        }

        guard pressed, !isRepeat else { return }
        if keyCode == 49 {
            triggerBomb()
        } else if keyCode == 15, session.isGameOver {
            restartGame()
        }
    }

    func setPointerLocation(_ location: CGPoint) {
        pointerLocation = location
        hasPointerLocation = true
    }

    func setMouseFiring(_ firing: Bool) {
        if firing, session.isGameOver {
            restartGame()
            return
        }
        mouseIsFiring = firing
    }

    func triggerBomb() {
        guard session.useBomb() else { return }
        bombCooldownFrames = 60
        let enemies = enemyLayer.children.filter { $0.name == "enemy" || $0.name == "generator" }
        for enemy in enemies {
            destroyEnemy(enemy, playSound: false, awardPoints: false)
        }

        let ring = SKShapeNode(circleOfRadius: 12)
        ring.position = player.position
        ring.strokeColor = .white
        ring.lineWidth = 5
        ring.glowWidth = 7
        effectLayer.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 70, duration: 0.42),
                .fadeOut(withDuration: 0.42),
            ]),
            .removeFromParent(),
        ]))
        run(.playSoundFileNamed("Explo1.wav", waitForCompletion: false))
        updateHUD()
    }

    private var keyboardMovement: CGVector {
        var vector = CGVector.zero
        if pressedKeys.contains(0) || pressedKeys.contains(123) && pressedKeys.contains(56) {
            vector.dx -= 1
        }
        if pressedKeys.contains(2) || pressedKeys.contains(124) && pressedKeys.contains(56) {
            vector.dx += 1
        }
        if pressedKeys.contains(13) || pressedKeys.contains(126) && pressedKeys.contains(56) {
            vector.dy += 1
        }
        if pressedKeys.contains(1) || pressedKeys.contains(125) && pressedKeys.contains(56) {
            vector.dy -= 1
        }
        return vector.length > 1 ? vector.normalized : vector
    }

    private var keyboardAim: CGVector {
        var vector = CGVector.zero
        if pressedKeys.contains(123), !pressedKeys.contains(56) { vector.dx -= 1 }
        if pressedKeys.contains(124), !pressedKeys.contains(56) { vector.dx += 1 }
        if pressedKeys.contains(126), !pressedKeys.contains(56) { vector.dy += 1 }
        if pressedKeys.contains(125), !pressedKeys.contains(56) { vector.dy -= 1 }
        return vector.length > 1 ? vector.normalized : vector
    }

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if session.isGameOver {
            restartGame()
            return
        }

        for touch in touches {
            let location = touch.location(in: self)
            if bombButton.contains(location) {
                triggerBomb()
            } else if location.x < size.width / 2, movementTouch == nil {
                movementTouch = touch
                movementTouchOrigin = location
                movementStick.show(at: location)
            } else if aimingTouch == nil {
                aimingTouch = touch
                aimingTouchOrigin = location
                aimingStick.show(at: location)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if touch === movementTouch {
                touchMovement = stickVector(from: movementTouchOrigin, to: location)
                movementStick.update(vector: touchMovement)
            } else if touch === aimingTouch {
                touchAim = stickVector(from: aimingTouchOrigin, to: location).normalized
                touchIsFiring = touchAim.length > 0
                aimingStick.update(vector: stickVector(from: aimingTouchOrigin, to: location))
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            if touch === movementTouch {
                movementTouch = nil
                touchMovement = .zero
                movementStick.hide()
            } else if touch === aimingTouch {
                aimingTouch = nil
                touchAim = .zero
                touchIsFiring = false
                aimingStick.hide()
            }
        }
    }

    private func stickVector(from origin: CGPoint, to location: CGPoint) -> CGVector {
        let vector = CGVector(dx: location.x - origin.x, dy: location.y - origin.y)
        let magnitude = min(1, vector.length / 62)
        return vector.normalized * magnitude
    }
    #endif
}

@MainActor
private final class VirtualStickNode: SKNode {
    private let base = SKShapeNode(circleOfRadius: 52)
    private let knob = SKShapeNode(circleOfRadius: 22)

    override init() {
        super.init()
        base.fillColor = SKColor(white: 0.1, alpha: 0.38)
        base.strokeColor = SKColor(white: 0.8, alpha: 0.55)
        base.lineWidth = 2
        knob.fillColor = SKColor(red: 0.15, green: 0.5, blue: 1, alpha: 0.7)
        knob.strokeColor = .white
        knob.lineWidth = 2
        addChild(base)
        addChild(knob)
        isHidden = true
        zPosition = 10
    }

    required init?(coder decoder: NSCoder) {
        nil
    }

    func show(at position: CGPoint) {
        self.position = position
        knob.position = .zero
        isHidden = false
    }

    func update(vector: CGVector) {
        knob.position = CGPoint(x: vector.dx * 42, y: vector.dy * 42)
    }

    func hide() {
        isHidden = true
        knob.position = .zero
    }
}
