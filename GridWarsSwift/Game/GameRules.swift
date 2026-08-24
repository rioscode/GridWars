import Foundation

struct GameSession: Equatable {
    private(set) var score = 0
    private(set) var lives = 3
    private(set) var bombs = 3
    private(set) var multiplier = 1
    private(set) var killsSinceDamage = 0
    private(set) var nextExtraLifeScore = 100_000

    var isGameOver: Bool { lives == 0 }

    mutating func registerEnemyDestroyed(baseScore: Int) {
        killsSinceDamage += 1
        multiplier = min(10, 1 + killsSinceDamage / 25)
        score += max(0, baseScore) * multiplier

        while score >= nextExtraLifeScore {
            lives += 1
            nextExtraLifeScore += 100_000
        }
    }

    mutating func registerPlayerHit() {
        guard lives > 0 else { return }
        lives -= 1
        killsSinceDamage = 0
        multiplier = 1
    }

    mutating func useBomb() -> Bool {
        guard bombs > 0, !isGameOver else { return false }
        bombs -= 1
        return true
    }

    mutating func collectPowerUp() {
        bombs = min(9, bombs + 1)
        score += 1_000 * multiplier
    }

    mutating func restart() {
        self = GameSession()
    }
}

enum SpawnPacing {
    static func interval(forElapsedTime elapsedTime: TimeInterval) -> TimeInterval {
        max(0.34, 1.15 - elapsedTime / 180)
    }

    static func maximumEnemies(forElapsedTime elapsedTime: TimeInterval) -> Int {
        min(80, 14 + Int(elapsedTime / 12))
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

    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }
}
