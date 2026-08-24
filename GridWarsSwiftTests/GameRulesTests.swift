import XCTest

final class GameRulesTests: XCTestCase {
    func testDifficultyMatchesOriginalInitialState() {
        let easy = GameSession(difficulty: .easy)
        XCTAssertEqual(easy.lives, 4)
        XCTAssertEqual(easy.bombs, 4)
        XCTAssertEqual(easy.cannons, 2)
        XCTAssertEqual(easy.shotSpeed, 4)
        XCTAssertEqual(easy.enemySpeeds[.greenSquare], 3.1 * 0.75, accuracy: 0.0001)

        let medium = GameSession(difficulty: .medium)
        XCTAssertEqual(medium.lives, 3)
        XCTAssertEqual(medium.bombs, 3)
        XCTAssertEqual(medium.shotSpeed, 3)

        let hard = GameSession(difficulty: .hard)
        XCTAssertEqual(hard.lives, 2)
        XCTAssertEqual(hard.bombs, 2)
        XCTAssertEqual(hard.enemySpeeds[.butterfly], 6.25, accuracy: 0.0001)
        XCTAssertEqual(GameDifficulty.hard.initialFrame, 7_000)
    }

    func testMultiplierUsesOriginalCumulativeThresholds() {
        var session = GameSession()

        for _ in 0..<25 {
            session.registerEnemyDestroyed(baseScore: 100)
        }

        XCTAssertEqual(session.multiplier, 2)
        XCTAssertEqual(session.score, 2_500)

        for _ in 25..<100 {
            session.registerEnemyDestroyed(baseScore: 100)
        }

        XCTAssertEqual(session.multiplier, 3)
        XCTAssertEqual(session.score, 17_500)
    }

    func testPlayerHitCostsLifeAndRemovesOriginalUpgrades() {
        var session = GameSession()
        session.collectPowerUp(.extraCannon)
        session.collectPowerUp(.fasterShots)
        session.collectPowerUp(.reverseShooter)
        session.collectPowerUp(.sideShooters)
        session.collectPowerUp(.superShots)
        session.collectPowerUp(.bouncyShots)
        for _ in 0..<25 {
            session.registerEnemyDestroyed(baseScore: 10)
        }

        session.registerPlayerHit()

        XCTAssertEqual(session.lives, 2)
        XCTAssertEqual(session.multiplier, 1)
        XCTAssertEqual(session.killsSinceDamage, 0)
        XCTAssertEqual(session.cannons, 2)
        XCTAssertEqual(session.shotSpeed, 3)
        XCTAssertEqual(session.reverseShooterFrames, 0)
        XCTAssertEqual(session.sideShooterFrames, 0)
        XCTAssertEqual(session.superShotFrames, 0)
        XCTAssertEqual(session.bouncyShotFrames, 0)
    }

    func testBombMatchesOriginalSupplyShieldAndMultiplierReset() {
        var session = GameSession()
        for _ in 0..<25 {
            session.registerEnemyDestroyed(baseScore: 10)
        }

        XCTAssertTrue(session.useBomb())
        XCTAssertEqual(session.bombs, 2)
        XCTAssertEqual(session.shieldFrames, 65)
        XCTAssertEqual(session.multiplier, 1)
        XCTAssertEqual(session.killsSinceDamage, 0)
    }

    func testPowerUpCapsFallBackToTwoThousandPoints() {
        var session = GameSession()
        session.collectPowerUp(.extraCannon)
        session.collectPowerUp(.extraCannon)
        let scoreBeforeCappedPickup = session.score

        let event = session.collectPowerUp(.extraCannon)

        XCTAssertEqual(session.cannons, 4)
        XCTAssertEqual(session.score, scoreBeforeCappedPickup + 2_000)
        XCTAssertTrue(event.contains(.powerUpCollected(.extraCannon, message: "2000 Points!")))
    }

    func testTimedPowerUpsUseDifficultySpecificOriginalDuration() {
        var easy = GameSession(difficulty: .easy)
        var hard = GameSession(difficulty: .hard)

        easy.collectPowerUp(.shield)
        hard.collectPowerUp(.shield)

        XCTAssertEqual(easy.shieldFrames, 400)
        XCTAssertEqual(hard.shieldFrames, 320)
    }

    func testScoreThresholdsRequestOriginalPowerUps() {
        var session = GameSession(difficulty: .medium)

        let firstEvents = session.registerEnemyDestroyed(baseScore: 5_000)
        XCTAssertTrue(firstEvents.contains(.spawnPowerUp(nil)))

        let thresholdEvents = session.registerEnemyDestroyed(baseScore: 95_000)
        XCTAssertTrue(thresholdEvents.contains(.spawnPowerUp(.extraPlayer)))
    }

    func testEnemySelectionUnlocksInOriginalStages() {
        var random = SeededRandomNumberGenerator(seed: 42)
        let director = SpawnDirector()

        for _ in 0..<20 {
            XCTAssertEqual(director.enemyType(for: 1_099, using: &random), .pinwheel)
        }

        var unlocked = Set<OriginalEnemyKind>()
        for _ in 0..<300 {
            unlocked.insert(director.enemyType(for: 8_800, using: &random))
        }
        XCTAssertEqual(unlocked, Set(OriginalEnemyKind.allCases))
    }

    func testSpawnDirectorMatchesSingleGeneratorAndSpeedFrames() {
        var random = SeededRandomNumberGenerator(seed: 7)
        var director = SpawnDirector()

        let single = director.advance(frame: 33, spawningIsBlocked: false, using: &random)
        XCTAssertEqual(single.commands.count, 1)
        guard case let .enemy(kind, freezeFrames, _) = single.commands[0] else {
            return XCTFail("Expected an enemy command")
        }
        XCTAssertEqual(kind, .pinwheel)
        XCTAssertEqual(freezeFrames, 30)

        let generator = director.advance(frame: 444, spawningIsBlocked: false, using: &random)
        XCTAssertEqual(generator.commands.count, 1)
        guard case let .generator(kind, freezeFrames, _, rate, size) = generator.commands[0] else {
            return XCTFail("Expected a generator command")
        }
        XCTAssertNotEqual(kind, .blackHole)
        XCTAssertNotEqual(kind, .interceptor)
        XCTAssertEqual(freezeFrames, 20)
        XCTAssertTrue((60...140).contains(rate))
        XCTAssertTrue((0...32).contains(size))

        let speedFrame = director.advance(frame: 3_001, spawningIsBlocked: false, using: &random)
        XCTAssertTrue(speedFrame.shouldIncreaseEnemySpeeds)
    }

    func testBombCooldownBlocksCommandsButNotSchedulerState() {
        var random = SeededRandomNumberGenerator(seed: 11)
        var director = SpawnDirector()

        let blocked = director.advance(frame: 33, spawningIsBlocked: true, using: &random)

        XCTAssertTrue(blocked.commands.isEmpty)
    }

    func testTriangleBondUsesOriginalStrengthAndProjectileImpulse() {
        var bond = TriangleBondState()
        let impulse = bond.registerProjectileHit(
            projectileVelocityPerFrame: CGVector(dx: 16, dy: -8)
        )

        XCTAssertEqual(bond.strength, 22.5, accuracy: 0.0001)
        XCTAssertEqual(impulse.dx, 5, accuracy: 0.0001)
        XCTAssertEqual(impulse.dy, -2.5, accuracy: 0.0001)

        for _ in 0..<9 {
            _ = bond.registerProjectileHit(projectileVelocityPerFrame: .zero)
        }
        XCTAssertTrue(bond.isBroken)
    }

    func testSnakeTailUsesOriginalFifteenPixelFollowingRule() {
        let farVelocity = SnakeSegmentRule.velocity(
            from: .zero,
            toward: CGPoint(x: 30, y: 0),
            maximumSpeed: 3.5
        )
        XCTAssertEqual(farVelocity.dx, 3.5, accuracy: 0.0001)
        XCTAssertEqual(farVelocity.dy, 0, accuracy: 0.0001)

        let nearVelocity = SnakeSegmentRule.velocity(
            from: .zero,
            toward: CGPoint(x: 8, y: 0),
            maximumSpeed: 3.5
        )
        XCTAssertEqual(nearVelocity.dx, 1.0 / 32.0, accuracy: 0.0001)
    }

    func testInterceptorShieldMatchesOriginalForwardTriangle() {
        let shield = InterceptorShieldGeometry(
            center: CGPoint(x: 100, y: 100),
            velocity: CGVector(dx: 4, dy: 0)
        )

        XCTAssertTrue(shield.contains(CGPoint(x: 140, y: 100)))
        XCTAssertFalse(shield.contains(CGPoint(x: 70, y: 100)))
        XCTAssertEqual(shield.right.x, 164, accuracy: 0.0001)
        XCTAssertEqual(abs(shield.right.y - 100), 36, accuracy: 0.0001)
    }

    func testTriangleBondCollisionUsesOriginalTwelvePixelRadius() {
        let distance = distanceFromPoint(
            CGPoint(x: 50, y: 11),
            toLineFrom: .zero,
            to: CGPoint(x: 100, y: 0)
        )
        XCTAssertEqual(distance, 11, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(distance, 12)
    }

    func testGeneratorHitScoreDoesNotAdvanceKillMultiplier() {
        var session = GameSession()
        for _ in 0..<25 {
            session.registerScore(baseScore: 1)
        }

        XCTAssertEqual(session.score, 25)
        XCTAssertEqual(session.multiplier, 1)
        XCTAssertEqual(session.killsSinceDamage, 0)
    }
}
