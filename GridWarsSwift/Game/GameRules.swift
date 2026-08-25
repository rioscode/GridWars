import CoreGraphics
import Foundation

enum OriginalTimingRule {
    static let framesPerSecond = 50
    static let fixedStep = 1.0 / Double(framesPerSecond)
    static let maximumAccumulatedTime = fixedStep * 5
}

struct OriginalPowerUpStatusMessage: Equatable {
    let text: String
    let remainingFrames: Int

    var red: Int { remainingFrames }
    var green: Int { 165 + remainingFrames / 2 }
    var blue: Int { remainingFrames }
}

enum OriginalDrawRectRule {
    static func sceneRect(
        at scenePoint: CGPoint,
        width: CGFloat,
        height: CGFloat
    ) -> CGRect {
        CGRect(
            x: scenePoint.x,
            y: scenePoint.y - height,
            width: width,
            height: height
        )
    }
}

enum OriginalLineRasterRule {
    static func scenePixelCenter(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + 0.5, y: point.y - 0.5)
    }
}

enum OriginalMoireGridRule {
    static func sourceRow(forSceneRow row: Int, rowCount: Int) -> Int {
        rowCount - 1 - row
    }

    static func sceneTriangle(cellPoints: [CGPoint], scale: CGFloat) -> [CGPoint] {
        precondition(cellPoints.count == 4)
        let bottomRight = cellPoints[1]
        return [
            CGPoint(
                x: bottomRight.x,
                y: bottomRight.y + (cellPoints[2].y - bottomRight.y) * scale
            ),
            bottomRight,
            CGPoint(
                x: bottomRight.x + (cellPoints[0].x - bottomRight.x) * scale,
                y: cellPoints[0].y
            ),
        ]
    }
}

enum OriginalTargetRule {
    static func scenePivot(position: CGPoint, size: CGFloat) -> CGPoint {
        CGPoint(x: position.x - size, y: position.y + size)
    }

    static func sceneEndpoints(
        position: CGPoint,
        frame: Int,
        size: CGFloat
    ) -> [CGPoint] {
        let pivot = scenePivot(position: position, size: size)
        let diameter = size * 2
        return stride(from: 0, to: 360, by: 45).map { angleOffset in
            let angle = CGFloat(frame * 8 + angleOffset) * .pi / 180
            let cosine = cos(angle)
            let sine = sin(angle)
            return CGPoint(
                x: pivot.x + diameter * (cosine - sine),
                y: pivot.y - diameter * (sine + cosine)
            )
        }
    }
}

enum OriginalBlendRule {
    static func spriteKitAdditiveNodeAlpha(sourceAlpha: CGFloat) -> CGFloat {
        min(1, max(0, sourceAlpha)).squareRoot()
    }
}

enum OriginalRGBSplitRule {
    enum DisplacementAxis {
        case horizontal
        case vertical
    }

    static func redPoint(
        _ point: CGPoint,
        origin: CGPoint,
        displacementAxis: DisplacementAxis
    ) -> CGPoint {
        let isDisplaced = switch displacementAxis {
        case .horizontal: abs(point.x - origin.x) > 1
        case .vertical: abs(point.y - origin.y) > 1
        }
        guard isDisplaced else {
            return point
        }
        return CGPoint(x: point.x - 4, y: point.y + 4)
    }
}

enum OriginalGetReadyRule {
    static let ringPullFrame = 60
    static let gridUpdatesPerFrame = 2
}

enum OriginalCameraRule {
    static let edgeThreshold: CGFloat = 500
    static let overscroll: CGFloat = 80

    static func centeredOffset(playfield: CGSize, viewport: CGSize) -> CGPoint {
        CGPoint(
            x: (playfield.width - viewport.width) / 2,
            y: (playfield.height - viewport.height) / 2
        )
    }

    static func advance(
        offset: CGPoint,
        player: CGPoint,
        playfield: CGSize,
        viewport: CGSize,
        scrolling: Bool
    ) -> CGPoint {
        guard scrolling else { return offset }
        return CGPoint(
            x: advanceAxis(
                offset: offset.x,
                player: player.x,
                playfield: playfield.width,
                viewport: viewport.width
            ),
            y: advanceAxis(
                offset: offset.y,
                player: player.y,
                playfield: playfield.height,
                viewport: viewport.height
            )
        )
    }

    private static func advanceAxis(
        offset oldOffset: CGFloat,
        player: CGFloat,
        playfield: CGFloat,
        viewport: CGFloat
    ) -> CGFloat {
        var offset = oldOffset
        let nearEdge = Int(player - offset)
        if nearEdge < Int(edgeThreshold) {
            offset -= CGFloat(2 * (5 - nearEdge / 100))
            offset = max(-overscroll, offset)
        }

        let farEdge = Int(player - offset - viewport)
        if farEdge > -Int(edgeThreshold) {
            offset += CGFloat(2 * (5 - abs(farEdge) / 100))
            offset = min(playfield - viewport + overscroll, offset)
        }
        return offset
    }
}

enum GameDifficulty: Int, CaseIterable, Codable {
    case easy
    case medium
    case hard

    var title: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }

    var initialLives: Int {
        switch self {
        case .easy: 4
        case .medium: 3
        case .hard: 2
        }
    }

    var initialBombs: Int { initialLives }
    var initialCannons: Int { 2 }
    var initialShotSpeed: Int { self == .easy ? 4 : 3 }
    var initialFrame: Int { self == .hard ? 7_000 : 1 }

    var upgradeSeconds: Int {
        switch self {
        case .easy: 20
        case .medium: 18
        case .hard: 16
        }
    }

    var speedScale: CGFloat {
        switch self {
        case .easy: 0.75
        case .medium: 1
        case .hard: 1.25
        }
    }

    var speedIncreasePerMinute: CGFloat {
        0.15 + CGFloat(rawValue) * 0.1
    }

    var extraLifeThreshold: Int {
        switch self {
        case .easy: 75_000
        case .medium: 100_000
        case .hard: 200_000
        }
    }

    var extraBombThreshold: Int {
        switch self {
        case .easy: 100_000
        case .medium: 150_000
        case .hard: 250_000
        }
    }
}

enum PowerUpKind: Int, CaseIterable, Codable, Equatable {
    case reverseShooter
    case sideShooters
    case extraCannon
    case fasterShots
    case extraPlayer
    case extraBomb
    case shield
    case superShots
    case bouncyShots

    var message: String {
        switch self {
        case .reverseShooter: "Reverse Shooter"
        case .sideShooters: "Side Shooters"
        case .extraCannon: "Extra Cannon"
        case .fasterShots: "Faster Shots"
        case .extraPlayer: "Extra Player"
        case .extraBomb: "Extra Bomb"
        case .shield: "Shield"
        case .superShots: "Super Shots"
        case .bouncyShots: "Bouncy Shots"
        }
    }
}

enum ProgressionEvent: Equatable {
    case multiplierIncreased(Int)
    case spawnPowerUp(PowerUpKind?)
    case powerUpCollected(PowerUpKind, message: String)
}

struct EnemySpeeds: Equatable {
    private static let original: [OriginalEnemyKind: CGFloat] = [
        .pinwheel: 2.25,
        .diamond: 3.25,
        .greenSquare: 3.1,
        .cube: 3,
        .seeker: 4.35,
        .blackHole: 2.5,
        .triangle: 2,
        .snake: 3.5,
        .interceptor: 4.45,
        .butterfly: 5,
    ]

    private(set) var values: [OriginalEnemyKind: CGFloat]

    init(difficulty: GameDifficulty) {
        values = Self.original.mapValues { $0 * difficulty.speedScale }
    }

    subscript(kind: OriginalEnemyKind) -> CGFloat {
        values[kind, default: 1]
    }

    mutating func increaseAll(by amount: CGFloat) {
        for key in values.keys {
            values[key, default: 0] += amount
        }
    }
}

struct PlayerMotionState: Equatable {
    static let maximumSpeedPerFrame: CGFloat = 6
    static let defaultInertia: CGFloat = 0.5
    static let boundaryMargin: CGFloat = 16

    private(set) var memory = CGVector.zero

    mutating func advance(
        from position: CGPoint,
        input: CGVector,
        arenaSize: CGSize,
        inertia: CGFloat = Self.defaultInertia,
        movementLimit: OriginalMovementLimit = .unit
    ) -> (position: CGPoint, movement: CGVector) {
        var movement = input + memory * inertia
        switch movementLimit {
        case .unit:
            if movement.length > 1 {
                movement = movement.normalized
            }
        case let .mouse(sensitivity):
            let divisor = 1 + sensitivity * 10
            if movement.length > divisor {
                movement = movement / divisor
            }
        }
        memory = movement

        var next = position
        next.x += movement.dx * Self.maximumSpeedPerFrame
        if next.x < Self.boundaryMargin || next.x > arenaSize.width - Self.boundaryMargin {
            next.x -= movement.dx * Self.maximumSpeedPerFrame
            memory.dx = -memory.dx
        }

        next.y += movement.dy * Self.maximumSpeedPerFrame
        if next.y < Self.boundaryMargin || next.y > arenaSize.height - Self.boundaryMargin {
            next.y -= movement.dy * Self.maximumSpeedPerFrame
            memory.dy = -memory.dy
        }
        return (next, movement)
    }

    mutating func reset() {
        memory = .zero
    }
}

struct PlayerTrailState: Equatable {
    static let activeFrames = 40
    static let movementDelayFrames = 28
    static let sourceScale: CGFloat = 2
    static let sourceAlpha: CGFloat = 0.23

    var position: CGPoint
    var velocity: CGVector
    var color: ParticleColor
    private(set) var framesRemaining: Int

    init(
        playerPosition: CGPoint,
        movement: CGVector,
        frame: Int,
        index: Int,
        color: ParticleColor
    ) {
        let angle = CGFloat(frame * 12 + index * 45) * .pi / 180
        position = CGPoint(
            x: playerPosition.x - movement.dx * 12 + sin(angle) * 8,
            // BlitzMax stores Y downward. Inverting the source
            // `-jdmy*12 + Cos(angle)*8` expression changes the cosine sign.
            y: playerPosition.y - movement.dy * 12 - cos(angle) * 8
        )
        velocity = CGVector(dx: -movement.dx * 1.5, dy: -movement.dy * 1.5)
        self.color = color
        framesRemaining = Self.activeFrames
    }

    init(
        position: CGPoint,
        velocity: CGVector,
        color: ParticleColor,
        framesRemaining: Int
    ) {
        self.position = position
        self.velocity = velocity
        self.color = color
        self.framesRemaining = framesRemaining
    }

    @discardableResult
    mutating func advance() -> Bool {
        framesRemaining -= 1
        if framesRemaining < Self.movementDelayFrames {
            color.red = Int(CGFloat(color.red) * 0.91)
            color.green = Int(CGFloat(color.green) * 0.88)
            color.blue = Int(CGFloat(color.blue) * 0.86)
            position.x += velocity.dx
            position.y += velocity.dy
            velocity = velocity * 0.999
        }
        return framesRemaining > 0
    }
}

enum PlayerVisualRule {
    static func sceneRotation(forMovement movement: CGVector) -> CGFloat {
        guard movement.length > 0 else { return 0 }
        // whiteplayer.png points down. Max2D rotates clockwise in its Y-down
        // coordinate system; SpriteKit needs the algebraically inverted angle.
        return atan2(movement.dy, movement.dx) + .pi / 2
    }

    static func projectileSceneRotation(forDirection direction: CGVector) -> CGFloat {
        // yellowshot.png points up, while shot.DrawAllShots adds 90 degrees in
        // Max2D. After Y inversion that is a -90-degree SpriteKit offset.
        atan2(direction.dy, direction.dx) - .pi / 2
    }

    static func shieldIsVisible(frames: Int) -> Bool {
        frames > 60 || frames % 15 > 7
    }

    static func shieldScale(frames: Int) -> CGFloat {
        2.75 + CGFloat(frames) / 128
    }

    static func shieldPath() -> CGPath {
        let path = CGMutablePath()
        for index in 0..<18 {
            let angle = CGFloat(index * 20) * .pi / 180
            let point = CGPoint(x: cos(angle) * 8, y: -sin(angle) * 8)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct ProjectileLaunch: Equatable {
    let direction: CGVector
    let speed: CGFloat
    let offset: CGVector

    init(direction: CGVector, speed: CGFloat, offset: CGVector = .zero) {
        self.direction = direction
        self.speed = speed
        self.offset = offset
    }
}

struct ProjectileBoundaryResult: Equatable {
    var position: CGPoint
    var velocity: CGVector
    var shouldRemove: Bool
}

enum ProjectileUpdateRule {
    static func resolveBoundary(
        positionAfterHalfStep: CGPoint,
        velocity: CGVector,
        arenaSize: CGSize,
        isBouncy: Bool
    ) -> ProjectileBoundaryResult {
        var position = positionAfterHalfStep
        var velocity = velocity
        var shouldRemove = false

        if position.x < 0 || position.x > arenaSize.width - 1 {
            position.x -= velocity.dx
            if isBouncy {
                velocity.dx = -velocity.dx
            } else {
                shouldRemove = true
            }
        }

        // Source Y is valid from 0 through H-1 and sceneY = H-sourceY,
        // therefore the exact SpriteKit interval is 1 through H.
        if position.y < 1 || position.y > arenaSize.height {
            position.y -= velocity.dy
            if isBouncy {
                velocity.dy = -velocity.dy
            } else {
                shouldRemove = true
            }
        }

        return ProjectileBoundaryResult(
            position: position,
            velocity: velocity,
            shouldRemove: shouldRemove
        )
    }

    static func enforceSourceMinimumSpeed(
        velocity: CGVector,
        originalSpeed: CGFloat
    ) -> CGVector {
        let speed = velocity.length
        guard speed > 0, speed < originalSpeed / 2 else { return velocity }
        var result = velocity
        // The original assigns dx twice with the unchanged pre-adjustment
        // speed and never assigns dy. Preserve that observable typo exactly.
        result.dx = result.dx / speed * (originalSpeed / 2)
        result.dx = result.dx / speed * (originalSpeed / 2)
        return result
    }
}

enum ProjectileUpgradeRule {
    static func collisionRemovesProjectile(collided: Bool, superShotFrames: Int) -> Bool {
        collided && superShotFrames == 0
    }

    static func colorRole(superShotFrames: Int, bouncyShotFrames: Int) -> OriginalColorRole {
        if superShotFrames > 0 { return .superShot }
        if bouncyShotFrames > 0 { return .bouncyShot }
        return .shot
    }
}

enum PlayerWeaponRule {
    static func timerFrames(cannons: Int) -> Int {
        4 + cannons / 2
    }

    static func debugTimerFrames(cannons: Int) -> Int {
        switch cannons {
        case 2, 4: 8
        case 3: 10
        default: 4
        }
    }

    static func launches(
        aim: CGVector,
        cannons: Int,
        shotSpeed: Int,
        reverseShooter: Bool,
        sideShooters: Bool
    ) -> [ProjectileLaunch] {
        let direction = aim.normalized
        guard direction.length > 0 else { return [] }
        var launches: [ProjectileLaunch] = []

        if !cannons.isMultiple(of: 2) {
            launches.append(.init(direction: direction, speed: CGFloat(shotSpeed) * 3.2))
        }
        if cannons > 1 {
            let angle: CGFloat = cannons.isMultiple(of: 2) ? 2 : 4
            launches.append(.init(
                direction: rotate(direction, degrees: angle),
                speed: CGFloat(shotSpeed) * 3.15
            ))
            launches.append(.init(
                direction: rotate(direction, degrees: -angle),
                speed: CGFloat(shotSpeed) * 3.15
            ))
        }
        if cannons > 3 {
            launches.append(.init(
                direction: rotate(direction, degrees: 5),
                speed: CGFloat(shotSpeed) * 3.1
            ))
            launches.append(.init(
                direction: rotate(direction, degrees: -5),
                speed: CGFloat(shotSpeed) * 3.1
            ))
        }
        if reverseShooter {
            launches.append(.init(
                direction: rotate(direction, degrees: 180),
                speed: CGFloat(shotSpeed) * 3
            ))
        }
        if sideShooters {
            launches.append(.init(
                direction: rotate(direction, degrees: 90),
                speed: CGFloat(shotSpeed) * 3
            ))
            launches.append(.init(
                direction: rotate(direction, degrees: -90),
                speed: CGFloat(shotSpeed) * 3
            ))
        }
        return launches
    }

    static func debugLaunches(
        aim: CGVector,
        cannons: Int,
        shotSpeed: Int,
        reverseShooter: Bool,
        sideShooters: Bool
    ) -> [ProjectileLaunch] {
        let direction = aim.normalized
        guard direction.length > 0 else { return [] }
        let speed = CGFloat(shotSpeed)
        var launches: [ProjectileLaunch] = []

        switch cannons {
        case 1:
            launches.append(.init(direction: direction, speed: speed * 2))
        case 2:
            for angle: CGFloat in [12, -12] {
                let rotated = rotate(direction, degrees: angle)
                let launchSpeed = speed * 2
                launches.append(.init(
                    direction: rotated,
                    speed: launchSpeed,
                    offset: rotated * launchSpeed * 25
                ))
            }
        case 3:
            launches.append(.init(direction: rotate(direction, degrees: 3), speed: speed * 2))
            for angle: CGFloat in [2.5, 0, -2.5] {
                launches.append(.init(direction: rotate(direction, degrees: angle), speed: speed * 2.05))
            }
            launches.append(.init(direction: rotate(direction, degrees: -3), speed: speed * 2))
        default:
            launches.append(.init(direction: rotate(direction, degrees: -2), speed: speed * 2))
            launches.append(.init(direction: direction, speed: speed * 2.25))
            launches.append(.init(direction: rotate(direction, degrees: 2), speed: speed * 2))
        }
        if reverseShooter {
            launches.append(.init(direction: rotate(direction, degrees: 180), speed: speed * 2))
        }
        if sideShooters {
            launches.append(.init(direction: rotate(direction, degrees: 90), speed: speed * 2))
            launches.append(.init(direction: rotate(direction, degrees: -90), speed: speed * 2))
        }
        return launches
    }

    private static func rotate(_ vector: CGVector, degrees: CGFloat) -> CGVector {
        // The requested angle comes from BlitzMax's Y-down source space.
        // Negating it preserves the source turn direction in SpriteKit's Y-up scene.
        let angle = -degrees * .pi / 180
        return CGVector(
            dx: vector.dx * cos(angle) - vector.dy * sin(angle),
            dy: vector.dx * sin(angle) + vector.dy * cos(angle)
        )
    }
}

struct GameSession: Equatable {
    static let multiplierThresholds = [25, 100, 200, 400, 800, 1_600, 2_500, 3_500, 5_000, 5_500]
    static let powerUpBaseScore = 2_500

    private(set) var difficulty: GameDifficulty
    private(set) var score = 0
    private(set) var lives: Int
    private(set) var bombs: Int
    private(set) var multiplier = 1
    private(set) var killsSinceDamage = 0
    private(set) var nextExtraLifeScore: Int
    private(set) var nextExtraBombScore: Int
    private(set) var nextPowerUpScore = 5_000
    private(set) var powerUpMessageFrames = 180
    private(set) var announcedPowerUpScore = 5_000
    private(set) var cannons: Int
    private(set) var shotSpeed: Int
    private(set) var reverseShooterFrames = 0
    private(set) var sideShooterFrames = 0
    private(set) var shieldFrames = 0
    private(set) var superShotFrames = 0
    private(set) var bouncyShotFrames = 0
    private(set) var enemySpeeds: EnemySpeeds
    private(set) var isScoreValid = true

    var isGameOver: Bool { lives == 0 }

    var powerUpStatusMessage: OriginalPowerUpStatusMessage? {
        guard powerUpMessageFrames > 0 else { return nil }
        return OriginalPowerUpStatusMessage(
            text: "Power Up at \(announcedPowerUpScore)",
            remainingFrames: powerUpMessageFrames
        )
    }

    init(difficulty: GameDifficulty = .medium) {
        self.difficulty = difficulty
        lives = difficulty.initialLives
        bombs = difficulty.initialBombs
        cannons = difficulty.initialCannons
        shotSpeed = difficulty.initialShotSpeed
        nextExtraLifeScore = difficulty.extraLifeThreshold
        nextExtraBombScore = difficulty.extraBombThreshold
        enemySpeeds = EnemySpeeds(difficulty: difficulty)
    }

    @discardableResult
    mutating func registerEnemyDestroyed(baseScore: Int) -> [ProgressionEvent] {
        registerScore(baseScore: baseScore, countsAsKill: true)
    }

    @discardableResult
    mutating func registerScore(
        baseScore: Int,
        countsAsKill: Bool = false
    ) -> [ProgressionEvent] {
        var events: [ProgressionEvent] = []
        score += max(0, baseScore) * multiplier
        if countsAsKill { killsSinceDamage += 1 }

        if countsAsKill,
           multiplier < 10,
           killsSinceDamage >= Self.multiplierThresholds[multiplier - 1] {
            multiplier += 1
            events.append(.multiplierIncreased(multiplier))
        }

        if score >= nextExtraLifeScore {
            nextExtraLifeScore += difficulty.extraLifeThreshold
            if lives < 10 { events.append(.spawnPowerUp(.extraPlayer)) }
        }

        if score >= nextExtraBombScore {
            nextExtraBombScore += difficulty.extraBombThreshold
            if bombs < 9 { events.append(.spawnPowerUp(.extraBomb)) }
        }

        if score >= nextPowerUpScore {
            events.append(.spawnPowerUp(nil))
            nextPowerUpScore += Self.powerUpBaseScore * multiplier * multiplier
        }
        return events
    }

    mutating func registerPlayerHit() {
        guard lives > 0 else { return }
        lives -= 1
        guard lives > 0 else { return }
        if cannons > 2 { cannons -= 1 }
        if shotSpeed > 3 { shotSpeed -= 1 }
        reverseShooterFrames = 0
        sideShooterFrames = 0
        superShotFrames = 0
        bouncyShotFrames = 0
        resetMultiplier()
    }

    mutating func useBomb() -> Bool {
        guard bombs > 0, !isGameOver else { return false }
        bombs -= 1
        shieldFrames = 65
        resetMultiplier()
        return true
    }

    mutating func grantRespawnShield() {
        shieldFrames = 80
    }

    mutating func finishGetReady() {
        shieldFrames = 80
        resetMultiplier()
    }

    mutating func advancePowerUpStatusMessageFrame() {
        guard powerUpMessageFrames > 0 else { return }
        powerUpMessageFrames -= 1
        if powerUpMessageFrames == 90 {
            announcedPowerUpScore = nextPowerUpScore
        }
    }

    mutating func clearPowerUpStatusMessage() {
        powerUpMessageFrames = 0
    }

    @discardableResult
    mutating func collectPowerUp(_ kind: PowerUpKind = .extraBomb) -> [ProgressionEvent] {
        let timedUpgradeFrames = 20 * difficulty.upgradeSeconds
        var message = kind.message
        var scoreEvents: [ProgressionEvent] = []

        switch kind {
        case .reverseShooter:
            reverseShooterFrames += timedUpgradeFrames
        case .sideShooters:
            sideShooterFrames += timedUpgradeFrames
        case .extraCannon:
            if cannons >= 4 {
                scoreEvents = registerScore(baseScore: 2_000)
                message = "2000 Points!"
            } else {
                cannons += 1
            }
        case .fasterShots:
            if shotSpeed >= 5 {
                scoreEvents = registerScore(baseScore: 2_000)
                message = "2000 Points!"
            } else {
                shotSpeed += 1
            }
        case .extraPlayer:
            if lives > 9 {
                scoreEvents = registerScore(baseScore: 2_000)
                message = "2000 Points!"
            } else {
                lives += 1
            }
        case .extraBomb:
            if bombs > 8 {
                scoreEvents = registerScore(baseScore: 2_000)
                message = "2000 Points!"
            } else {
                bombs += 1
            }
        case .shield:
            shieldFrames = min(timedUpgradeFrames * 2, shieldFrames + timedUpgradeFrames)
        case .superShots:
            superShotFrames += timedUpgradeFrames
        case .bouncyShots:
            bouncyShotFrames += timedUpgradeFrames
        }
        return [.powerUpCollected(kind, message: message)] + scoreEvents
    }

    @discardableResult
    mutating func tick() -> Bool {
        reverseShooterFrames = max(0, reverseShooterFrames - 1)
        sideShooterFrames = max(0, sideShooterFrames - 1)
        shieldFrames = max(0, shieldFrames - 1)
        superShotFrames = max(0, superShotFrames - 1)
        bouncyShotFrames = max(0, bouncyShotFrames - 1)
        return shieldFrames == 100 || shieldFrames == 70 || shieldFrames == 40
    }

    mutating func increaseEnemySpeeds() {
        enemySpeeds.increaseAll(by: difficulty.speedIncreasePerMinute)
    }

    mutating func invalidateScore() {
        isScoreValid = false
    }

    mutating func grantCheatUpgrade(_ kind: PowerUpKind, frames: Int = 15 * 30) {
        switch kind {
        case .reverseShooter: reverseShooterFrames += frames
        case .sideShooters: sideShooterFrames += frames
        case .superShots: superShotFrames += frames
        case .bouncyShots: bouncyShotFrames += frames
        default: break
        }
    }

    mutating func grantCheatCannon() {
        cannons = min(4, cannons + 1)
    }

    mutating func grantCheatShotSpeed() {
        shotSpeed = min(5, shotSpeed + 1)
    }

    mutating func restart(difficulty: GameDifficulty? = nil) {
        self = GameSession(difficulty: difficulty ?? self.difficulty)
    }

    private mutating func resetMultiplier() {
        multiplier = 1
        killsSinceDamage = 0
        nextPowerUpScore = score + Self.powerUpBaseScore * 2
        nextPowerUpScore = (nextPowerUpScore / (Self.powerUpBaseScore * 2)) * (Self.powerUpBaseScore * 2)
        powerUpMessageFrames = 180
        announcedPowerUpScore = nextPowerUpScore
    }
}

enum OriginalEnemyKind: Int, CaseIterable, Codable, Equatable {
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

    var displayName: String {
        switch self {
        case .pinwheel: "Paul the Pinwheel"
        case .diamond: "Dimmy the Diamond"
        case .greenSquare: "Shy the Square"
        case .cube: "Cubie the Cube"
        case .seeker: "Sammy the Seeker"
        case .blackHole: "Dwight the Black Hole"
        case .triangle: "Trish the Triangle"
        case .snake: "Selena the Snake"
        case .interceptor: "Ivan the Interceptor"
        case .butterfly: "Indy the Butterfly"
        }
    }

    var baseScore: Int {
        switch self {
        case .pinwheel: 25
        case .diamond: 50
        case .greenSquare, .cube, .snake, .interceptor: 100
        case .seeker, .butterfly: 10
        case .blackHole, .triangle: 150
        }
    }
}

enum OriginalGeneratorRule {
    static func childUsesCloseSafePosition(kind: OriginalEnemyKind) -> Bool {
        // ge.Birth's trailing `1` is nme6.Create's rr argument; Snake's close
        // parameter remains at its default zero unlike the other nine kinds.
        kind != .snake
    }

    static func birthPeriod(rate: Int, health: Int) -> Int {
        max(1, rate + 42 - health)
    }

    static func isWarningFrame(rotation: Int, rate: Int, health: Int) -> Bool {
        (rotation + 8) % birthPeriod(rate: rate, health: health) < 8
    }

    static func fillAlpha(kind: OriginalEnemyKind, health: Int) -> CGFloat {
        switch kind {
        case .triangle, .butterfly:
            // ge.Draw declares `sc` but never assigns it in these two cases.
            return 0.1
        default:
            return 0.1 + CGFloat(health) / 256
        }
    }
}

struct OriginalEnemySpawnState: Equatable {
    let rotation: Int
    let direction: Int
    let magnitude: CGFloat
    let snakeTurnDirection: Int

    static func make(
        kind: OriginalEnemyKind,
        using random: inout BlitzMaxRandomNumberGenerator
    ) -> OriginalEnemySpawnState {
        switch kind {
        case .pinwheel:
            return stateWithFixedRotation(
                90,
                magnitude: 0.5..<2,
                using: &random
            )
        case .greenSquare:
            return stateWithFixedRotation(
                90,
                magnitude: 2..<4,
                using: &random
            )
        case .interceptor:
            // nme7.Create draws direction and magnitude before its visual rotation.
            let direction = random.rand(0, 359)
            let magnitude = CGFloat(random.rnd(0.5, 2))
            let rotation = random.rand(0, 359)
            return OriginalEnemySpawnState(
                rotation: rotation,
                direction: direction,
                magnitude: magnitude,
                snakeTurnDirection: 0
            )
        case .snake:
            let rotation = random.rand(0, 359)
            let turnDirection = random.rand(0, 1)
            let magnitude = CGFloat(random.rnd(0.5, 2))

            // The recursive nme6.Create builds 24 tail links plus the terminal
            // link. Their random rotations and every-third-link direction flips
            // are gameplay-inert, but they still advance BRL.Random's state.
            _ = random.rand(0, 1) // Head length 24 direction flip.
            for length in stride(from: 23, through: 0, by: -1) {
                _ = random.rand(0, 359)
                if length > 0, length.isMultiple(of: 3) {
                    _ = random.rand(0, 1)
                }
            }
            return OriginalEnemySpawnState(
                rotation: rotation,
                direction: rotation,
                magnitude: magnitude,
                snakeTurnDirection: turnDirection
            )
        case .diamond, .triangle:
            return stateWithRandomRotation(magnitude: 0.25..<1, using: &random)
        case .cube:
            return stateWithRandomRotation(magnitude: 0.25..<2, using: &random)
        case .seeker, .butterfly:
            return stateWithRandomRotation(magnitude: 3..<6, using: &random)
        case .blackHole:
            return stateWithRandomRotation(magnitude: 0.05..<0.5, using: &random)
        }
    }

    private static func stateWithFixedRotation(
        _ rotation: Int,
        magnitude: Range<Double>,
        using random: inout BlitzMaxRandomNumberGenerator
    ) -> OriginalEnemySpawnState {
        OriginalEnemySpawnState(
            rotation: rotation,
            direction: random.rand(0, 359),
            magnitude: CGFloat(random.rnd(magnitude.lowerBound, magnitude.upperBound)),
            snakeTurnDirection: 0
        )
    }

    private static func stateWithRandomRotation(
        magnitude: Range<Double>,
        using random: inout BlitzMaxRandomNumberGenerator
    ) -> OriginalEnemySpawnState {
        OriginalEnemySpawnState(
            rotation: random.rand(0, 359),
            direction: random.rand(0, 359),
            magnitude: CGFloat(random.rnd(magnitude.lowerBound, magnitude.upperBound)),
            snakeTurnDirection: 0
        )
    }
}

enum OriginalDiamondRandomRule {
    static func consumeIntegerJitter(
        using random: inout BlitzMaxRandomNumberGenerator
    ) {
        guard random.rand(0, 1) != 0 else { return }
        // Rand accepts Int arguments. Both Float literals in
        // Rand(-0.2, 0.2) truncate to zero, yet each call consumes RNG state.
        _ = random.rand(0, 0)
        _ = random.rand(0, 0)
    }
}

enum OriginalSourceTransform {
    static func sceneRadians(sourceDegrees: CGFloat) -> CGFloat {
        -sourceDegrees * .pi / 180
    }
}

struct OriginalEnemySeparationRule: Equatable {
    let thresholdSquared: CGFloat
    let force: CGFloat
}

enum OriginalBasicEnemyRule {
    static func boundaryMargin(for kind: OriginalEnemyKind) -> CGFloat {
        kind == .greenSquare ? 12 : 8
    }

    static func homingAcceleration(for kind: OriginalEnemyKind) -> CGFloat {
        switch kind {
        case .pinwheel: 0
        case .diamond: 0.5
        case .greenSquare: 1
        case .cube: 2.5
        case .seeker: 4
        case .butterfly: 2
        case .blackHole, .triangle, .snake, .interceptor: 0
        }
    }

    static func separation(
        for kind: OriginalEnemyKind,
        cubeTier: Int = 0
    ) -> OriginalEnemySeparationRule? {
        switch kind {
        case .pinwheel:
            OriginalEnemySeparationRule(thresholdSquared: 20 * 20 + 20 * 20, force: 1)
        case .diamond:
            OriginalEnemySeparationRule(thresholdSquared: 30 * 30 + 20 * 20, force: 1)
        case .greenSquare:
            OriginalEnemySeparationRule(thresholdSquared: 30 * 30 + 24 * 24, force: 1)
        case .cube:
            OriginalEnemySeparationRule(
                thresholdSquared: CGFloat(30 * 30 + 20 * 20 - cubeTier * 20),
                force: 1
            )
        case .seeker:
            OriginalEnemySeparationRule(thresholdSquared: 24 * 24 + 20 * 20, force: 1)
        case .butterfly:
            OriginalEnemySeparationRule(thresholdSquared: 16 * 16 + 16 * 16, force: 0.125)
        case .blackHole, .triangle, .snake, .interceptor:
            nil
        }
    }

    static func maximumSpeed(
        for kind: OriginalEnemyKind,
        baseSpeed: CGFloat,
        cubeTier: Int = 0,
        seekerMean: Int = 0
    ) -> CGFloat {
        switch kind {
        case .cube:
            baseSpeed - CGFloat(cubeTier) / 4
        case .seeker:
            baseSpeed + CGFloat(seekerMean)
        default:
            baseSpeed
        }
    }

    static func playerCollisionThresholdSquared(
        for kind: OriginalEnemyKind,
        cubeTier: Int = 0
    ) -> CGFloat? {
        switch kind {
        case .pinwheel, .diamond, .greenSquare:
            24 * 24
        case .cube:
            CGFloat((12 - cubeTier) * (12 - cubeTier) + 12 * 12)
        case .seeker, .butterfly:
            12 * 12 + 12 * 12
        case .blackHole, .triangle, .snake, .interceptor:
            nil
        }
    }

    static func cubeSceneOrbit(rotation: Int, tier: Int) -> CGVector {
        let radians = CGFloat(rotation * (6 + tier)) * .pi / 180
        return CGVector(
            dx: sin(radians) * CGFloat(tier),
            dy: -cos(radians) * CGFloat(tier)
        )
    }
}

enum OriginalBoundaryRule {
    static func bounce(
        position: inout CGPoint,
        velocity: inout CGVector,
        arenaSize: CGSize,
        margin: CGFloat
    ) {
        if position.x < margin {
            velocity.dx = abs(velocity.dx)
            position.x += velocity.dx
        } else if position.x > arenaSize.width - margin {
            velocity.dx = -abs(velocity.dx)
            position.x += velocity.dx
        }
        if position.y < margin {
            velocity.dy = abs(velocity.dy)
            position.y += velocity.dy
        } else if position.y > arenaSize.height - margin {
            velocity.dy = -abs(velocity.dy)
            position.y += velocity.dy
        }
    }
}

enum OriginalGreenSquareRule {
    static func velocityAvoidingProjectile(
        squarePosition: CGPoint,
        squareVelocity: CGVector,
        projectilePosition: CGPoint,
        projectileVelocity: CGVector,
        maximumSpeed: CGFloat
    ) -> CGVector {
        let danger = CGVector(
            dx: projectilePosition.x - squarePosition.x + projectileVelocity.dx * 4,
            dy: projectilePosition.y - squarePosition.y + projectileVelocity.dy * 4
        )
        let bulletBack = projectileVelocity * -1
        let dangerDistance = danger.length + 0.001
        let bulletDistance = bulletBack.length + 0.001
        guard dangerDistance < 100 else { return squareVelocity }
        var result = squareVelocity
            - danger / dangerDistance * 30
            + bulletBack / bulletDistance * 30
        if result.length > maximumSpeed {
            result = result.normalized * maximumSpeed
        }
        return result
    }
}

enum OriginalCubeSplitRule {
    static func sceneOffset(
        using random: inout BlitzMaxRandomNumberGenerator
    ) -> CGVector {
        let sourceX = random.rand(-30, -30)
        let sourceY = random.rand(-30, 30)
        return CGVector(dx: CGFloat(sourceX), dy: -CGFloat(sourceY))
    }
}

struct TriangleBondState: Equatable {
    static let initialStrength: CGFloat = 25

    private(set) var strength: CGFloat = initialStrength

    var isBroken: Bool { strength <= 0 }

    mutating func registerProjectileHit(
        projectileVelocityPerFrame: CGVector
    ) -> CGVector {
        strength = max(0, strength - 2.5)
        return projectileVelocityPerFrame * (5.0 / 16.0)
    }

    mutating func registerBlackHoleSpin() {
        strength = max(0, strength - 0.25)
    }
}

enum TriangleRule {
    static let pairDistanceSquared: CGFloat = 32 * 32
    static let partnerFarDistance: CGFloat = 150
    static let partnerNearDistance: CGFloat = 64
    static let partnerAcceleration: CGFloat = 32
    static let playerHomingRange: CGFloat = 300
    static let boundaryMargin: CGFloat = 8
    static let playerCollisionThresholdSquared: CGFloat = 24 * 24
    static let projectileCollisionThresholdSquared: CGFloat = 12 * 12 + 2 * 2
    static let bondPlayerCollisionRadius: CGFloat = 12

    static func sceneBlackHoleSpinImpulse(sourceRotation: CGFloat) -> CGVector {
        let radians = sourceRotation * 2 * .pi / 180
        // le.Spin subtracts (Cos(r*2)*8, Sin(r*2)*8) in source Y-down space.
        return CGVector(dx: -cos(radians) * 8, dy: sin(radians) * 8)
    }

    static func bondBlackHoleCollisionThresholdSquared(size: CGFloat) -> CGFloat {
        12 * 12 + size * size * 4
    }
}

enum SnakeSegmentRule {
    static let tailSegmentCount = 24
    static let followDistance: CGFloat = 15
    static let closeFollowDivisor: CGFloat = 32
    static let boundaryMargin: CGFloat = 8
    static let playerCollisionThresholdSquared: CGFloat = 24 * 24
    static let zeroVelocityDrawRotation = CGFloat.pi / 2

    static func originalFrame(segmentIndex: Int) -> Int {
        tailSegmentCount - 1 - segmentIndex
    }

    static func projectileCollisionThresholdSquared(originalFrame: Int) -> CGFloat {
        CGFloat(9 * 9 + originalFrame)
    }

    static func cascadeStartFrame(awardsPoints: Bool) -> Int {
        awardsPoints ? 30 : 300
    }

    static func velocity(
        from position: CGPoint,
        toward precedingPosition: CGPoint,
        maximumSpeed: CGFloat
    ) -> CGVector {
        let difference = CGVector(
            dx: precedingPosition.x - position.x,
            dy: precedingPosition.y - position.y
        )
        let distance = max(0.001, difference.length)
        if distance > followDistance {
            return difference / distance * maximumSpeed
        }
        return difference / distance / closeFollowDivisor
    }
}

enum SnakeHeadRule {
    static func sceneSteeringAcceleration(
        sourceHeading: CGFloat,
        maximumSpeed: CGFloat
    ) -> CGVector {
        let radians = sourceHeading * .pi / 180
        return CGVector(
            dx: cos(radians) * maximumSpeed,
            dy: -sin(radians) * maximumSpeed
        )
    }

    static func sourceHeadingAfterTurn(
        _ sourceHeading: CGFloat,
        turnDirection: Int
    ) -> CGFloat {
        sourceHeading + (turnDirection == 0 ? 4 : -4)
    }

    static func turnDirectionAfterRoll(_ turnDirection: Int, roll: Int) -> Int {
        roll > 90 ? 1 - turnDirection : turnDirection
    }

    static func bounce(
        position: inout CGPoint,
        velocity: inout CGVector,
        sourceHeading: inout CGFloat,
        arenaSize: CGSize
    ) {
        let margin = SnakeSegmentRule.boundaryMargin
        if position.x < margin {
            velocity.dx = abs(velocity.dx)
            position.x += velocity.dx
            sourceHeading += 90
        } else if position.x > arenaSize.width - margin {
            velocity.dx = -abs(velocity.dx)
            position.x += velocity.dx
            sourceHeading += 90
        }
        if position.y < margin {
            velocity.dy = abs(velocity.dy)
            position.y += velocity.dy
            sourceHeading += 90
        } else if position.y > arenaSize.height - margin {
            velocity.dy = -abs(velocity.dy)
            position.y += velocity.dy
            sourceHeading += 90
        }
    }
}

enum BlackHoleRule {
    static let activationPushRadius = 6
    static let finalPushRadius = 8
    static let shrinkPerHit: CGFloat = 0.75
    static let minimumSize: CGFloat = 4
    static let maximumSize: CGFloat = 64

    static func growthSpeedUp(frame: Int) -> CGFloat {
        min(5, 1 + CGFloat(frame / (50 * 60 * 6)))
    }

    static func destructionScore(absorbedEnemies: Int) -> Int {
        150 + absorbedEnemies * (absorbedEnemies + 1) / 3 * 5
    }

    static func sizeAfterHit(size: CGFloat, awardsPoints: Bool = true) -> CGFloat {
        awardsPoints ? size - shrinkPerHit : 0
    }

    static func shrinkSoundRate(size: CGFloat) -> CGFloat {
        1.1 + (maximumSize - size) / maximumSize
    }

    static func playerCollisionThresholdSquared(size: CGFloat) -> CGFloat {
        pow(12 + size / 2, 2) + 12 * 12
    }

    static func pulledPlayerPosition(
        player: CGPoint,
        blackHole: CGPoint,
        size: CGFloat
    ) -> CGPoint {
        let difference = CGVector(dx: blackHole.x - player.x, dy: blackHole.y - player.y)
        let distance = difference.length
        guard distance > 0, distance < size * 10 else { return player }
        let pull = difference / distance * (size / 30)
        return CGPoint(x: player.x + pull.dx, y: player.y + pull.dy)
    }

    static func explosionChildPosition(
        sceneCenter: CGPoint,
        arenaHeight: CGFloat,
        index: Int,
        angleStep: CGFloat,
        radius: CGFloat
    ) -> CGPoint {
        let angle = CGFloat(index) * angleStep * .pi / 180
        let sourceCenterY = arenaHeight - sceneCenter.y
        let sourceX = Int(sceneCenter.x + cos(angle) * radius)
        let sourceY = Int(sourceCenterY + sin(angle) * radius)
        return CGPoint(x: sourceX, y: Int(arenaHeight) - sourceY)
    }

    static func explosionParticlePosition(
        sceneCenter: CGPoint,
        index: Int
    ) -> CGPoint {
        let angle = CGFloat(index * 10) * .pi / 180
        return CGPoint(
            x: sceneCenter.x + sin(angle) * 20,
            y: sceneCenter.y - cos(angle) * 20
        )
    }

    static func mutuallyDeflectedVelocity(
        velocity: CGVector,
        differenceToOther: CGVector,
        ownSize: CGFloat,
        otherSize: CGFloat,
        maximumSpeed: CGFloat
    ) -> CGVector {
        let distance = differenceToOther.length + 0.001
        guard distance < otherSize * 2 + ownSize * 2 + 64 else { return velocity }
        let magnitude = min(8, max(1, (otherSize - ownSize) / 8))
        var force = differenceToOther / distance * magnitude
        if distance < otherSize + ownSize {
            // Source Y is inverted. Preserve its sequential ddx-then-ddy update.
            force.dx = -force.dx + force.dy * 0.25
            force.dy = -force.dy + force.dx * 0.25
        }
        let result = velocity + force
        return result.length > maximumSpeed
            ? result.normalized * maximumSpeed
            : result
    }

    static func deflectProjectile(
        position: CGPoint,
        velocity: CGVector,
        blackHolePosition: CGPoint,
        blackHoleSize: CGFloat
    ) -> CGVector {
        let difference = CGVector(
            dx: blackHolePosition.x - position.x,
            dy: blackHolePosition.y - position.y
        )
        let distanceSquared = difference.dx * difference.dx + difference.dy * difference.dy
        let range = CGFloat(Int(75 + blackHoleSize * 5))
        guard distanceSquared < range * range, distanceSquared > 32 * 32 else { return velocity }

        let diameter = Int(blackHoleSize / 4)
        let divisor = CGFloat(26 - diameter)
        return CGVector(
            dx: velocity.dx - (difference.dx == 0 ? 0 : copysign(1 / divisor, difference.dx)),
            dy: velocity.dy - (difference.dy == 0 ? 0 : copysign(1 / divisor, difference.dy))
        )
    }
}

struct OriginalFloatingScoreState: Equatable {
    let text: String
    let sourcePosition: CGPoint
    var life: Int = 30

    var drawX: CGFloat { sourcePosition.x - CGFloat(life) }
    var drawY: CGFloat { sourcePosition.y - 16 }
    var scale: CGFloat { 1 + CGFloat(life) / 12 }
    var colorComponent: Int { min(255, 75 + life * 10) }

    mutating func advance() {
        life -= 1
    }
}

enum InterceptorRule {
    static let boundaryMargin: CGFloat = 16
    static let playerCollisionThresholdSquared: CGFloat = 24 * 24
    static let bodyProjectileThresholdSquared: CGFloat = 12 * 12
    static let shieldRangeSquared: CGFloat = 64 * 64

    static func sourceTurnToFace(
        sceneVelocity: CGVector,
        sceneTarget: CGVector
    ) -> Int {
        let targetAngle = atan2(-sceneTarget.dy, sceneTarget.dx) * 180 / .pi
        let velocityAngle = atan2(-sceneVelocity.dy, sceneVelocity.dx) * 180 / .pi
        var result = Int(targetAngle - velocityAngle)
        if result >= 180 {
            result = -(360 - result)
        } else if result <= -180 {
            result += 360
        }
        return abs(result) < 6 ? 0 : result
    }

    static func initialTurnRemaining(_ sourceTurn: Int) -> Int {
        abs(sourceTurn) < 16 ? 16 : sourceTurn
    }

    static func shouldRetarget(roll: Int, maximumSpeed: CGFloat) -> Bool {
        CGFloat(roll) > 95 - maximumSpeed * 8
    }

    static func advanceTurn(
        sourceHeading: inout CGFloat,
        turnRemaining: inout Int
    ) {
        guard turnRemaining != 0 else { return }
        let sign = turnRemaining < 0 ? -1 : 1
        sourceHeading += CGFloat(4 * sign)
        turnRemaining -= sign
    }

    static func sceneFacing(sourceHeading: CGFloat) -> CGVector {
        let radians = sourceHeading * .pi / 180
        return CGVector(dx: cos(radians), dy: -sin(radians))
    }

    static func steeredVelocity(
        _ velocity: CGVector,
        sourceHeading: CGFloat,
        turnRemaining: Int,
        maximumSpeed: CGFloat
    ) -> CGVector {
        let facing = sceneFacing(sourceHeading: sourceHeading)
        if abs(turnRemaining) < 20 {
            return velocity + facing * 2
        }
        return (velocity + facing) * (0.265 + maximumSpeed / 20)
    }

    static func shieldIsActive(turnRemaining: Int) -> Bool {
        abs(turnRemaining) <= 4
    }
}

struct InterceptorShieldGeometry: Equatable {
    let center: CGPoint
    let right: CGPoint
    let left: CGPoint

    init(center: CGPoint, right: CGPoint, left: CGPoint) {
        self.center = center
        self.right = right
        self.left = left
    }

    init(center: CGPoint, velocity: CGVector) {
        let speed = velocity.length
        guard speed > 0 else {
            self.center = center
            right = CGPoint(x: center.x + 100, y: center.y + 28)
            left = CGPoint(x: center.x + 28, y: center.y + 100)
            return
        }
        let direction = velocity / speed
        let normal = CGVector(dx: -direction.dy, dy: direction.dx)

        self.center = center
        right = CGPoint(
            x: center.x + direction.dx * 64 - normal.dx * 36,
            y: center.y + direction.dy * 64 - normal.dy * 36
        )
        left = CGPoint(
            x: center.x + direction.dx * 64 + normal.dx * 36,
            y: center.y + direction.dy * 64 + normal.dy * 36
        )
    }

    func contains(_ point: CGPoint, projectileVelocity: CGVector) -> Bool {
        let rear = CGPoint(
            x: center.x - projectileVelocity.dx,
            y: center.y - projectileVelocity.dy
        )
        return Self.originalPointInTriangle(
            point: Self.sourceOriented(point),
            first: Self.sourceOriented(rear),
            second: Self.sourceOriented(right),
            third: Self.sourceOriented(left)
        )
    }

    private static func sourceOriented(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: -point.y)
    }

    private static func originalPointInTriangle(
        point: CGPoint,
        first: CGPoint,
        second: CGPoint,
        third: CGPoint
    ) -> Bool {
        var result = true
        if ((first.y <= point.y && point.y < second.y)
                || (second.y <= point.y && point.y < first.y)),
           second.y - first.y != 0,
           point.x < (second.x - first.x) * (point.y - first.y)
                / (second.y - first.y) + first.x {
            result.toggle()
        }
        // Preserve the source typo: the second alternative compares y3 with
        // itself, and the denominator guard still checks y2-y1.
        if ((first.y <= point.y && point.y < third.y)
                || (third.y <= point.y && point.y < third.y)),
           second.y - first.y != 0,
           point.x < (third.x - first.x) * (point.y - first.y)
                / (third.y - first.y) + first.x {
            result.toggle()
        }
        return result
    }
}

func distanceFromPoint(_ point: CGPoint, toLineFrom start: CGPoint, to end: CGPoint) -> CGFloat {
    let segment = CGVector(dx: end.x - start.x, dy: end.y - start.y)
    let lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy
    guard lengthSquared > 0 else {
        return CGVector(dx: point.x - start.x, dy: point.y - start.y).length
    }
    let projection = max(0, min(1,
        ((point.x - start.x) * segment.dx + (point.y - start.y) * segment.dy)
            / lengthSquared
    ))
    let closest = CGPoint(
        x: start.x + projection * segment.dx,
        y: start.y + projection * segment.dy
    )
    return CGVector(dx: point.x - closest.x, dy: point.y - closest.y).length
}

enum SpawnCorner: Int, Codable {
    case anywhere
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
    case anyCorner
    case topCorners
    case rightCorners
    case bottomCorners
    case diagonalTopLeftBottomRight
    case leftCorners
    case diagonalTopRightBottomLeft
    case nearPlayer
}

enum SpawnCommand: Equatable {
    case enemy(kind: OriginalEnemyKind, freezeFrames: Int, corner: SpawnCorner)
    case generator(kind: OriginalEnemyKind, freezeFrames: Int, corner: SpawnCorner, rate: Int, size: Int)
}

struct SpawnFrameResult: Equatable {
    var commands: [SpawnCommand] = []
    var shouldIncreaseEnemySpeeds = false
}

struct SpawnDirector {
    private struct Wave {
        var kind: OriginalEnemyKind = .pinwheel
        var corner: SpawnCorner = .anywhere
        var framesRemaining = 0
        var cadence = 2
        var duplicateButterflies = false
    }

    private var waves = [Wave(), Wave(), Wave(cadence: 3), Wave(cadence: 3)]

    mutating func reset() {
        self = SpawnDirector()
    }

    mutating func advance(
        frame: Int,
        spawningIsBlocked: Bool,
        using random: inout BlitzMaxRandomNumberGenerator
    ) -> SpawnFrameResult {
        var result = SpawnFrameResult()

        if (frame / 350).isMultiple(of: 2), frame.isMultiple(of: 33) {
            result.commands.append(.enemy(
                kind: enemyType(for: frame, using: &random),
                freezeFrames: 30,
                corner: randomCorner(using: &random)
            ))
        }

        if frame.isMultiple(of: 444) {
            var kindValue = enemyType(for: frame / 3 + 500, using: &random).rawValue + 1
            let size = min(randomInt(1...(16 + frame / 2_000), using: &random), 32)
            let rate = max(60, 80 + randomInt(1...60, using: &random) - frame / 1_000)
            if kindValue == 9 { kindValue = 10 }
            if kindValue == 6 { kindValue = randomInt(3...5, using: &random) }
            let generatorKind = OriginalEnemyKind(rawValue: kindValue - 1) ?? .greenSquare
            result.commands.append(.generator(
                kind: generatorKind,
                freezeFrames: 20,
                corner: randomCorner(using: &random),
                rate: rate,
                size: size
            ))
        }

        if frame.isMultiple(of: 777) {
            startWave(index: 0, frame: frame, divisor: 3, base: 15, growthBase: 24, multiplier: 2, cap: 100, corner: randomCorner(using: &random), using: &random)
        }
        if frame.isMultiple(of: 1_850) {
            startWave(index: 1, frame: frame, divisor: 2, base: 15, growthBase: 24, multiplier: 2, cap: 175, corner: randomCorner(using: &random), using: &random)
        }
        if frame.isMultiple(of: 2_900) {
            startWave(index: 2, frame: frame, divisor: 2, base: 20, growthBase: 40, multiplier: 3, cap: 300, corner: .anyCorner, using: &random)
        }
        if (frame / 4_000) % 2 == 1, frame.isMultiple(of: 3_333) {
            let cornerValue = randomInt(0...11, using: &random)
            startWave(index: 3, frame: frame, divisor: 2, base: 20, growthBase: 40, multiplier: 3, cap: 300, corner: SpawnCorner(rawValue: cornerValue) ?? .anywhere, using: &random)
        }

        for index in waves.indices where waves[index].framesRemaining > 0 {
            waves[index].framesRemaining -= 1
            let wave = waves[index]
            if wave.framesRemaining.isMultiple(of: wave.cadence) {
                if wave.duplicateButterflies, wave.kind == .butterfly {
                    result.commands.append(.enemy(kind: wave.kind, freezeFrames: index < 2 ? 24 : 20, corner: wave.corner))
                }
                result.commands.append(.enemy(kind: wave.kind, freezeFrames: index < 2 ? 24 : 20, corner: wave.corner))
            }
        }

        if frame % 3_000 == 1 { result.shouldIncreaseEnemySpeeds = true }
        if spawningIsBlocked { result.commands.removeAll() }
        return result
    }

    func enemyType(
        for frame: Int,
        using random: inout BlitzMaxRandomNumberGenerator
    ) -> OriginalEnemyKind {
        let selection = min(frame / 1_100, 8)
        let upperBound: Int
        switch selection {
        case 0: return .pinwheel
        case 1...7: upperBound = selection
        default: upperBound = 9
        }
        return OriginalEnemyKind(rawValue: randomInt(0...upperBound, using: &random)) ?? .pinwheel
    }

    private mutating func startWave(
        index: Int,
        frame: Int,
        divisor: Int,
        base: Int,
        growthBase: Int,
        multiplier: Int,
        cap: Int,
        corner: SpawnCorner,
        using random: inout BlitzMaxRandomNumberGenerator
    ) {
        let kind = enemyType(for: frame / divisor, using: &random)
        var duration = randomInt(base...(growthBase + frame / 750), using: &random) * multiplier
        duration = min(duration, cap)
        if kind == .blackHole { duration = multiplier * 8 }
        waves[index] = Wave(
            kind: kind,
            corner: corner,
            framesRemaining: duration,
            cadence: index < 2 ? 2 : 3,
            duplicateButterflies: index >= 2
        )
    }

    private func randomCorner(
        using random: inout BlitzMaxRandomNumberGenerator
    ) -> SpawnCorner {
        SpawnCorner(rawValue: randomInt(0...12, using: &random)) ?? .anywhere
    }

    private func randomInt(
        _ range: ClosedRange<Int>,
        using random: inout BlitzMaxRandomNumberGenerator
    ) -> Int {
        random.rand(range.lowerBound, range.upperBound)
    }
}

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

struct BlitzMaxRandomNumberGenerator: RandomNumberGenerator {
    private var state: Int64

    init(seed: Int = 0x1234) {
        let masked = Int64(seed) & 0x7FFF_FFFF
        state = masked == 0 || masked == 2_147_483_647 ? 0x1234 : masked
    }

    mutating func next() -> UInt64 {
        let first = UInt64((nextState() >> 9) & 0x003F_FFFF)
        let second = UInt64((nextState() >> 9) & 0x003F_FFFF)
        let third = UInt64((nextState() >> 11) & 0x000F_FFFF)
        return (first << 42) | (second << 20) | third
    }

    mutating func rand(_ minimum: Int, _ maximum: Int = 1) -> Int {
        let range = Int64(maximum) - Int64(minimum)
        if range > 0 {
            return Int(Int64(rndDouble() * Double(1 + range))) + minimum
        }
        return Int(Int64(rndDouble() * Double(1 - range))) + maximum
    }

    mutating func rnd(_ minimum: Double = 1, _ maximum: Double = 0) -> Double {
        if maximum > minimum {
            return rndDouble() * (maximum - minimum) + minimum
        }
        return rndDouble() * (minimum - maximum) + maximum
    }

    mutating func rndDouble() -> Double {
        let high = Double(nextState() & 0x1FFF_FFFC)
        let low = Double(nextState() & 0x1FFF_FFF8)
        return (high + low / 134_217_728) / 536_870_912
    }

    private mutating func nextState() -> Int64 {
        state = 48_271 * (state % 44_488) - 3_399 * (state / 44_488)
        if state < 0 {
            state += 2_147_483_647
        }
        return state
    }
}

struct GameRandomNumberGenerator: RandomNumberGenerator {
    private var seeded: SeededRandomNumberGenerator?
    private var system = SystemRandomNumberGenerator()

    init(seed: UInt64? = nil) {
        if let seed {
            seeded = SeededRandomNumberGenerator(seed: seed)
        } else {
            seeded = nil
        }
    }

    mutating func next() -> UInt64 {
        if var seeded {
            let value = seeded.next()
            self.seeded = seeded
            return value
        }
        return system.next()
    }
}

extension CGVector {
    var length: CGFloat {
        sqrt(dx * dx + dy * dy)
    }

    var normalized: CGVector {
        let magnitude = length
        guard magnitude > 0.001 else { return .zero }
        return CGVector(dx: dx / magnitude, dy: dy / magnitude)
    }

    static func + (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    static func - (lhs: CGVector, rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }

    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }

    static func / (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx / rhs, dy: lhs.dy / rhs)
    }
}
