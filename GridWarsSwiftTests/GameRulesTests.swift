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

    func testFinalPlayerDeathDoesNotRunRespawnDowngrades() {
        var session = GameSession(difficulty: .hard)
        session.collectPowerUp(.extraCannon)
        session.collectPowerUp(.fasterShots)

        session.registerPlayerHit()
        session.collectPowerUp(.extraCannon)
        session.collectPowerUp(.fasterShots)
        session.registerPlayerHit()

        XCTAssertTrue(session.isGameOver)
        XCTAssertEqual(session.cannons, 3)
        XCTAssertEqual(session.shotSpeed, 4)
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

    func testPlayerMotionUsesOriginalInertiaSpeedAndNormalization() {
        var motion = PlayerMotionState()
        let center = CGPoint(x: 512, y: 384)

        let first = motion.advance(
            from: center,
            input: CGVector(dx: 1, dy: 0),
            arenaSize: CGSize(width: 1_024, height: 768)
        )
        XCTAssertEqual(first.position.x, 518, accuracy: 0.0001)
        XCTAssertEqual(first.position.y, 384, accuracy: 0.0001)

        let coast = motion.advance(
            from: first.position,
            input: .zero,
            arenaSize: CGSize(width: 1_024, height: 768)
        )
        XCTAssertEqual(coast.movement.dx, 0.5, accuracy: 0.0001)
        XCTAssertEqual(coast.position.x, 521, accuracy: 0.0001)

        let diagonal = motion.advance(
            from: coast.position,
            input: CGVector(dx: 1, dy: 1),
            arenaSize: CGSize(width: 1_024, height: 768)
        )
        XCTAssertEqual(diagonal.movement.length, 1, accuracy: 0.0001)
    }

    func testPlayerMotionUndoesBoundaryStepAndReversesMemory() {
        var motion = PlayerMotionState()
        let result = motion.advance(
            from: CGPoint(x: 17, y: 384),
            input: CGVector(dx: -1, dy: 0),
            arenaSize: CGSize(width: 1_024, height: 768)
        )

        XCTAssertEqual(result.position.x, 17, accuracy: 0.0001)
        XCTAssertEqual(motion.memory.dx, 1, accuracy: 0.0001)
    }

    func testRespawnShieldAndOriginalWarningFrames() {
        var session = GameSession()
        session.grantRespawnShield()
        XCTAssertEqual(session.shieldFrames, 80)

        for _ in 0..<9 {
            XCTAssertFalse(session.tick())
        }
        XCTAssertTrue(session.tick())
        XCTAssertEqual(session.shieldFrames, 70)
    }

    func testWeaponRuleMatchesOriginalCannonCountsTimersAndSpeeds() {
        let aim = CGVector(dx: 1, dy: 0)
        let one = PlayerWeaponRule.launches(
            aim: aim,
            cannons: 1,
            shotSpeed: 3,
            reverseShooter: false,
            sideShooters: false
        )
        XCTAssertEqual(one.count, 1)
        XCTAssertEqual(one[0].speed, 9.6, accuracy: 0.0001)

        let four = PlayerWeaponRule.launches(
            aim: aim,
            cannons: 4,
            shotSpeed: 5,
            reverseShooter: true,
            sideShooters: true
        )
        XCTAssertEqual(four.count, 7)
        XCTAssertEqual(four[0].speed, 15.75, accuracy: 0.0001)
        XCTAssertEqual(four[2].speed, 15.5, accuracy: 0.0001)
        XCTAssertEqual(four[4].direction.dx, -1, accuracy: 0.0001)
        XCTAssertEqual(PlayerWeaponRule.timerFrames(cannons: 1), 4)
        XCTAssertEqual(PlayerWeaponRule.timerFrames(cannons: 2), 5)
        XCTAssertEqual(PlayerWeaponRule.timerFrames(cannons: 4), 6)
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
        XCTAssertTrue((81...140).contains(rate))
        XCTAssertTrue((1...32).contains(size))

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

    func testBlackHoleRulesPreserveOriginalIntegerConversions() {
        XCTAssertEqual(BlackHoleRule.growthSpeedUp(frame: 0), 1)
        XCTAssertEqual(BlackHoleRule.growthSpeedUp(frame: 50 * 60 * 6), 2)
        XCTAssertEqual(BlackHoleRule.growthSpeedUp(frame: 50 * 60 * 30), 5)
        XCTAssertEqual(BlackHoleRule.destructionScore(absorbedEnemies: 5), 200)

        let deflected = BlackHoleRule.deflectProjectile(
            position: .zero,
            velocity: CGVector(dx: 3, dy: 4),
            blackHolePosition: CGPoint(x: 40, y: 40),
            blackHoleSize: 21.9
        )
        XCTAssertEqual(deflected.dx, 3 - 1.0 / 21.0, accuracy: 0.0001)
        XCTAssertEqual(deflected.dy, 4 - 1.0 / 21.0, accuracy: 0.0001)
    }

    func testInterceptorShieldMatchesOriginalForwardTriangle() {
        let shield = InterceptorShieldGeometry(
            center: CGPoint(x: 100, y: 100),
            velocity: CGVector(dx: 4, dy: 0)
        )

        let projectileVelocity = CGVector(dx: 10, dy: 0)
        XCTAssertTrue(shield.contains(
            CGPoint(x: 140, y: 100),
            projectileVelocity: projectileVelocity
        ))
        XCTAssertFalse(shield.contains(
            CGPoint(x: 70, y: 100),
            projectileVelocity: projectileVelocity
        ))
        XCTAssertEqual(shield.right.x, 164, accuracy: 0.0001)
        XCTAssertEqual(abs(shield.right.y - 100), 36, accuracy: 0.0001)
    }

    func testStationaryInterceptorShieldMatchesOriginalFallbackGeometry() {
        let shield = InterceptorShieldGeometry(
            center: CGPoint(x: 40, y: 60),
            velocity: .zero
        )

        XCTAssertEqual(shield.right, CGPoint(x: 140, y: 32))
        XCTAssertEqual(shield.left, CGPoint(x: 68, y: -40))
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

    func testGridSimulationUsesOriginalDimensionsAndReset() {
        var grid = GridSimulation(arenaSize: CGSize(width: 1_024, height: 768))

        XCTAssertEqual(grid.columns, 64)
        XCTAssertEqual(grid.rows, 48)
        XCTAssertEqual(grid[12, 9].origin, CGPoint(x: 192, y: 144))

        grid.push(at: CGPoint(x: 192, y: 144), radiusInPoints: 2, amount: 1)
        XCTAssertNotEqual(grid[13, 9].velocity, .zero)
        grid.reset()
        XCTAssertEqual(grid[13, 9].position, grid[13, 9].origin)
        XCTAssertEqual(grid[13, 9].velocity, .zero)
    }

    func testGridPullPushAndShockwaveMatchOriginalImpulses() {
        let center = CGPoint(x: 160, y: 160)
        var pulled = GridSimulation(arenaSize: CGSize(width: 320, height: 320))
        pulled.pull(at: center, radiusInPoints: 2, amount: 4)
        XCTAssertEqual(pulled[11, 10].velocity.dx, -4, accuracy: 0.0001)

        var pushed = GridSimulation(arenaSize: CGSize(width: 320, height: 320))
        pushed.push(at: center, radiusInPoints: 2, amount: 1)
        XCTAssertEqual(pushed[11, 10].velocity.dx, 16, accuracy: 0.0001)

        var shocked = GridSimulation(arenaSize: CGSize(width: 320, height: 320))
        shocked.shockwave(at: center)
        XCTAssertEqual(shocked[11, 10].velocity.dx, 4, accuracy: 0.0001)
    }

    func testGridUpdateAppliesOriginalPointDamping() {
        var grid = GridSimulation(arenaSize: CGSize(width: 320, height: 320))
        grid.pull(at: CGPoint(x: 160, y: 160), radiusInPoints: 2, amount: 4)

        grid.update()

        XCTAssertNotEqual(grid[11, 10].position, grid[11, 10].origin)
        XCTAssertLessThan(abs(grid[11, 10].velocity.dx), 4)
    }

    func testParticleRingUsesOriginalRadialVelocityLifetimeAndWrap() {
        var random = SeededRandomNumberGenerator(seed: 123)
        var particles = ParticleSimulation(
            arenaSize: CGSize(width: 1_024, height: 768),
            capacity: 2
        )
        let color = ParticleColor(red: 200, green: 100, blue: 50)

        particles.emit(
            at: CGPoint(x: 100, y: 100),
            kind: .radialBomb,
            color: color,
            rotationDegrees: 0,
            using: &random
        )

        XCTAssertEqual(particles.particles[0].velocity.dx, 32, accuracy: 0.0001)
        XCTAssertEqual(particles.particles[0].position.x, 132, accuracy: 0.0001)
        XCTAssertEqual(particles.particles[0].activeFrames, 24)
        XCTAssertEqual(particles.nextSlot, 1)

        particles.emit(at: .zero, kind: .directed, color: color, using: &random)
        particles.emit(at: .zero, kind: .directed, color: color, using: &random)
        XCTAssertEqual(particles.nextSlot, 1)
    }

    func testParticleUpdateUsesOriginalDecayAndLateColorFade() {
        var random = SeededRandomNumberGenerator(seed: 321)
        var particles = ParticleSimulation(
            arenaSize: CGSize(width: 1_024, height: 768),
            capacity: 1
        )
        particles.emit(
            at: CGPoint(x: 100, y: 100),
            kind: .radialBomb,
            color: ParticleColor(red: 200, green: 100, blue: 50),
            rotationDegrees: 0,
            using: &random
        )

        particles.update()
        XCTAssertEqual(particles.particles[0].velocity.dx, 30.4, accuracy: 0.0001)
        XCTAssertEqual(particles.particles[0].activeFrames, 23)

        for _ in 0..<14 { particles.update() }
        XCTAssertLessThan(particles.particles[0].color.red, 200)
        XCTAssertEqual(particles.particles[0].activeFrames, 9)
    }

    func testOriginalParticlePaletteMatchesColorDefinitions() {
        XCTAssertEqual(
            OriginalParticleColor.greenSquare,
            ParticleColor(red: 32, green: 255, blue: 32)
        )
        XCTAssertEqual(
            OriginalParticleColor.player,
            ParticleColor(red: 255, green: 255, blue: 200)
        )
        XCTAssertEqual(
            OriginalParticleColor.powerUp,
            ParticleColor(red: 255, green: 255, blue: 32)
        )
    }

    func testBlackHoleParticleGravityAlternatesHalfOfRing() {
        var random = SeededRandomNumberGenerator(seed: 99)
        var particles = ParticleSimulation(
            arenaSize: CGSize(width: 1_024, height: 768),
            capacity: 2
        )
        for _ in 0..<2 {
            particles.emit(
                at: CGPoint(x: 100, y: 100),
                kind: .radialBomb,
                color: OriginalParticleColor.bomb,
                rotationDegrees: 0,
                using: &random
            )
        }

        particles.applyBlackHole(at: CGPoint(x: 200, y: 100), size: 20, frame: 0)
        XCTAssertEqual(particles.particles[0].activeFrames, 27)
        XCTAssertEqual(particles.particles[1].activeFrames, 24)

        particles.applyBlackHole(at: CGPoint(x: 200, y: 100), size: 20, frame: 1)
        XCTAssertEqual(particles.particles[1].activeFrames, 27)
    }

    func testAttractModeUsesOriginalPageDurationsAndOrder() {
        var flow = OriginalScreenFlow()
        XCTAssertEqual(flow.phase, .attract(.title))

        for _ in 0..<899 { XCTAssertFalse(flow.advance()) }
        XCTAssertTrue(flow.advance())
        XCTAssertEqual(flow.phase, .attract(.scores))

        for _ in 0..<750 { _ = flow.advance() }
        XCTAssertEqual(flow.phase, .attract(.friends))
        for _ in 0..<900 { _ = flow.advance() }
        XCTAssertEqual(flow.phase, .attract(.enemies))
        for _ in 0..<900 { _ = flow.advance() }
        XCTAssertEqual(flow.phase, .attract(.title))
        XCTAssertEqual(flow.persistentTitleFrame, 600)
    }

    func testGameOverRunsOriginal179DisplayFramesBeforeScores() {
        var flow = OriginalScreenFlow()
        flow.startGame()
        flow.showGameOver()

        for _ in 0..<178 { XCTAssertFalse(flow.advance()) }
        XCTAssertTrue(flow.advance())
        XCTAssertEqual(flow.phase, .attract(.scores))
    }

    func testMenuMatchesOriginalHierarchyAndAdjustsSettings() {
        var menu = OriginalMenuModel()
        menu.open(duringGame: true)
        XCTAssertEqual(menu.lines, ["Exit Program", "Settings", "End Game", "Continue"])
        XCTAssertEqual(menu.selection, 3)

        menu.select(1)
        XCTAssertEqual(menu.activate(), .none)
        XCTAssertEqual(menu.page, .settings)
        menu.select(3)
        XCTAssertEqual(menu.activate(), .none)
        XCTAssertEqual(menu.page, .game)
        menu.select(0)
        XCTAssertEqual(menu.adjust(by: 1), .none)
        XCTAssertEqual(menu.settings.difficulty, .hard)
        menu.select(4)
        _ = menu.adjust(by: 1)
        XCTAssertEqual(menu.settings.inertia, 0.05, accuracy: 0.0001)
    }

    func testOriginalHardAwardThresholdsMatchControlDefaults() {
        XCTAssertEqual(GameDifficulty.hard.extraLifeThreshold, 200_000)
        XCTAssertEqual(GameDifficulty.hard.extraBombThreshold, 250_000)
    }

    func testRuntimeVideoControlsUseOriginalBoundsAndBrightnessMath() {
        var settings = OriginalRuntimeSettings()
        settings.starCount = 10_000
        settings.cycleStars()
        XCTAssertEqual(settings.starCount, 0)
        settings.cycleStars(by: -1)
        XCTAssertEqual(settings.starCount, 10_000)

        var menu = OriginalMenuModel()
        menu.open(duringGame: false)
        menu.select(1)
        _ = menu.activate()
        menu.select(1)
        _ = menu.activate()
        menu.select(8)
        _ = menu.adjust(by: -1)
        XCTAssertEqual(menu.settings.gridColorPosition, 0)
        menu.select(9)
        _ = menu.adjust(by: 1)
        XCTAssertEqual(menu.settings.gridBrightness, 103)
        XCTAssertEqual(menu.settings.gridOpacity, 103.0 / 119.0, accuracy: 0.0001)
    }

    func testCheatKeysGrantOriginalFramesAndCapsAndInvalidateScore() {
        var session = GameSession()
        session.invalidateScore()
        session.grantCheatUpgrade(.reverseShooter)
        session.grantCheatUpgrade(.sideShooters)
        session.grantCheatUpgrade(.superShots)
        session.grantCheatUpgrade(.bouncyShots)
        for _ in 0..<5 {
            session.grantCheatCannon()
            session.grantCheatShotSpeed()
        }

        XCTAssertFalse(session.isScoreValid)
        XCTAssertEqual(session.reverseShooterFrames, 450)
        XCTAssertEqual(session.sideShooterFrames, 450)
        XCTAssertEqual(session.superShotFrames, 450)
        XCTAssertEqual(session.bouncyShotFrames, 450)
        XCTAssertEqual(session.cannons, 4)
        XCTAssertEqual(session.shotSpeed, 5)
    }

    func testDebugWeaponPatternMatchesOriginalDeveloperMode() {
        XCTAssertEqual(PlayerWeaponRule.debugTimerFrames(cannons: 1), 4)
        XCTAssertEqual(PlayerWeaponRule.debugTimerFrames(cannons: 2), 8)
        XCTAssertEqual(PlayerWeaponRule.debugTimerFrames(cannons: 3), 10)
        XCTAssertEqual(PlayerWeaponRule.debugTimerFrames(cannons: 4), 8)

        let two = PlayerWeaponRule.debugLaunches(
            aim: CGVector(dx: 0, dy: 1),
            cannons: 2,
            shotSpeed: 3,
            reverseShooter: false,
            sideShooters: false
        )
        XCTAssertEqual(two.count, 2)
        XCTAssertEqual(two[0].speed, 6, accuracy: 0.0001)
        XCTAssertEqual(two[0].offset.length, 150, accuracy: 0.0001)

        let three = PlayerWeaponRule.debugLaunches(
            aim: CGVector(dx: 1, dy: 0),
            cannons: 3,
            shotSpeed: 4,
            reverseShooter: true,
            sideShooters: true
        )
        XCTAssertEqual(three.count, 8)
        XCTAssertEqual(three[2].speed, 8.2, accuracy: 0.0001)
    }

    func testVectorFontParserReadsOriginalDefDataLayout() {
        let source = """
        ignored
        #letterdata
        DefData 0
        DefData 2, 2,0, 2,4, 2,5, 2,6
        """
        let font = OriginalVectorFontData.parse(source)

        XCTAssertEqual(font.glyphs[32], [])
        XCTAssertEqual(font.glyphs[33]?.count, 2)
        XCTAssertEqual(font.glyphs[33]?.first?.start, CGPoint(x: 2, y: 0))
        XCTAssertEqual(font.glyphs[33]?.last?.end, CGPoint(x: 2, y: 6))
    }
}
