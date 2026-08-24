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

        var initialMagnitude: Range<CGFloat> {
            switch self {
            case .pinwheel, .snake, .interceptor: 0.5..<2
            case .cube: 0.25..<2
            case .diamond, .triangle: 0.25..<1
            case .greenSquare: 2..<4
            case .seeker, .butterfly: 3..<6
            case .blackHole: 0.05..<0.5
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
    private let gridRenderer = GridRenderer()
    private let particleRenderer = ParticleRenderer()
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
    private let playerShield = SKShapeNode(circleOfRadius: 8)
    private let readyRings = (0..<3).map { _ in SKShapeNode(circleOfRadius: 1) }

    private var session = GameSession()
    private var configured = false
    private var pressedKeys = Set<UInt16>()
    private var pointerLocation = CGPoint(x: 512, y: 600)
    private var hasPointerLocation = false
    private var mouseIsFiring = false
    private var mouseBombIsHeld = false
    private var touchMovement = CGVector.zero
    private var touchAim = CGVector.zero
    private var touchIsFiring = false
    private var currentAim = CGVector(dx: 0, dy: 1)
    private var mouseAutofireArmed = false
    private var keyboardAutofireArmed = false
    private var playerMotion = PlayerMotionState()
    private var gridSimulation = GridSimulation(arenaSize: CGSize(width: 1_024, height: 768))
    private var particleSimulation = ParticleSimulation(arenaSize: CGSize(width: 1_024, height: 768))
    private var gridStyle = GridStyle.pointsSolid

    private var lastUpdateTime: TimeInterval = 0
    private var shotTimerFrames = 0
    private var deathFramesRemaining = 0
    private var getReadyFrame = -1
    private var destroyedEnemyCount = 0
    private var fixedTimeAccumulator: TimeInterval = 0
    private var simulationFrame = GameDifficulty.medium.initialFrame
    private var bombCooldownFrames = 20
    private var spawnDirector = SpawnDirector()
    private var spawnRandom = SystemRandomNumberGenerator()
    private var cyclingRed = 250
    private var cyclingGreen = 20
    private var cyclingBlue = 30
    private var cyclingRedDelta: CGFloat = -3
    private var cyclingGreenDelta: CGFloat = 5
    private var cyclingBlueDelta: CGFloat = 7

    #if os(iOS)
    private var movementTouch: UITouch?
    private var aimingTouch: UITouch?
    private var movementTouchOrigin = CGPoint.zero
    private var aimingTouchOrigin = CGPoint.zero
    #endif

    override init(size: CGSize) {
        super.init(size: size)
        gridSimulation = GridSimulation(arenaSize: size)
        particleSimulation = ParticleSimulation(arenaSize: size)
        scaleMode = .aspectFit
        backgroundColor = .black
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        gridSimulation = GridSimulation(arenaSize: size)
        particleSimulation = ParticleSimulation(arenaSize: size)
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
        worldLayer.addChild(particleRenderer.node)
        worldLayer.addChild(enemyLayer)
        worldLayer.addChild(projectileLayer)
        worldLayer.addChild(pickupLayer)
        worldLayer.addChild(effectLayer)
        addChild(hudLayer)

        gridLayer.zPosition = -10
        gridLayer.addChild(gridRenderer.node)
        particleRenderer.node.zPosition = 5
        enemyLayer.zPosition = 10
        projectileLayer.zPosition = 20
        pickupLayer.zPosition = 15
        effectLayer.zPosition = 30
        hudLayer.zPosition = 100
    }

    private func setupArena() {
        renderGrid()

        for index in 0...300 {
            let depth = 2 + CGFloat(index % 8) / 4
            let brightness = min(1, (480 / depth) / 255)
            let star = SKShapeNode(rectOf: CGSize(width: 2, height: 2))
            star.fillColor = SKColor(white: brightness, alpha: 1)
            star.strokeColor = .clear
            star.alpha = 0.8
            star.position = CGPoint(
                x: CGFloat(Int.random(in: -100...Int(size.width + 100))),
                y: CGFloat(Int.random(in: -100...Int(size.height + 100)))
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
        playerShield.name = "playerShield"
        playerShield.fillColor = SKColor(red: 0.4, green: 0.8, blue: 1, alpha: 1)
        playerShield.strokeColor = .clear
        playerShield.alpha = 0.48
        playerShield.zPosition = 4
        playerShield.isHidden = true
        worldLayer.addChild(playerShield)

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

        for ring in readyRings {
            ring.name = "readyRing"
            ring.fillColor = .clear
            ring.strokeColor = SKColor(red: 1, green: 1, blue: 0.78, alpha: 1)
            ring.lineWidth = 2
            ring.glowWidth = 3
            ring.zPosition = 3
            ring.isHidden = true
            worldLayer.addChild(ring)
        }
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
        deathFramesRemaining = 0
        getReadyFrame = -1
        fixedTimeAccumulator = 0
        simulationFrame = session.difficulty.initialFrame
        bombCooldownFrames = 20
        player.removeAllActions()
        player.alpha = 1
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        playerMotion.reset()
        gridSimulation.reset()
        particleSimulation.reset()
        playerShield.isHidden = true
        playerShield.position = player.position
        readyRings.forEach { $0.isHidden = true }
        messageLabel.isHidden = true
        touchMovement = .zero
        touchAim = .zero
        touchIsFiring = false
        mouseAutofireArmed = false
        keyboardAutofireArmed = false
        mouseBombIsHeld = false
        currentAim = CGVector(dx: 0, dy: 1)
        updateHUD()
        startGetReadySequence()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            renderGrid()
            particleRenderer.render(particleSimulation)
            return
        }

        let deltaTime = min(0.1, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        guard !session.isGameOver else {
            renderGrid()
            particleRenderer.render(particleSimulation)
            return
        }
        fixedTimeAccumulator += deltaTime
        while fixedTimeAccumulator >= 0.02 {
            simulateFrame()
            fixedTimeAccumulator -= 0.02
        }
        renderGrid()
        particleRenderer.render(particleSimulation)
    }

    private func simulateFrame() {
        updateParticleSimulation()
        cycleColors()
        cycleColors()
        gridSimulation.update()
        if deathFramesRemaining > 0 {
            advanceDeathSequence()
            return
        }
        if getReadyFrame >= 0 {
            advanceGetReadySequence()
            return
        }

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
        if bombCooldownFrames == 0,
           pressedKeys.contains(49) || mouseBombIsHeld {
            triggerBomb()
        }
        updatePlayer()
        updatePlayerTrails()
        updateAim()
        updatePlayerShield()
        fireIfNeeded()
        pullPlayerTowardBlackHoles()
        checkTriangleBondPlayerCollision()
        if stopGameplayFrameForDeath() { return }
        updateGenerators()
        if stopGameplayFrameForDeath() { return }
        updateEnemies(kinds: [
            .greenSquare, .pinwheel, .diamond, .cube, .seeker,
            .snake, .interceptor, .butterfly, .triangle,
        ])
        if stopGameplayFrameForDeath() { return }
        updateTrianglePairsAndBonds()
        updatePowerUps()
        updateEnemies(kinds: [.blackHole])
        if stopGameplayFrameForDeath() { return }
        updateProjectiles()
        simulationFrame += 1
    }

    private func stopGameplayFrameForDeath() -> Bool {
        guard deathFramesRemaining > 0 else { return false }
        simulationFrame += 1
        return true
    }

    private func renderGrid() {
        gridRenderer.render(
            simulation: gridSimulation,
            style: gridStyle,
            solidColor: SKColor(red: 32 / 255, green: 80 / 255, blue: 200 / 255, alpha: 1),
            cyclingColor: SKColor(
                red: CGFloat(cyclingRed) / 255,
                green: CGFloat(cyclingGreen) / 255,
                blue: CGFloat(cyclingBlue) / 255,
                alpha: 1
            ),
            opacity: 0.85
        )
    }

    private func updateParticleSimulation() {
        for blackHole in enemies(of: .blackHole)
            where (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false {
            let blackHoleSize = CGFloat(
                (blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20
            )
            particleSimulation.applyBlackHole(
                at: blackHole.position,
                size: blackHoleSize,
                frame: simulationFrame
            )
        }

        if deathFramesRemaining > 0 {
            let deathFrame = 100 - deathFramesRemaining
            guard deathFrame.isMultiple(of: 2) else { return }
        }
        particleSimulation.update()
    }

    private func updatePlayer() {
        let keyboard = keyboardMovement
        let combined = keyboard.length > 0 ? keyboard : touchMovement
        let result = playerMotion.advance(
            from: player.position,
            input: combined,
            arenaSize: size
        )
        player.position = result.position
        if result.movement.length > 0 {
            player.zRotation = atan2(result.movement.dy, result.movement.dx) - .pi / 2
        }
        if abs(result.movement.dx) > 0.1 || abs(result.movement.dy) > 0.1 {
            createPlayerTrail(movement: result.movement)
        }
    }

    private func createPlayerTrail(movement: CGVector) {
        for index in 0..<3 {
            let angle = CGFloat(simulationFrame * 12 + index * 45) * .pi / 180
            let trail = SKSpriteNode(imageNamed: "particle")
            trail.name = "playerTrail"
            trail.color = SKColor(red: 240 / 255, green: 240 / 255, blue: 100 / 255, alpha: 1)
            trail.colorBlendFactor = 1
            trail.blendMode = .add
            trail.alpha = 0.23
            trail.size = CGSize(width: 30, height: 30)
            trail.position = CGPoint(
                x: player.position.x - movement.dx * 12 + sin(angle) * 8,
                y: player.position.y - movement.dy * 12 + cos(angle) * 8
            )
            trail.userData = NSMutableDictionary(dictionary: [
                "trailActive": 40,
                "trailDX": -movement.dx * 1.5,
                "trailDY": -movement.dy * 1.5,
                "trailR": 240,
                "trailG": 240,
                "trailB": 100,
            ])
            effectLayer.addChild(trail)
        }
    }

    private func updatePlayerTrails() {
        for case let trail as SKSpriteNode in effectLayer.children where trail.name == "playerTrail" {
            var active = (trail.userData?["trailActive"] as? NSNumber)?.intValue ?? 0
            active -= 1
            trail.userData?["trailActive"] = active
            if active < 28 {
                var red = (trail.userData?["trailR"] as? NSNumber)?.intValue ?? 0
                var green = (trail.userData?["trailG"] as? NSNumber)?.intValue ?? 0
                var blue = (trail.userData?["trailB"] as? NSNumber)?.intValue ?? 0
                var dx = CGFloat((trail.userData?["trailDX"] as? NSNumber)?.doubleValue ?? 0)
                var dy = CGFloat((trail.userData?["trailDY"] as? NSNumber)?.doubleValue ?? 0)

                red = Int(CGFloat(red) * 0.91)
                green = Int(CGFloat(green) * 0.88)
                blue = Int(CGFloat(blue) * 0.86)
                trail.position.x += dx
                trail.position.y += dy
                dx *= 0.999
                dy *= 0.999

                trail.userData?["trailR"] = red
                trail.userData?["trailG"] = green
                trail.userData?["trailB"] = blue
                trail.userData?["trailDX"] = dx
                trail.userData?["trailDY"] = dy
                trail.color = SKColor(
                    red: CGFloat(red) / 255,
                    green: CGFloat(green) / 255,
                    blue: CGFloat(blue) / 255,
                    alpha: 1
                )
            }
            if active <= 0 {
                trail.removeFromParent()
            }
        }
    }

    private func updatePlayerShield() {
        playerShield.position = player.position
        let frames = session.shieldFrames
        playerShield.isHidden = frames == 0 || (frames <= 60 && frames % 15 <= 7)
        playerShield.setScale(2.75 + CGFloat(frames) / 128)
        playerShield.fillColor = SKColor(
            red: CGFloat(cyclingRed) / 255,
            green: CGFloat(cyclingGreen) / 255,
            blue: CGFloat(cyclingBlue) / 255,
            alpha: 1
        )
    }

    private func cycleColors() {
        cycleColor(value: &cyclingRed, delta: &cyclingRedDelta)
        cycleColor(value: &cyclingGreen, delta: &cyclingGreenDelta)
        cycleColor(value: &cyclingBlue, delta: &cyclingBlueDelta)
    }

    private func cycleColor(value: inout Int, delta: inout CGFloat) {
        value = Int(CGFloat(value) + delta)
        if value < 0 {
            value = 0
            delta = CGFloat.random(in: 1..<10)
        } else if value > 255 {
            value = 255
            delta = -CGFloat.random(in: 1..<10)
        }
    }

    private func updateAim() {
        let arrowAim = keyboardAim
        if arrowAim.length > 0 {
            currentAim = arrowAim.normalized
            keyboardAutofireArmed = true
        } else if touchAim.length > 0 {
            currentAim = touchAim.normalized
        } else if hasPointerLocation, mouseIsFiring {
            let pointerAim = CGVector(
                dx: pointerLocation.x - player.position.x,
                dy: pointerLocation.y - player.position.y
            )
            if pointerAim.length > 2 {
                currentAim = pointerAim.normalized
                mouseAutofireArmed = true
            }
        }

    }

    private func fireIfNeeded() {
        shotTimerFrames = max(0, shotTimerFrames - 1)
        let shouldFire = mouseIsFiring
            || touchIsFiring
            || keyboardAim.length > 0
            || mouseAutofireArmed
            || keyboardAutofireArmed
        guard shotTimerFrames == 0 else { return }
        shotTimerFrames = PlayerWeaponRule.timerFrames(cannons: session.cannons)
        guard shouldFire else { return }

        let launches = PlayerWeaponRule.launches(
            aim: currentAim,
            cannons: session.cannons,
            shotSpeed: session.shotSpeed,
            reverseShooter: session.reverseShooterFrames > 0,
            sideShooters: session.sideShooterFrames > 0
        )
        for launch in launches {
            spawnProjectile(direction: launch.direction, speed: launch.speed)
        }
        run(.playSoundFileNamed("shotborn.wav", waitForCompletion: false))
    }

    private func spawnProjectile(direction: CGVector, speed: CGFloat) {
        guard projectileLayer.children.count < 500 else { return }
        let projectile = SKSpriteNode(imageNamed: "yellowshot")
        projectile.name = "projectile"
        projectile.size = CGSize(width: 32, height: 32)
        projectile.blendMode = .add
        projectile.color = projectileColor
        projectile.colorBlendFactor = 1
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
            let snakeNodeCount = matchingEnemyCount + enemyLayer.children.filter {
                $0.name == "snakeTail"
            }.count
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
        let initialRotation = switch kind {
        case .greenSquare, .pinwheel: 90
        default: Int.random(in: 0...359)
        }
        let initialDirection = Int.random(in: 0...359)
        let initialAngle = kind == .snake
            ? CGFloat(initialRotation) * .pi / 180
            : CGFloat(initialDirection) * .pi / 180
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
                ? 16
                : interceptorTurn,
            "interceptorLastPlayed": 0,
            "seekerMean": 0,
            "triangleResist": false,
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
            return CGPoint(x: randomCoordinate(30...80), y: size.height - randomCoordinate(30...80))
        case .topRight:
            return CGPoint(x: size.width - randomCoordinate(30...80), y: size.height - randomCoordinate(30...80))
        case .bottomRight:
            return CGPoint(x: size.width - randomCoordinate(30...80), y: randomCoordinate(30...80))
        case .bottomLeft:
            return CGPoint(x: randomCoordinate(30...80), y: randomCoordinate(30...80))
        case .nearPlayer:
            let angle = CGFloat(Int.random(in: 0...360)) * .pi / 180
            return CGPoint(x: player.position.x + cos(angle) * 240, y: player.position.y + sin(angle) * 240)
        default:
            return CGPoint(
                x: randomCoordinate(30...Int(size.width - 30)),
                y: randomCoordinate(30...Int(size.height - 30))
            )
        }
    }

    private func randomCoordinate(_ range: ClosedRange<Int>) -> CGFloat {
        CGFloat(Int.random(in: range))
    }

    private func safePosition(_ proposed: CGPoint, minimumPlayerDistance: CGFloat) -> CGPoint {
        var result = CGPoint(
            x: min(size.width - 20, max(20, proposed.x)),
            y: min(size.height - 20, max(20, proposed.y))
        )
        var fromSpawnToPlayer = CGVector(
            dx: player.position.x - result.x,
            dy: player.position.y - result.y
        )

        if minimumPlayerDistance == 40 {
            var distance = fromSpawnToPlayer.length + 0.001
            while distance < minimumPlayerDistance {
                if distance < 0.001 {
                    let angle = CGFloat(Int.random(in: 0...360)) * .pi / 180
                    result = CGPoint(
                        x: player.position.x + cos(angle) * 10,
                        y: player.position.y + sin(angle) * 10
                    )
                } else {
                    result.x -= fromSpawnToPlayer.dx / distance * 10
                    result.y -= fromSpawnToPlayer.dy / distance * 10
                }
                fromSpawnToPlayer = CGVector(
                    dx: player.position.x - result.x,
                    dy: player.position.y - result.y
                )
                distance = fromSpawnToPlayer.length
            }
        } else {
            while fromSpawnToPlayer.dx * fromSpawnToPlayer.dx
                    + fromSpawnToPlayer.dy * fromSpawnToPlayer.dy
                    < minimumPlayerDistance * minimumPlayerDistance {
                let angle = CGFloat(Int.random(in: 0...(360 * 8))) / 8 * .pi / 180
                result = CGPoint(
                    x: player.position.x + sin(angle) * minimumPlayerDistance,
                    y: player.position.y + cos(angle) * minimumPlayerDistance
                )
                result.x = min(size.width - 20, max(20, result.x))
                result.y = min(size.height - 20, max(20, result.y))
                fromSpawnToPlayer = CGVector(
                    dx: player.position.x - result.x,
                    dy: player.position.y - result.y
                )
            }
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
               hitPlayer(killer: generator) {
                continue
            }
            guard rotation.isMultiple(of: max(1, rate + 42 - health)) else { continue }
            gridSimulation.push(at: generator.position, radiusInPoints: 6, amount: 0.9)
            let offset = CGPoint(
                x: generator.position.x + randomCoordinate(-10...10),
                y: generator.position.y + randomCoordinate(-10...10)
            )
            let born = spawnEnemy(kind: kind, at: offset, freezeFrames: 5, closeToPlayer: true)
            if kind == .blackHole {
                born?.userData?["blackHoleSize"] = 10.0
            }
        }
    }

    private func updateEnemies(kinds: [EnemyKind]) {
        for requestedKind in kinds {
            if requestedKind == .snake {
                updateDyingSnakeSegments(maximumSpeed: session.enemySpeeds[.snake])
                if deathFramesRemaining > 0 { return }
            }
            if requestedKind == .triangle {
                pairEligibleTriangles()
            }
            let enemies = enemyLayer.children.filter {
                $0.name == "enemy" && $0.userData?["kind"] as? String == requestedKind.rawValue
            }
            for enemy in enemies {
            guard enemy.parent != nil else { continue }
            var maximumSpeed = CGFloat((enemy.userData?["speed"] as? NSNumber)?.doubleValue ?? 1)
            if requestedKind == .seeker {
                maximumSpeed += CGFloat((enemy.userData?["seekerMean"] as? NSNumber)?.intValue ?? 0)
            }
            if requestedKind == .snake {
                updateSnakeSegments(for: enemy, maximumSpeed: maximumSpeed)
                if deathFramesRemaining > 0 { continue }
            }
            var freezeFrames = (enemy.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                enemy.userData?["freezeFrames"] = freezeFrames
                updateEnemyVisual(enemy, kind: requestedKind, rotation: (enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0)
                continue
            }

            let kind = EnemyKind(rawValue: enemy.userData?["kind"] as? String ?? "") ?? .pinwheel
            var velocity = CGVector(
                dx: CGFloat((enemy.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((enemy.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )
            var rotation = (enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0
            rotation = switch kind {
            case .interceptor: (rotation + 16) % 360
            case .triangle: rotation + 2
            default: rotation + 1
            }

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

            let playerDifference = CGVector(
                dx: player.position.x - enemy.position.x,
                dy: player.position.y - enemy.position.y
            )
            let towardPlayer = playerDifference / (playerDifference.length + 0.001)

            switch kind {
            case .pinwheel:
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .diamond:
                // BlitzMax Rand is integer-valued, so Rand(-0.2, 0.2) is always zero.
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
                updateBlackHole(enemy, velocity: &velocity, maximumSpeed: maximumSpeed)
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
                if CGFloat(Int.random(in: 1...100)) > 95 - maximumSpeed * 8 {
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
                var lastPlayed = (enemy.userData?["interceptorLastPlayed"] as? NSNumber)?.intValue ?? 0
                if turnRemaining == 0, lastPlayed == 0 {
                    lastPlayed = 60
                    run(.playSoundFileNamed("shield1.wav", waitForCompletion: false))
                }
                if lastPlayed > 0 { lastPlayed -= 1 }
                let headingRadians = heading * .pi / 180
                let facing = CGVector(dx: cos(headingRadians), dy: sin(headingRadians))
                if abs(turnRemaining) < 20 {
                    velocity = velocity + facing * 2
                    gridSimulation.push(
                        at: CGPoint(
                            x: enemy.position.x + velocity.dx * 8,
                            y: enemy.position.y + velocity.dy * 8
                        ),
                        radiusInPoints: 4,
                        amount: 0.1
                    )
                } else {
                    velocity = (velocity + facing) * (0.265 + maximumSpeed / 20)
                }
                enemy.userData?["interceptorHeading"] = heading
                enemy.userData?["interceptorTurnRemaining"] = turnRemaining
                enemy.userData?["interceptorLastPlayed"] = lastPlayed
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
            if kind == .interceptor { updateInterceptorShieldVisual(enemy) }
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
                let twin = SKSpriteNode(imageNamed: EnemyKind.triangle.textureName)
                twin.name = "triangleTwin"
                twin.size = EnemyKind.triangle.size
                twin.blendMode = .add
                enemy.addChild(twin)
                second = twin
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
        let segmentsByIndex = Dictionary(uniqueKeysWithValues: segments.map {
            ((($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0), $0)
        })
        let orderedSegments = segments.sorted {
            (($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
                > (($1.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
        }

        for segment in orderedSegments {
            let index = (segment.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0
            let precedingPosition = index == 0
                ? head.position
                : segmentsByIndex[index - 1]?.position ?? head.position
            var freezeFrames = (segment.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                segment.userData?["freezeFrames"] = freezeFrames
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
            segment.zRotation = atan2(velocity.dy, velocity.dx) + .pi / 2
            if squaredDistance(segment.position, player.position) < 24 * 24,
               hitPlayer(killer: segment) {
                return
            }
        }
    }

    private func scheduleSnakeTailExplosion(for head: SKNode, awardPoints: Bool) {
        guard let headID = head.userData?["enemyID"] as? String else { return }
        let segments = enemyLayer.children.filter {
            $0.name == "snakeTail" && $0.userData?["snakeHeadID"] as? String == headID
        }
        let nearest = segments.min {
            (($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
                < (($1.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
        }
        nearest?.userData?["snakeDyingMove"] = awardPoints ? 30 : 300
    }

    private func updateDyingSnakeSegments(maximumSpeed: CGFloat) {
        let allSegments = enemyLayer.children.compactMap { $0 as? SKSpriteNode }
            .filter { $0.name == "snakeTail" }
        let dyingHeadIDs = Set(allSegments.compactMap { segment -> String? in
            guard segment.userData?["snakeDyingMove"] != nil else { return nil }
            return segment.userData?["snakeHeadID"] as? String
        })
        let chains = Dictionary(grouping: allSegments.filter {
            dyingHeadIDs.contains($0.userData?["snakeHeadID"] as? String ?? "")
        }) {
            $0.userData?["snakeHeadID"] as? String ?? ""
        }

        for chain in chains.values {
            let byIndex = Dictionary(uniqueKeysWithValues: chain.map {
                ((($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0), $0)
            })
            let ordered = chain.sorted {
                (($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
                    > (($1.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
            }
            for segment in ordered {
                let index = (segment.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0
                if let dyingMove = (segment.userData?["snakeDyingMove"] as? NSNumber)?.intValue {
                    let nextMove = dyingMove - 1
                    byIndex[index + 1]?.userData?["snakeDyingMove"] = nextMove
                    let position = segment.position
                    segment.removeFromParent()
                    emitParticles(
                        count: 8,
                        at: position,
                        kind: .random,
                        color: OriginalParticleColor.snakeTail
                    )
                    if nextMove < 50 {
                        run(.playSoundFileNamed("snakehit.wav", waitForCompletion: false))
                    }
                    continue
                }

                var freezeFrames = (segment.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
                if freezeFrames > 0 {
                    freezeFrames -= 1
                    segment.userData?["freezeFrames"] = freezeFrames
                    continue
                }
                guard let preceding = byIndex[index - 1] else { continue }
                var velocity = SnakeSegmentRule.velocity(
                    from: segment.position,
                    toward: preceding.position,
                    maximumSpeed: maximumSpeed
                )
                segment.position.x += velocity.dx
                segment.position.y += velocity.dy
                bounce(segment, velocity: &velocity, margin: 8)
                segment.userData?["dx"] = velocity.dx
                segment.userData?["dy"] = velocity.dy
                segment.zRotation = atan2(velocity.dy, velocity.dx) + .pi / 2
                if squaredDistance(segment.position, player.position) < 24 * 24,
                   hitPlayer(killer: segment) {
                    return
                }
            }
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
            ).length + 0.001
            if distance < 300 { velocity = velocity + towardPlayer }
            _ = applyBlackHoleInfluence(to: triangle, kind: .triangle, velocity: &velocity)
            return
        }

        let difference = CGVector(
            dx: partner.position.x - triangle.position.x,
            dy: partner.position.y - triangle.position.y
        )
        let distance = difference.length + 0.001
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

    private func pairEligibleTriangles() {
        let triangles = enemyLayer.children.filter {
            $0.name == "enemy"
                && $0.userData?["kind"] as? String == EnemyKind.triangle.rawValue
        }
        for triangle in triangles where trianglePartner(of: triangle) == nil {
            let freezeFrames = (triangle.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            guard freezeFrames == 0 else { continue }
            guard let partner = triangles.first(where: {
                $0 !== triangle
                    && trianglePartner(of: $0) == nil
                    && squaredDistance(triangle.position, $0.position) < 32 * 32
            }) else { continue }
            attachTriangles(triangle, partner)
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
                _ = hitPlayer()
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
        first.userData?["triangleResist"] = false
        second.userData?["trianglePartnerID"] = firstID
        second.userData?["triangleStrength"] = TriangleBondState.initialStrength
        second.userData?["triangleResist"] = true
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
            partner.userData?["triangleResist"] = false
        }
        triangle.userData?["trianglePartnerID"] = nil
        triangle.userData?["triangleStrength"] = 0
        triangle.userData?["triangleResist"] = false
    }

    private func updateInterceptorShieldVisual(_ interceptor: SKNode) {
        interceptor.childNode(withName: "interceptorShield")?.removeFromParent()
        let turnRemaining = (interceptor.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
        guard abs(turnRemaining) <= 4 else { return }

        let path = CGMutablePath()
        let rotation = CGFloat((interceptor.userData?["rotation"] as? NSNumber)?.intValue ?? 0)
        let phase = rotation / 360
        for index in 0...2 {
            let t = 1.5 + phase + CGFloat(index)
            let forward = 12 + 12 * t
            let halfWidth = abs(12 - 9 * t)
            path.move(to: CGPoint(x: forward, y: -halfWidth))
            path.addLine(to: CGPoint(x: forward, y: halfWidth))
        }
        let shield = SKShapeNode(path: path)
        shield.name = "interceptorShield"
        shield.strokeColor = SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.9)
        shield.lineWidth = 1
        shield.glowWidth = 2
        shield.zPosition = -1
        shield.zRotation = -.pi / 2
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
                if geometry.contains(
                    projectile.position,
                    projectileVelocity: projectileVelocity(projectile)
                ) {
                    let position = projectile.position
                    projectile.removeFromParent()
                    emitParticles(
                        count: 4,
                        at: position,
                        kind: .random,
                        color: projectileParticleColor
                    )
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
           let partner = trianglePartner(of: enemy) {
            let resists = (enemy.userData?["triangleResist"] as? NSNumber)?.boolValue ?? false
            guard !resists else { return false }
            for blackHole in enemies(of: .blackHole) {
                let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
                let difference = CGVector(
                    dx: blackHole.position.x - enemy.position.x,
                    dy: blackHole.position.y - enemy.position.y
                )
                let distance = difference.length + 0.001
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
            let distance = difference.length + 0.001
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

    private func updateBlackHole(
        _ blackHole: SKNode,
        velocity: inout CGVector,
        maximumSpeed: CGFloat
    ) {
        let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
        blackHole.setScale(max(0.25, 0.25 + blackHoleSize / 64))
        if (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false {
            gridSimulation.pull(
                at: blackHole.position,
                radiusInPoints: 5 + Int(blackHoleSize / 2),
                amount: 4
            )
        }

        for otherBlackHole in enemyLayer.children where otherBlackHole !== blackHole
            && otherBlackHole.name == "enemy"
            && otherBlackHole.userData?["kind"] as? String == EnemyKind.blackHole.rawValue {
            let otherSize = CGFloat((otherBlackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            var difference = CGVector(
                dx: otherBlackHole.position.x - blackHole.position.x,
                dy: otherBlackHole.position.y - blackHole.position.y
            )
            let distance = difference.length + 0.001
            var magnitude = min(8, max(1, (otherSize - blackHoleSize) / 8))
            if magnitude.isNaN { magnitude = 1 }
            guard distance < otherSize * 2 + blackHoleSize * 2 + 64 else { continue }
            difference = difference / distance * magnitude
            if distance < otherSize + blackHoleSize {
                difference.dx = -difference.dx - difference.dy * 0.25
                difference.dy = -difference.dy - difference.dx * 0.25
            }
            velocity = velocity + difference
            if velocity.length > maximumSpeed {
                velocity = velocity.normalized * maximumSpeed
            }
        }
    }

    private func growBlackHole(_ blackHole: SKNode, amount: CGFloat) {
        var blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
        let speedUp = BlackHoleRule.growthSpeedUp(frame: simulationFrame)
        blackHoleSize += amount * speedUp
        blackHole.userData?["blackHoleSize"] = blackHoleSize
        let wasActive = (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false
        blackHole.userData?["blackHoleActive"] = true
        if !wasActive {
            gridSimulation.push(at: blackHole.position, radiusInPoints: 6, amount: 1)
        }
        let absorbed = (blackHole.userData?["absorbCount"] as? NSNumber)?.intValue ?? 0
        blackHole.userData?["absorbCount"] = absorbed + 1

        if blackHoleSize > 64 {
            let position = blackHole.position
            blackHole.removeFromParent()
            for index in 0..<16 {
                let angle = CGFloat(index) * 22.5 * .pi / 180
                let seeker = spawnEnemy(
                    kind: .seeker,
                    at: CGPoint(
                        x: CGFloat(Int(position.x + cos(angle) * 20)),
                        y: CGFloat(Int(position.y + sin(angle) * 20))
                    ),
                    freezeFrames: 4,
                    closeToPlayer: true
                )
                seeker?.userData?["seekerMean"] = 1
            }
            for index in 0..<18 {
                let angle = CGFloat(index) * 20 * .pi / 180
                spawnEnemy(
                    kind: .butterfly,
                    at: CGPoint(
                        x: CGFloat(Int(position.x + cos(angle) * 30)),
                        y: CGFloat(Int(position.y + sin(angle) * 30))
                    ),
                    freezeFrames: 4,
                    closeToPlayer: true
                )
            }
            emitParticles(
                count: 36,
                at: position,
                kind: .random,
                color: OriginalParticleColor.blackHole,
                positionForIndex: { index in
                    let angle = CGFloat(index * 10) * .pi / 180
                    return CGPoint(
                        x: position.x + sin(angle) * 20,
                        y: position.y + cos(angle) * 20
                    )
                }
            )
        }
    }

    private func updateProjectiles() {
        for projectile in projectileLayer.children {
            guard projectile.parent != nil else { continue }
            if let sprite = projectile as? SKSpriteNode {
                sprite.color = projectileColor
                sprite.colorBlendFactor = 1
            }
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
                    createProjectileImpact(at: position)
                    break
                } else {
                    gridSimulation.push(
                        at: CGPoint(
                            x: projectile.position.x + velocity.dx * 2,
                            y: projectile.position.y + velocity.dy * 2
                        ),
                        radiusInPoints: 3,
                        amount: 0.025
                    )
                }
            }

            if projectile.parent != nil {
                projectile.userData?["dx"] = velocity.dx
                projectile.userData?["dy"] = velocity.dy
                projectile.zRotation = atan2(velocity.dy, velocity.dx)
            }
        }
    }

    private var projectileColor: SKColor {
        if session.superShotFrames > 0 {
            return SKColor(red: 200 / 255, green: 32 / 255, blue: 32 / 255, alpha: 1)
        }
        if session.bouncyShotFrames > 0 {
            return SKColor(red: 32 / 255, green: 200 / 255, blue: 32 / 255, alpha: 1)
        }
        return SKColor(red: 200 / 255, green: 200 / 255, blue: 128 / 255, alpha: 1)
    }

    private var projectileParticleColor: ParticleColor {
        if session.superShotFrames > 0 { return OriginalParticleColor.superShot }
        if session.bouncyShotFrames > 0 { return OriginalParticleColor.bouncyShot }
        return OriginalParticleColor.shot
    }

    private func createProjectileImpact(at position: CGPoint) {
        emitParticles(
            count: 4,
            at: position,
            kind: .random,
            color: projectileParticleColor
        )
        run(.playSoundFileNamed("shotwall.wav", waitForCompletion: false))
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
                if InterceptorShieldGeometry(center: interceptor.position, velocity: velocity).contains(
                    position,
                    projectileVelocity: projectileVelocity(projectile)
                ) {
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
              hitPlayer(killer: enemy) else { return false }
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
        let dangerDistance = danger.length + 0.001
        let bulletDistance = bulletBack.length + 0.001
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
            velocity = BlackHoleRule.deflectProjectile(
                position: projectile.position,
                velocity: velocity,
                blackHolePosition: blackHole.position,
                blackHoleSize: blackHoleSize
            )
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
            _ = hitPlayer(killer: enemy)
        } else if categories == Category.player | Category.powerUp {
            let powerUp = first.physicsBody?.categoryBitMask == Category.powerUp ? first : second
            collect(powerUp)
        }
    }

    private func damageEnemy(_ enemy: SKNode, projectile: SKNode) {
        guard enemy.parent != nil else { return }
        if enemy.name == "snakeTail" {
            emitParticles(
                count: 8,
                at: enemy.position,
                kind: .random,
                color: OriginalParticleColor.snakeTail
            )
            run(.playSoundFileNamed("tailhit.wav", waitForCompletion: false))
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
               InterceptorShieldGeometry(center: enemy.position, velocity: velocity).contains(
                   projectile.position,
                   projectileVelocity: projectileVelocity(projectile)
               ) {
                emitParticles(
                    count: 4,
                    at: projectile.position,
                    kind: .random,
                    color: projectileParticleColor
                )
                return
            }
        }
        var trianglePreHitParticlesEmitted = false
        if kind == .triangle, enemy.name == "enemy" {
            let strength = CGFloat((enemy.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                                   ?? Double(TriangleBondState.initialStrength))
            emitParticles(
                count: 4,
                at: enemy.position,
                kind: .threeDirections,
                color: ParticleColor(
                    red: 20 + Int(strength * 4),
                    green: 220 - Int(strength * 4),
                    blue: 0
                ),
                rotation: { _ in
                    CGFloat((enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0)
                }
            )
            trianglePreHitParticlesEmitted = true
            if trianglePartner(of: enemy) != nil {
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
                if bond.isBroken { detachTriangle(enemy) }
                return
            }
        }
        if kind == .blackHole, enemy.name == "enemy" {
            emitParticles(
                count: 4,
                at: enemy.position,
                kind: .random,
                color: OriginalParticleColor.blackHole
            )
            var blackHoleSize = CGFloat((enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            let wasActive = (enemy.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false
            enemy.userData?["blackHoleActive"] = true
            if !wasActive {
                gridSimulation.push(at: enemy.position, radiusInPoints: 6, amount: 1)
            }
            blackHoleSize -= 0.75
            enemy.userData?["blackHoleSize"] = blackHoleSize
            if blackHoleSize < 4 {
                gridSimulation.push(at: enemy.position, radiusInPoints: 8, amount: 2)
                let absorbed = (enemy.userData?["absorbCount"] as? NSNumber)?.intValue ?? 0
                enemy.userData?["score"] = BlackHoleRule.destructionScore(absorbedEnemies: absorbed)
                destroyEnemy(enemy, preHitParticlesEmitted: true)
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
                emitParticles(
                    count: 4,
                    at: enemy.position,
                    kind: .random,
                    color: particleColor(for: kind)
                )
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
            destroyEnemy(enemy, preHitParticlesEmitted: trianglePreHitParticlesEmitted)
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
        awardPoints: Bool = true,
        preHitParticlesEmitted: Bool = false
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
        if originalName == "enemy", kind != .blackHole {
            gridSimulation.shockwave(at: position)
        }
        emitEnemyDestructionParticles(
            for: enemy,
            kind: kind,
            originalName: originalName,
            preHitParticlesEmitted: preHitParticlesEmitted
        )
        enemy.removeFromParent()

        let progressionEvents = awardPoints
            ? session.registerEnemyDestroyed(baseScore: score)
            : []
        if awardPoints { destroyedEnemyCount += 1 }
        if awardPoints, kind == .cube, cubeTier == 0, originalName == "enemy" {
            for _ in 0..<3 {
                if let smallCube = spawnEnemy(
                    kind: .cube,
                    at: CGPoint(x: position.x - 30, y: position.y + randomCoordinate(-30...30)),
                    freezeFrames: 2,
                    closeToPlayer: true
                ) {
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

    private func emitEnemyDestructionParticles(
        for enemy: SKNode,
        kind: EnemyKind,
        originalName: String?,
        preHitParticlesEmitted: Bool
    ) {
        let position = enemy.position
        let rotation = CGFloat((enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0)

        if originalName == "generator" {
            emitParticles(
                count: 12,
                at: position,
                kind: .random,
                color: particleColor(for: kind)
            )
            return
        }

        switch kind {
        case .greenSquare:
            emitParticles(
                count: 16,
                at: position,
                kind: .eightDirections,
                color: OriginalParticleColor.greenSquare
            )
        case .pinwheel:
            emitParticles(
                count: 16,
                at: position,
                kind: .eightDirections,
                color: OriginalParticleColor.pinwheel,
                rotation: { _ in rotation }
            )
        case .diamond:
            emitParticles(
                count: 16,
                at: position,
                kind: .fourDirections,
                color: OriginalParticleColor.diamond,
                positionForIndex: { _ in
                    CGPoint(
                        x: position.x + CGFloat(Int.random(in: -8...8)),
                        y: position.y + CGFloat(Int.random(in: -8...8))
                    )
                }
            )
        case .cube:
            emitParticles(
                count: 16,
                at: position,
                kind: .fourDirections,
                color: OriginalParticleColor.cube,
                rotation: { _ in rotation }
            )
        case .seeker:
            emitParticles(
                count: 16,
                at: position,
                kind: .directed,
                color: OriginalParticleColor.seeker,
                rotation: { index in CGFloat(index * 24) + rotation }
            )
        case .blackHole:
            if !preHitParticlesEmitted {
                emitParticles(
                    count: 4,
                    at: position,
                    kind: .random,
                    color: OriginalParticleColor.blackHole
                )
            }
            emitParticles(
                count: 32,
                at: position,
                kind: .random,
                color: OriginalParticleColor.blackHole
            )
        case .triangle:
            if !preHitParticlesEmitted {
                let strength = CGFloat(
                    (enemy.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                        ?? Double(TriangleBondState.initialStrength)
                )
                emitParticles(
                    count: 4,
                    at: position,
                    kind: .threeDirections,
                    color: ParticleColor(
                        red: 20 + Int(strength * 4),
                        green: 220 - Int(strength * 4),
                        blue: 0
                    ),
                    rotation: { _ in rotation }
                )
            }
            emitParticles(
                count: 32,
                at: position,
                kind: .threeDirections,
                color: OriginalParticleColor.triangle
            )
        case .snake:
            emitParticles(
                count: 32,
                at: position,
                kind: .random,
                color: OriginalParticleColor.snake
            )
        case .interceptor:
            emitParticles(
                count: 16,
                at: position,
                kind: .eightDirections,
                color: OriginalParticleColor.interceptor
            )
        case .butterfly:
            emitParticles(
                count: 9,
                at: position,
                kind: .threeDirections,
                color: OriginalParticleColor.butterfly,
                rotation: { index in CGFloat(index * 120) + rotation }
            )
        }
    }

    private func particleColor(for kind: EnemyKind) -> ParticleColor {
        switch kind {
        case .greenSquare: OriginalParticleColor.greenSquare
        case .pinwheel: OriginalParticleColor.pinwheel
        case .diamond: OriginalParticleColor.diamond
        case .cube: OriginalParticleColor.cube
        case .seeker: OriginalParticleColor.seeker
        case .blackHole: OriginalParticleColor.blackHole
        case .triangle: OriginalParticleColor.triangle
        case .snake: OriginalParticleColor.snake
        case .interceptor: OriginalParticleColor.interceptor
        case .butterfly: OriginalParticleColor.butterfly
        }
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
                x: randomCoordinate(250...Int(size.width - 250)),
                y: randomCoordinate(150...Int(size.height - 150))
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
        let direction = CGFloat(Int.random(in: 0...359)) * .pi / 180
        let magnitude = CGFloat.random(in: 0.5..<2)
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
        gridSimulation.push(at: position, radiusInPoints: 6, amount: 1)
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
                let differenceToPlayer = CGVector(
                    dx: player.position.x - powerUp.position.x,
                    dy: player.position.y - powerUp.position.y
                )
                let towardPlayer = differenceToPlayer / (differenceToPlayer.length + 0.001)
                velocity = velocity + towardPlayer
            }

            if kind.rawValue > 1, lifeFrames > 200 {
                var didMerge = false
                for other in powerUps where other !== powerUp && other.parent != nil
                    && ((other.userData?["kind"] as? NSNumber)?.intValue ?? 0) > 1 {
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
                    if towardOther.dx * towardOther.dx + towardOther.dy * towardOther.dy < 16 * 16 + 16 * 16 {
                        other.removeFromParent()
                        didMerge = true
                        spawnGenerator(
                            kind: .butterfly,
                            at: powerUp.position,
                            freezeFrames: 20,
                            rate: 20,
                            generatorSize: 20
                        )
                    }
                }
                if didMerge {
                    let position = powerUp.position
                    powerUp.removeFromParent()
                    emitParticles(
                        count: 8,
                        at: position,
                        kind: .random,
                        color: OriginalParticleColor.powerUp
                    )
                    continue
                }
            } else if kind.rawValue < 2, lifeFrames > 400 {
                let position = powerUp.position
                powerUp.removeFromParent()
                spawnEnemy(kind: .butterfly, at: position, freezeFrames: 30)
                emitParticles(
                    count: 8,
                    at: position,
                    kind: .random,
                    color: OriginalParticleColor.powerUp
                )
                continue
            }

            let speed = velocity.length + 0.001
            if speed > 4 { velocity = velocity / speed * 4 }
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
            let distance = difference.length + 0.001
            guard distance < 75 + blackHoleSize * 5 else { continue }
            velocity = velocity + difference / distance * ((400 - distance) / 4_096)
            if distance < 12 + blackHoleSize {
                let position = powerUp.position
                let rotation = CGFloat(
                    ((powerUp.userData?["lifeFrames"] as? NSNumber)?.intValue ?? 0) * 6
                )
                powerUp.removeFromParent()
                emitParticles(
                    count: 15,
                    at: position,
                    kind: .directed,
                    color: OriginalParticleColor.powerUp,
                    rotation: { index in CGFloat(index * 24) + rotation }
                )
                growBlackHole(blackHole, amount: 1)
                return true
            }
        }
        return false
    }

    private func collect(_ powerUp: SKNode) {
        guard powerUp.parent != nil else { return }
        powerUp.removeFromParent()
        let rawKind = (powerUp.userData?["kind"] as? NSNumber)?.intValue ?? PowerUpKind.extraBomb.rawValue
        let kind = PowerUpKind(rawValue: rawKind) ?? .extraBomb
        let events = session.collectPowerUp(kind)
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

    private func startGetReadySequence() {
        getReadyFrame = 0
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        playerMotion.reset()
        player.isHidden = true
        player.alpha = 1
        playerShield.isHidden = true
        readyRings.forEach { $0.isHidden = true }
        messageLabel.text = "GET READY"
        messageLabel.setScale(1)
        messageLabel.isHidden = false
        run(.playSoundFileNamed("startup.wav", waitForCompletion: false))
    }

    private func advanceGetReadySequence() {
        let frame = getReadyFrame
        if frame < 60 {
            let pulse = abs(sin(CGFloat(frame) * .pi / 180))
            messageLabel.isHidden = false
            messageLabel.position = CGPoint(
                x: size.width / 2,
                y: size.height / 2 + pulse * 100
            )
            messageLabel.setScale(max(0.05, pulse * 3.2))
            messageLabel.fontColor = SKColor(
                red: 0,
                green: (55 + pulse * 200) / 255,
                blue: 0,
                alpha: 1
            )
            player.isHidden = true
            readyRings.forEach { $0.isHidden = true }
        } else {
            let ringFrame = frame - 60
            if ringFrame == 0 {
                gridSimulation.pull(at: player.position, radiusInPoints: 20, amount: 20)
            }
            messageLabel.isHidden = true
            player.isHidden = ringFrame <= 10
            let contractions: [CGFloat] = [6, 8, 12]
            for (ring, contraction) in zip(readyRings, contractions) {
                let radius = max(0, 300 - CGFloat(ringFrame) * contraction)
                ring.position = player.position
                ring.path = CGPath(
                    ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
                    transform: nil
                )
                ring.isHidden = radius == 0
            }
        }

        getReadyFrame += 1
        if getReadyFrame >= 100 {
            getReadyFrame = -1
            readyRings.forEach { $0.isHidden = true }
            messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
            messageLabel.setScale(1)
            messageLabel.isHidden = true
            player.isHidden = false
            session.grantRespawnShield()
            updatePlayerShield()
        }
    }

    private func advanceDeathSequence() {
        deathFramesRemaining -= 1
        guard deathFramesRemaining == 0 else { return }

        enemyLayer.removeAllChildren()
        projectileLayer.removeAllChildren()
        pickupLayer.removeAllChildren()
        effectLayer.removeAllChildren()
        gridSimulation.reset()
        particleSimulation.reset()
        session.registerPlayerHit()
        updateHUD()
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        playerMotion.reset()

        if session.isGameOver {
            player.isHidden = true
            playerShield.isHidden = true
            mouseIsFiring = false
            touchIsFiring = false
            messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
            messageLabel.setScale(1)
            messageLabel.fontColor = .white
            messageLabel.text = "GAME OVER\nPunkte: \(session.score)\nR oder Tippen zum Neustart"
            messageLabel.isHidden = false
            run(.playSoundFileNamed("gameover.wav", waitForCompletion: false))
        } else {
            touchAim = .zero
            touchIsFiring = false
            mouseAutofireArmed = false
            keyboardAutofireArmed = false
            startGetReadySequence()
        }
    }

    private func markKiller(_ killer: SKNode?) {
        guard let killer else { return }
        killer.userData?["killer"] = true

        let snakeHeadID: String?
        if killer.name == "snakeTail" {
            snakeHeadID = killer.userData?["snakeHeadID"] as? String
        } else if killer.userData?["kind"] as? String == EnemyKind.snake.rawValue {
            snakeHeadID = killer.userData?["enemyID"] as? String
        } else {
            snakeHeadID = nil
        }
        guard let snakeHeadID else { return }

        for node in enemyLayer.children {
            let isHead = node.userData?["enemyID"] as? String == snakeHeadID
            let isTail = node.userData?["snakeHeadID"] as? String == snakeHeadID
            if isHead || isTail {
                node.userData?["killer"] = true
            }
        }
    }

    private func removeNonKillerEntities() {
        for node in enemyLayer.children {
            let isKiller = (node.userData?["killer"] as? NSNumber)?.boolValue ?? false
            if !isKiller {
                node.removeFromParent()
            }
        }
        projectileLayer.removeAllChildren()
        pickupLayer.removeAllChildren()
        for node in effectLayer.children where node.name == "playerTrail" {
            node.removeFromParent()
        }
        // RemoveAll(False) clears all four pending wave counters in the original.
        spawnDirector.reset()
    }

    @discardableResult
    private func hitPlayer(killer: SKNode? = nil) -> Bool {
        guard session.shieldFrames == 0,
              deathFramesRemaining == 0,
              getReadyFrame < 0 else { return false }

        markKiller(killer)
        deathFramesRemaining = 100
        player.isHidden = true
        playerShield.isHidden = true
        messageLabel.isHidden = true
        removeNonKillerEntities()
        gridSimulation.pull(at: player.position, radiusInPoints: 32, amount: 64)

        emitParticles(
            count: 256,
            at: player.position,
            kind: .random,
            color: OriginalParticleColor.player
        )
        run(.playSoundFileNamed("die1.wav", waitForCompletion: false))
        return true
    }

    private func emitParticles(
        count: Int,
        at position: CGPoint,
        kind: OriginalParticleKind,
        color: ParticleColor,
        rotation: (Int) -> CGFloat = { _ in 0 },
        positionForIndex: ((Int) -> CGPoint)? = nil
    ) {
        guard count > 0 else { return }
        for index in 0..<count {
            particleSimulation.emit(
                at: positionForIndex?(index) ?? position,
                kind: kind,
                color: color,
                rotationDegrees: rotation(index)
            )
        }
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

    func setMouseBomb(_ pressed: Bool) {
        mouseBombIsHeld = pressed
        if pressed {
            triggerBomb()
        }
    }

    func triggerBomb() {
        if getReadyFrame >= 0 {
            getReadyFrame = getReadyFrame < 60 ? 60 : 99
            return
        }
        guard deathFramesRemaining == 0 else { return }
        guard bombCooldownFrames == 0 else { return }
        guard session.useBomb() else { return }
        bombCooldownFrames = 60
        for angle in 0..<360 {
            particleSimulation.emit(
                at: player.position,
                kind: .radialBomb,
                color: OriginalParticleColor.bomb,
                rotationDegrees: CGFloat(angle)
            )
            particleSimulation.emit(
                at: player.position,
                kind: .bombInternal,
                color: OriginalParticleColor.bomb
            )
        }
        let enemies = enemyLayer.children.filter { $0.name == "enemy" || $0.name == "generator" }
        for enemy in enemies {
            destroyEnemy(enemy, playSound: false, awardPoints: false)
        }
        gridSimulation.pull(at: player.position, radiusInPoints: 60, amount: 60)

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
        return vector
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
