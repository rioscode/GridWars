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
        case chaser
        case weaver
        case tank

        var textureName: String {
            switch self {
            case .chaser: "redcircle"
            case .weaver: "greensquare"
            case .tank: "bluediamond"
            }
        }

        var size: CGSize {
            switch self {
            case .chaser: CGSize(width: 42, height: 42)
            case .weaver: CGSize(width: 34, height: 34)
            case .tank: CGSize(width: 48, height: 48)
            }
        }

        var speed: CGFloat {
            switch self {
            case .chaser: 92
            case .weaver: 112
            case .tank: 58
            }
        }

        var health: Int {
            switch self {
            case .chaser, .weaver: 1
            case .tank: 3
            }
        }

        var score: Int {
            switch self {
            case .chaser: 100
            case .weaver: 150
            case .tank: 350
            }
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
    private var gameStartedAt: TimeInterval = 0
    private var lastSpawnTime: TimeInterval = 0
    private var lastShotTime: TimeInterval = 0
    private var playerInvulnerableUntil: TimeInterval = 0
    private var destroyedEnemyCount = 0

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
        physicsWorld.contactDelegate = self
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
        player.size = CGSize(width: 42, height: 42)
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
        destroyedEnemyCount = 0
        lastUpdateTime = 0
        gameStartedAt = 0
        lastSpawnTime = 0
        lastShotTime = 0
        playerInvulnerableUntil = 0
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
            gameStartedAt = currentTime
            lastSpawnTime = currentTime
        }

        let deltaTime = min(1.0 / 20.0, currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        guard !session.isGameOver else { return }

        let elapsedTime = currentTime - gameStartedAt
        updateGrid(at: currentTime)
        updatePlayer(deltaTime: deltaTime)
        updateAim()
        fireIfNeeded(at: currentTime)
        spawnIfNeeded(at: currentTime, elapsedTime: elapsedTime)
        updateEnemies(deltaTime: deltaTime, elapsedTime: elapsedTime)
        removeOffscreenProjectiles()
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

    private func fireIfNeeded(at currentTime: TimeInterval) {
        let shouldFire = mouseIsFiring || touchIsFiring || keyboardAim.length > 0
        guard shouldFire, currentTime - lastShotTime >= 0.12 else { return }
        lastShotTime = currentTime

        let projectile = SKSpriteNode(imageNamed: "yellowshot")
        projectile.name = "projectile"
        projectile.size = CGSize(width: 14, height: 14)
        projectile.position = CGPoint(
            x: player.position.x + currentAim.dx * 24,
            y: player.position.y + currentAim.dy * 24
        )
        projectile.zRotation = atan2(currentAim.dy, currentAim.dx)
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: 5)
        projectile.physicsBody?.affectedByGravity = false
        projectile.physicsBody?.linearDamping = 0
        projectile.physicsBody?.categoryBitMask = Category.projectile
        projectile.physicsBody?.collisionBitMask = 0
        projectile.physicsBody?.contactTestBitMask = Category.enemy
        projectile.physicsBody?.velocity = currentAim * 720
        projectileLayer.addChild(projectile)
        run(.playSoundFileNamed("shotborn.wav", waitForCompletion: false))
    }

    private func spawnIfNeeded(at currentTime: TimeInterval, elapsedTime: TimeInterval) {
        guard enemyLayer.children.count < SpawnPacing.maximumEnemies(forElapsedTime: elapsedTime) else {
            return
        }
        guard currentTime - lastSpawnTime >= SpawnPacing.interval(forElapsedTime: elapsedTime) else {
            return
        }
        lastSpawnTime = currentTime

        let kind: EnemyKind
        let roll = Int.random(in: 0..<100)
        if elapsedTime > 35, roll < 18 {
            kind = .tank
        } else if elapsedTime > 12, roll < 48 {
            kind = .weaver
        } else {
            kind = .chaser
        }

        let enemy = SKSpriteNode(imageNamed: kind.textureName)
        enemy.name = "enemy"
        enemy.size = kind.size
        enemy.position = randomEdgePosition(margin: 38)
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: min(kind.size.width, kind.size.height) * 0.38)
        enemy.physicsBody?.affectedByGravity = false
        enemy.physicsBody?.allowsRotation = false
        enemy.physicsBody?.categoryBitMask = Category.enemy
        enemy.physicsBody?.collisionBitMask = 0
        enemy.physicsBody?.contactTestBitMask = Category.player | Category.projectile
        enemy.userData = NSMutableDictionary(dictionary: [
            "kind": kind.rawValue,
            "health": kind.health,
            "speed": kind.speed,
            "score": kind.score,
            "phase": Double.random(in: 0...(Double.pi * 2)),
        ])
        enemy.setScale(0.05)
        enemyLayer.addChild(enemy)
        enemy.run(.scale(to: 1, duration: 0.2))
    }

    private func randomEdgePosition(margin: CGFloat) -> CGPoint {
        switch Int.random(in: 0..<4) {
        case 0:
            CGPoint(x: CGFloat.random(in: margin...(size.width - margin)), y: margin)
        case 1:
            CGPoint(x: size.width - margin, y: CGFloat.random(in: margin...(size.height - margin)))
        case 2:
            CGPoint(x: CGFloat.random(in: margin...(size.width - margin)), y: size.height - margin)
        default:
            CGPoint(x: margin, y: CGFloat.random(in: margin...(size.height - margin)))
        }
    }

    private func updateEnemies(deltaTime: TimeInterval, elapsedTime: TimeInterval) {
        for enemy in enemyLayer.children where enemy.name == "enemy" {
            let towardPlayer = CGVector(
                dx: player.position.x - enemy.position.x,
                dy: player.position.y - enemy.position.y
            ).normalized
            let speed = CGFloat((enemy.userData?["speed"] as? NSNumber)?.doubleValue ?? 80)
            let kind = EnemyKind(rawValue: enemy.userData?["kind"] as? String ?? "") ?? .chaser
            var velocity = towardPlayer * speed

            if kind == .weaver {
                let phase = (enemy.userData?["phase"] as? NSNumber)?.doubleValue ?? 0
                let wave = CGFloat(sin(elapsedTime * 3.4 + phase)) * 68
                velocity = velocity + CGVector(dx: -towardPlayer.dy, dy: towardPlayer.dx) * wave
                enemy.zRotation -= CGFloat(deltaTime) * 3
            } else {
                enemy.zRotation = atan2(towardPlayer.dy, towardPlayer.dx) - .pi / 2
            }

            enemy.position.x += velocity.dx * deltaTime
            enemy.position.y += velocity.dy * deltaTime
        }
    }

    private func removeOffscreenProjectiles() {
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -60, dy: -60)
        for projectile in projectileLayer.children where !bounds.contains(projectile.position) {
            projectile.removeFromParent()
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
            projectile.removeFromParent()
            damageEnemy(enemy)
        } else if categories == Category.player | Category.enemy {
            let enemy = first.physicsBody?.categoryBitMask == Category.enemy ? first : second
            enemy.removeFromParent()
            createExplosion(at: enemy.position, color: .red)
            hitPlayer(at: contact.contactPoint)
        } else if categories == Category.player | Category.powerUp {
            let powerUp = first.physicsBody?.categoryBitMask == Category.powerUp ? first : second
            collect(powerUp)
        }
    }

    private func damageEnemy(_ enemy: SKNode) {
        guard enemy.parent != nil, enemy.name == "enemy" else { return }
        let health = (enemy.userData?["health"] as? NSNumber)?.intValue ?? 1
        if health > 1 {
            enemy.userData?["health"] = health - 1
            enemy.run(.sequence([
                .fadeAlpha(to: 0.25, duration: 0.035),
                .fadeAlpha(to: 1, duration: 0.07),
            ]))
            run(.playSoundFileNamed("genhit1.wav", waitForCompletion: false))
        } else {
            destroyEnemy(enemy)
        }
    }

    private func destroyEnemy(_ enemy: SKNode, playSound: Bool = true) {
        guard enemy.parent != nil, enemy.name == "enemy" else { return }
        enemy.name = "destroying"
        enemy.physicsBody?.categoryBitMask = 0
        let score = (enemy.userData?["score"] as? NSNumber)?.intValue ?? 100
        let position = enemy.position
        enemy.removeFromParent()

        session.registerEnemyDestroyed(baseScore: score)
        destroyedEnemyCount += 1
        createExplosion(at: position, color: .cyan)
        if destroyedEnemyCount.isMultiple(of: 12) {
            spawnPowerUp(at: position)
        }
        if playSound {
            run(.playSoundFileNamed("Explo1.wav", waitForCompletion: false))
        }
        updateHUD()
    }

    private func spawnPowerUp(at position: CGPoint) {
        let powerUp = SKSpriteNode(imageNamed: "whitestar")
        powerUp.name = "powerUp"
        powerUp.size = CGSize(width: 34, height: 34)
        powerUp.position = position
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: 14)
        powerUp.physicsBody?.affectedByGravity = false
        powerUp.physicsBody?.categoryBitMask = Category.powerUp
        powerUp.physicsBody?.collisionBitMask = 0
        powerUp.physicsBody?.contactTestBitMask = Category.player
        pickupLayer.addChild(powerUp)

        powerUp.run(.repeatForever(.rotate(byAngle: .pi, duration: 0.8)))
        powerUp.run(.sequence([
            .wait(forDuration: 8),
            .fadeOut(withDuration: 0.35),
            .removeFromParent(),
        ]))
    }

    private func collect(_ powerUp: SKNode) {
        guard powerUp.parent != nil else { return }
        let position = powerUp.position
        powerUp.removeFromParent()
        session.collectPowerUp()
        createExplosion(at: position, color: .white)
        run(.playSoundFileNamed("bonus1.wav", waitForCompletion: false))
        updateHUD()
    }

    private func hitPlayer(at position: CGPoint) {
        guard lastUpdateTime >= playerInvulnerableUntil else { return }
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
            return
        }

        playerInvulnerableUntil = lastUpdateTime + 2
        player.removeAllActions()
        let blink = SKAction.sequence([
            .fadeAlpha(to: 0.18, duration: 0.08),
            .fadeAlpha(to: 1, duration: 0.08),
        ])
        player.run(.repeat(blink, count: 10))
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
        let enemies = enemyLayer.children.filter { $0.name == "enemy" }
        for enemy in enemies {
            destroyEnemy(enemy, playSound: false)
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
