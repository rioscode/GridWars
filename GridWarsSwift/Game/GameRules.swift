import CoreGraphics
import Foundation

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

enum PowerUpKind: Int, CaseIterable, Codable {
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
        let angle = degrees * .pi / 180
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
    }
}

enum OriginalEnemyKind: Int, CaseIterable, Codable {
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

enum SnakeSegmentRule {
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
        if distance > 15 {
            return difference / distance * maximumSpeed
        }
        return difference / distance / 32
    }
}

enum BlackHoleRule {
    static func growthSpeedUp(frame: Int) -> CGFloat {
        min(5, 1 + CGFloat(frame / (50 * 60 * 6)))
    }

    static func destructionScore(absorbedEnemies: Int) -> Int {
        150 + absorbedEnemies * (absorbedEnemies + 1) / 3 * 5
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

struct InterceptorShieldGeometry: Equatable {
    let center: CGPoint
    let right: CGPoint
    let left: CGPoint

    init(center: CGPoint, velocity: CGVector) {
        let speed = velocity.length
        guard speed > 0 else {
            self.center = center
            right = CGPoint(x: center.x + 100, y: center.y - 28)
            left = CGPoint(x: center.x + 28, y: center.y - 100)
            return
        }
        let direction = velocity / speed
        let normal = CGVector(dx: -direction.dy, dy: direction.dx)

        self.center = center
        right = CGPoint(
            x: center.x + direction.dx * 64 + normal.dx * 36,
            y: center.y + direction.dy * 64 + normal.dy * 36
        )
        left = CGPoint(
            x: center.x + direction.dx * 64 - normal.dx * 36,
            y: center.y + direction.dy * 64 - normal.dy * 36
        )
    }

    func contains(_ point: CGPoint, projectileVelocity: CGVector) -> Bool {
        let rear = CGPoint(
            x: center.x - projectileVelocity.dx,
            y: center.y - projectileVelocity.dy
        )
        let first = Self.cross(point, rear, right)
        let second = Self.cross(point, right, left)
        let third = Self.cross(point, left, rear)
        let hasNegative = first < 0 || second < 0 || third < 0
        let hasPositive = first > 0 || second > 0 || third > 0
        return !(hasNegative && hasPositive)
    }

    private static func cross(_ point: CGPoint, _ first: CGPoint, _ second: CGPoint) -> CGFloat {
        (point.x - second.x) * (first.y - second.y)
            - (first.x - second.x) * (point.y - second.y)
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

    mutating func advance<R: RandomNumberGenerator>(
        frame: Int,
        spawningIsBlocked: Bool,
        using random: inout R
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
            if kindValue == 9 { kindValue = 10 }
            if kindValue == 6 { kindValue = randomInt(3...5, using: &random) }
            let generatorKind = OriginalEnemyKind(rawValue: kindValue - 1) ?? .greenSquare
            let size = min(randomInt(1...(16 + frame / 2_000), using: &random), 32)
            let rate = max(60, 80 + randomInt(1...60, using: &random) - frame / 1_000)
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

    func enemyType<R: RandomNumberGenerator>(for frame: Int, using random: inout R) -> OriginalEnemyKind {
        let selection = min(frame / 1_100, 8)
        let upperBound: Int
        switch selection {
        case 0: upperBound = 0
        case 1...7: upperBound = selection
        default: upperBound = 9
        }
        return OriginalEnemyKind(rawValue: randomInt(0...upperBound, using: &random)) ?? .pinwheel
    }

    private mutating func startWave<R: RandomNumberGenerator>(
        index: Int,
        frame: Int,
        divisor: Int,
        base: Int,
        growthBase: Int,
        multiplier: Int,
        cap: Int,
        corner: SpawnCorner,
        using random: inout R
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

    private func randomCorner<R: RandomNumberGenerator>(using random: inout R) -> SpawnCorner {
        SpawnCorner(rawValue: randomInt(0...12, using: &random)) ?? .anywhere
    }

    private func randomInt<R: RandomNumberGenerator>(
        _ range: ClosedRange<Int>,
        using random: inout R
    ) -> Int {
        Int.random(in: range, using: &random)
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
