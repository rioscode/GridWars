import AVFoundation
import XCTest

final class GameRulesTests: XCTestCase {
    func testGameplayTimingUsesOriginalFixedFiftyHertzStep() {
        XCTAssertEqual(OriginalTimingRule.framesPerSecond, 50)
        XCTAssertEqual(OriginalTimingRule.fixedStep, 0.02, accuracy: 0.000_001)
        XCTAssertEqual(OriginalTimingRule.maximumAccumulatedTime, 0.1, accuracy: 0.000_001)
    }

    func testCameraMatchesOriginalThresholdsAndOverscroll() {
        let playfield = CGSize(width: 1_280, height: 960)
        let viewport = CGSize(width: 1_024, height: 768)
        let centered = OriginalCameraRule.centeredOffset(
            playfield: playfield,
            viewport: viewport
        )
        XCTAssertEqual(centered, CGPoint(x: 128, y: 96))

        let stable = OriginalCameraRule.advance(
            offset: centered,
            player: CGPoint(x: 640, y: 480),
            playfield: playfield,
            viewport: viewport,
            scrolling: true
        )
        XCTAssertEqual(stable, centered)

        let nearEdge = OriginalCameraRule.advance(
            offset: centered,
            player: CGPoint(x: 16, y: 480),
            playfield: playfield,
            viewport: viewport,
            scrolling: true
        )
        XCTAssertEqual(nearEdge.x, 116)

        let farEdge = OriginalCameraRule.advance(
            offset: centered,
            player: CGPoint(x: 1_264, y: 480),
            playfield: playfield,
            viewport: viewport,
            scrolling: true
        )
        XCTAssertEqual(farEdge.x, 136)

        let clampedNear = OriginalCameraRule.advance(
            offset: CGPoint(x: -100, y: 96),
            player: CGPoint(x: 0, y: 480),
            playfield: playfield,
            viewport: viewport,
            scrolling: true
        )
        XCTAssertEqual(clampedNear.x, -80)

        let clampedFar = OriginalCameraRule.advance(
            offset: CGPoint(x: 400, y: 96),
            player: CGPoint(x: 1_280, y: 480),
            playfield: playfield,
            viewport: viewport,
            scrolling: true
        )
        XCTAssertEqual(clampedFar.x, 336)

        let disabled = OriginalCameraRule.advance(
            offset: centered,
            player: .zero,
            playfield: playfield,
            viewport: viewport,
            scrolling: false
        )
        XCTAssertEqual(disabled, centered)
    }

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

    func testPerMinuteSpeedIncreaseMutatesTheSharedEnemySpeeds() {
        var session = GameSession(difficulty: .medium)
        let initialSnakeSpeed = session.enemySpeeds[.snake]
        let initialButterflySpeed = session.enemySpeeds[.butterfly]

        session.increaseEnemySpeeds()

        XCTAssertEqual(
            session.enemySpeeds[.snake],
            initialSnakeSpeed + GameDifficulty.medium.speedIncreasePerMinute,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            session.enemySpeeds[.butterfly],
            initialButterflySpeed + GameDifficulty.medium.speedIncreasePerMinute,
            accuracy: 0.0001
        )
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

    func testAllOriginalEnemyScoresAndMultiplierThresholds() {
        XCTAssertEqual(GameSession.multiplierThresholds, [
            25, 100, 200, 400, 800, 1_600, 2_500, 3_500, 5_000, 5_500,
        ])
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: OriginalEnemyKind.allCases.map {
            ($0, $0.baseScore)
        }), [
            .pinwheel: 25,
            .diamond: 50,
            .greenSquare: 100,
            .cube: 100,
            .seeker: 10,
            .blackHole: 150,
            .triangle: 150,
            .snake: 100,
            .interceptor: 100,
            .butterfly: 10,
        ])

        var session = GameSession()
        for _ in 0..<5_000 {
            session.registerEnemyDestroyed(baseScore: 0)
        }
        XCTAssertEqual(session.multiplier, 10)
    }

    func testResetGameMakesTheEffectiveFirstPowerUpThresholdFiveThousand() {
        var session = GameSession()

        XCTAssertFalse(session.registerScore(baseScore: 4_999).contains(.spawnPowerUp(nil)))
        XCTAssertTrue(session.registerScore(baseScore: 1).contains(.spawnPowerUp(nil)))
        XCTAssertEqual(session.nextPowerUpScore, 7_500)
    }

    func testPowerUpStatusMessageMatchesOriginalFadeAndHalfwayRefresh() {
        var session = GameSession()

        XCTAssertEqual(session.powerUpStatusMessage, OriginalPowerUpStatusMessage(
            text: "Power Up at 5000",
            remainingFrames: 180
        ))
        XCTAssertEqual(session.powerUpStatusMessage?.red, 180)
        XCTAssertEqual(session.powerUpStatusMessage?.green, 255)
        XCTAssertEqual(session.powerUpStatusMessage?.blue, 180)

        _ = session.registerScore(baseScore: 5_000)
        for _ in 0..<89 { session.advancePowerUpStatusMessageFrame() }
        XCTAssertEqual(session.powerUpStatusMessage?.text, "Power Up at 5000")
        XCTAssertEqual(session.powerUpStatusMessage?.remainingFrames, 91)

        session.advancePowerUpStatusMessageFrame()
        XCTAssertEqual(session.powerUpStatusMessage?.text, "Power Up at 7500")
        XCTAssertEqual(session.powerUpStatusMessage?.remainingFrames, 90)
        XCTAssertEqual(session.powerUpStatusMessage?.red, 90)
        XCTAssertEqual(session.powerUpStatusMessage?.green, 210)
        XCTAssertEqual(session.powerUpStatusMessage?.blue, 90)

        for _ in 0..<90 { session.advancePowerUpStatusMessageFrame() }
        XCTAssertNil(session.powerUpStatusMessage)
    }

    func testMultiplierResetAndGetReadyRestartThePowerUpMessage() {
        var session = GameSession()
        _ = session.registerScore(baseScore: 6_000)
        for _ in 0..<25 { session.advancePowerUpStatusMessageFrame() }

        XCTAssertTrue(session.useBomb())
        XCTAssertEqual(session.powerUpStatusMessage?.text, "Power Up at 10000")
        XCTAssertEqual(session.powerUpStatusMessage?.remainingFrames, 180)

        session.advancePowerUpStatusMessageFrame()
        session.finishGetReady()
        XCTAssertEqual(session.shieldFrames, 80)
        XCTAssertEqual(session.powerUpStatusMessage?.text, "Power Up at 10000")
        XCTAssertEqual(session.powerUpStatusMessage?.remainingFrames, 180)
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

    func testKeyboardInputUsesEveryConfiguredOriginalKey() {
        var settings = OriginalRuntimeSettings()
        settings.controllerType = .keyboard
        settings.keyMoveLeft = 10
        settings.keyMoveRight = 11
        settings.keyMoveUp = 12
        settings.keyMoveDown = 13
        settings.keyFireLeft = 14
        settings.keyFireRight = 15
        settings.keyFireUp = 16
        settings.keyFireDown = 17
        settings.keyBomb = 18
        let snapshot = OriginalInputSnapshot(pressedKeys: [11, 12, 14, 16, 18])

        var resolver = OriginalInputResolver()
        let result = resolver.resolve(settings: settings, snapshot: snapshot)

        XCTAssertEqual(result.movement, CGVector(dx: 1, dy: 1))
        XCTAssertEqual(result.aim, CGVector(dx: -1, dy: 1))
        XCTAssertTrue(result.isFiring)
        XCTAssertTrue(result.bombIsHeld)
    }

    func testKeyboardAutofireRetainsTheLastDirectionLikeOriginalGlobals() {
        var settings = OriginalRuntimeSettings()
        settings.controllerType = .keyboard
        settings.autoFire = true
        var resolver = OriginalInputResolver()

        let pressed = resolver.resolve(
            settings: settings,
            snapshot: OriginalInputSnapshot(pressedKeys: [settings.keyFireRight])
        )
        let released = resolver.resolve(settings: settings, snapshot: OriginalInputSnapshot())

        XCTAssertEqual(pressed.aim, CGVector(dx: 1, dy: 0))
        XCTAssertEqual(released.aim, pressed.aim)
        XCTAssertTrue(released.isFiring)
    }

    func testMouseInputUsesConfiguredButtonsSensitivityAndRetainedAim() {
        var settings = OriginalRuntimeSettings()
        settings.controllerType = .mouse
        settings.mouseFireButton = 3
        settings.mouseBombButton = 1
        settings.mouseSensitivity = 0.5
        settings.autoFire = true
        var resolver = OriginalInputResolver()

        let moving = resolver.resolve(
            settings: settings,
            snapshot: OriginalInputSnapshot(
                mouseButtons: [1, 3],
                mouseDelta: CGVector(dx: 64, dy: -32)
            )
        )
        let stationary = resolver.resolve(settings: settings, snapshot: OriginalInputSnapshot())

        XCTAssertEqual(moving.movement.dx, 1.75, accuracy: 0.0001)
        XCTAssertEqual(moving.movement.dy, -0.875, accuracy: 0.0001)
        XCTAssertEqual(moving.aim, CGVector(dx: 4, dy: -2))
        XCTAssertTrue(moving.bombIsHeld)
        XCTAssertEqual(moving.movementLimit, .mouse(sensitivity: 0.5))
        XCTAssertEqual(stationary.aim, moving.aim)
        XCTAssertTrue(stationary.isFiring)
    }

    func testMouseMovementKeepsOriginalSensitivityDivisorBehavior() {
        var motion = PlayerMotionState()
        let result = motion.advance(
            from: CGPoint(x: 100, y: 100),
            input: CGVector(dx: 8, dy: 0),
            arenaSize: CGSize(width: 1_024, height: 768),
            inertia: 0,
            movementLimit: .mouse(sensitivity: 0.5)
        )

        XCTAssertEqual(result.movement.dx, 8.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(result.position.x, 108, accuracy: 0.0001)
    }

    func testDualAnalogUsesOriginalAxisFormulaAndPairedDeadZones() {
        var settings = OriginalRuntimeSettings()
        settings.controllerType = .dualAnalog
        settings.joyPorts[0] = OriginalJoyPortSettings(
            axes: [1, 2, 3, 4],
            inversion: [-1, 1, 1, -1],
            scale: [2, 2, 1, 1],
            center: [0.1, -0.1, 0, 0],
            deadZone: [0.6, 0.1, 0.4, 0.3],
            optionButton: 7,
            bombButton: 6
        )
        var snapshot = OriginalInputSnapshot(
            controllerAxes: [0.8, 0.2, 0.3, -0.4] + Array(repeating: 0, count: 11),
            controllerButtons: [6, 7]
        )
        var resolver = OriginalInputResolver()

        let result = resolver.resolve(settings: settings, snapshot: snapshot)
        XCTAssertEqual(result.movement.dx, -0.5, accuracy: 0.0001)
        XCTAssertEqual(result.movement.dy, -0.2, accuracy: 0.0001)
        XCTAssertEqual(result.aim.dx, 0.3, accuracy: 0.0001)
        XCTAssertEqual(result.aim.dy, -0.4, accuracy: 0.0001)
        XCTAssertTrue(result.bombIsHeld)
        XCTAssertTrue(result.optionIsHeld)

        snapshot.controllerAxes[3] = -0.2
        let insideBothAxes = resolver.resolve(settings: settings, snapshot: snapshot)
        XCTAssertEqual(insideBothAxes.aim, .zero)
    }

    func testJoypadSwapsDPadAndFourButtonRoles() {
        var settings = OriginalRuntimeSettings()
        settings.controllerType = .joypad
        settings.joypadButtons = [0, 1, 2, 3]
        settings.joypadBombButton = 4
        settings.joypadOptionButton = 5
        let snapshot = OriginalInputSnapshot(
            controllerDPad: CGVector(dx: -1, dy: -1),
            controllerButtons: [2, 3, 4, 5]
        )
        var resolver = OriginalInputResolver()

        let original = resolver.resolve(settings: settings, snapshot: snapshot)
        XCTAssertEqual(original.movement, CGVector(dx: -1, dy: 1))
        XCTAssertEqual(original.aim, CGVector(dx: 1, dy: 1))
        XCTAssertTrue(original.bombIsHeld)
        XCTAssertTrue(original.optionIsHeld)

        settings.joypadConfiguration = 1
        let swapped = resolver.resolve(settings: settings, snapshot: snapshot)
        XCTAssertEqual(swapped.movement, original.aim)
        XCTAssertEqual(swapped.aim, original.movement)
    }

    func testAllThreeHybridModesFollowOriginalControlPairings() {
        var settings = OriginalRuntimeSettings()
        settings.controllerType = .hybrid
        settings.mouseFireButton = 1
        var resolver = OriginalInputResolver()

        settings.hybridConfiguration = 0
        var snapshot = OriginalInputSnapshot(
            pressedKeys: [settings.keyMoveRight],
            mouseButtons: [1],
            pointerFromPlayer: CGVector(dx: 30, dy: 40)
        )
        let relative = resolver.resolve(settings: settings, snapshot: snapshot)
        XCTAssertEqual(relative.movement, CGVector(dx: 1, dy: 0))
        XCTAssertEqual(relative.aim.dx, 0.6, accuracy: 0.0001)
        XCTAssertEqual(relative.aim.dy, 0.8, accuracy: 0.0001)

        settings.hybridConfiguration = 1
        snapshot = OriginalInputSnapshot(
            pressedKeys: [settings.keyFireUp],
            mouseDelta: CGVector(dx: 64, dy: 0)
        )
        let mouseMove = resolver.resolve(settings: settings, snapshot: snapshot)
        XCTAssertGreaterThan(mouseMove.movement.dx, 0)
        XCTAssertEqual(mouseMove.aim, CGVector(dx: 0, dy: 1))
        XCTAssertEqual(mouseMove.movementLimit, .mouse(sensitivity: settings.mouseSensitivity))

        settings.hybridConfiguration = 2
        snapshot = OriginalInputSnapshot(
            pressedKeys: [settings.keyFireRight],
            mouseButtons: [1],
            pointerFromCenter: CGVector(dx: 0, dy: 100)
        )
        let centered = resolver.resolve(settings: settings, snapshot: snapshot)
        XCTAssertEqual(centered.aim.dx, 0.1, accuracy: 0.0001)
        XCTAssertEqual(centered.aim.dy, 0.8, accuracy: 0.0001)
    }

    func testTouchTwinSticksOverrideLegacyDeviceWithoutChangingVectors() {
        var settings = OriginalRuntimeSettings()
        settings.controllerType = .mouse
        let snapshot = OriginalInputSnapshot(
            mouseButtons: [settings.mouseFireButton],
            mouseDelta: CGVector(dx: 100, dy: 100),
            touchMovement: CGVector(dx: -0.4, dy: 0.2),
            touchAim: CGVector(dx: 0, dy: -1),
            touchIsActive: true
        )
        var resolver = OriginalInputResolver()

        let result = resolver.resolve(settings: settings, snapshot: snapshot)

        XCTAssertEqual(result.movement, snapshot.touchMovement)
        XCTAssertEqual(result.aim, snapshot.touchAim)
        XCTAssertTrue(result.isFiring)
        XCTAssertEqual(result.movementLimit, .unit)
    }

    func testControllerMenusCaptureKeysButtonsAndCalibrationValues() {
        var menu = OriginalMenuModel()
        menu.open(duringGame: false)
        menu.select(1)
        _ = menu.activate()
        menu.select(2)
        _ = menu.activate()
        menu.settings.controllerType = .keyboard
        menu.select(1)
        _ = menu.activate()
        menu.select(0)
        _ = menu.activate()
        XCTAssertTrue(menu.awaitingKeyboardBinding)
        XCTAssertTrue(menu.captureKeyboardKey(65))
        XCTAssertEqual(menu.settings.keyMoveLeft, 65)
        XCTAssertTrue(menu.lines[0].contains("A"))

        _ = menu.back()
        menu.settings.controllerType = .joypad
        menu.select(1)
        _ = menu.activate()
        menu.select(1)
        XCTAssertTrue(menu.captureControllerButton(12))
        XCTAssertEqual(menu.settings.joypadBombButton, 12)

        _ = menu.back()
        menu.settings.controllerType = .dualAnalog
        menu.select(1)
        _ = menu.activate()
        XCTAssertEqual(menu.page, .dualAnalog)
        XCTAssertEqual(menu.lines.count, 24)
        menu.select(5)
        _ = menu.adjust(by: 1)
        XCTAssertTrue(menu.settings.dualAnalogInverted[0])
        menu.select(9)
        _ = menu.adjust(by: 1)
        XCTAssertEqual(menu.settings.dualAnalogScale[0], 128)
        menu.select(13)
        _ = menu.adjust(by: 1)
        XCTAssertEqual(menu.settings.dualAnalogCenter[0], 0.01, accuracy: 0.0001)
        menu.select(17)
        _ = menu.adjust(by: 1)
        XCTAssertEqual(menu.settings.dualAnalogDeadZone[0], 0.01, accuracy: 0.0001)
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

    func testEveryDifficultyUsesItsOriginalExtraAwardThresholds() {
        for difficulty in GameDifficulty.allCases {
            var lifeSession = GameSession(difficulty: difficulty)
            XCTAssertTrue(
                lifeSession.registerScore(baseScore: difficulty.extraLifeThreshold)
                    .contains(.spawnPowerUp(.extraPlayer))
            )

            var bombSession = GameSession(difficulty: difficulty)
            XCTAssertTrue(
                bombSession.registerScore(baseScore: difficulty.extraBombThreshold)
                    .contains(.spawnPowerUp(.extraBomb))
            )
        }
    }

    func testEnemySelectionUnlocksInOriginalStages() {
        var random = BlitzMaxRandomNumberGenerator(seed: 42)
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
        var random = BlitzMaxRandomNumberGenerator(seed: 7)
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
        var random = BlitzMaxRandomNumberGenerator(seed: 11)
        var director = SpawnDirector()

        let blocked = director.advance(frame: 33, spawningIsBlocked: true, using: &random)

        XCTAssertTrue(blocked.commands.isEmpty)
    }

    func testSpawnDirectorPreservesAllFourOriginalWaveCadences() {
        var random = BlitzMaxRandomNumberGenerator(seed: 19)

        var first = SpawnDirector()
        XCTAssertTrue(first.advance(frame: 777, spawningIsBlocked: false, using: &random).commands.isEmpty)
        XCTAssertEqual(
            first.advance(frame: 778, spawningIsBlocked: false, using: &random).commands.count,
            1
        )

        var second = SpawnDirector()
        _ = second.advance(frame: 1_850, spawningIsBlocked: false, using: &random)
        XCTAssertEqual(
            second.advance(frame: 1_851, spawningIsBlocked: false, using: &random).commands.count,
            1
        )

        var third = SpawnDirector()
        _ = third.advance(frame: 2_900, spawningIsBlocked: false, using: &random)
        _ = third.advance(frame: 2_901, spawningIsBlocked: false, using: &random)
        XCTAssertFalse(
            third.advance(frame: 2_902, spawningIsBlocked: false, using: &random).commands.isEmpty
        )

        var fourth = SpawnDirector()
        _ = fourth.advance(frame: 6_666, spawningIsBlocked: false, using: &random)
        _ = fourth.advance(frame: 6_667, spawningIsBlocked: false, using: &random)
        XCTAssertFalse(
            fourth.advance(frame: 6_668, spawningIsBlocked: false, using: &random).commands.isEmpty
        )
    }

    func testGeneratorTimingWarningAndFillAlphaMatchOriginalQuirks() {
        XCTAssertFalse(OriginalGeneratorRule.childUsesCloseSafePosition(kind: .snake))
        for kind in OriginalEnemyKind.allCases where kind != .snake {
            XCTAssertTrue(OriginalGeneratorRule.childUsesCloseSafePosition(kind: kind))
        }
        XCTAssertEqual(OriginalGeneratorRule.birthPeriod(rate: 100, health: 24), 118)
        XCTAssertFalse(OriginalGeneratorRule.isWarningFrame(
            rotation: 109,
            rate: 100,
            health: 24
        ))
        XCTAssertTrue(OriginalGeneratorRule.isWarningFrame(
            rotation: 110,
            rate: 100,
            health: 24
        ))
        XCTAssertTrue(OriginalGeneratorRule.isWarningFrame(
            rotation: 117,
            rate: 100,
            health: 24
        ))
        XCTAssertFalse(OriginalGeneratorRule.isWarningFrame(
            rotation: 118,
            rate: 100,
            health: 24
        ))

        for kind in OriginalEnemyKind.allCases {
            let expected: CGFloat = switch kind {
            case .triangle, .butterfly: 0.1
            default: 0.1 + 24.0 / 256.0
            }
            XCTAssertEqual(
                OriginalGeneratorRule.fillAlpha(kind: kind, health: 24),
                expected,
                accuracy: 0.000_001
            )
        }
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

    func testTriangleRuleKeepsOriginalDistancesAndCollisionThresholds() {
        XCTAssertEqual(TriangleRule.pairDistanceSquared, 1_024)
        XCTAssertEqual(TriangleRule.partnerFarDistance, 150)
        XCTAssertEqual(TriangleRule.partnerNearDistance, 64)
        XCTAssertEqual(TriangleRule.partnerAcceleration, 32)
        XCTAssertEqual(TriangleRule.playerHomingRange, 300)
        XCTAssertEqual(TriangleRule.boundaryMargin, 8)
        XCTAssertEqual(TriangleRule.playerCollisionThresholdSquared, 576)
        XCTAssertEqual(TriangleRule.projectileCollisionThresholdSquared, 148)
        XCTAssertEqual(TriangleRule.bondPlayerCollisionRadius, 12)
        XCTAssertEqual(
            TriangleRule.bondBlackHoleCollisionThresholdSquared(size: 20),
            1_744
        )
    }

    func testTriangleBlackHoleSpinInvertsOnlyTheSourceYComponent() {
        let forward = TriangleRule.sceneBlackHoleSpinImpulse(sourceRotation: 0)
        XCTAssertEqual(forward.dx, -8, accuracy: 0.0001)
        XCTAssertEqual(forward.dy, 0, accuracy: 0.0001)

        let sourceDown = TriangleRule.sceneBlackHoleSpinImpulse(sourceRotation: 45)
        XCTAssertEqual(sourceDown.dx, 0, accuracy: 0.0001)
        XCTAssertEqual(sourceDown.dy, 8, accuracy: 0.0001)
    }

    func testSnakeTailUsesOriginalFifteenPixelFollowingRule() {
        XCTAssertEqual(SnakeSegmentRule.tailSegmentCount, 24)
        XCTAssertEqual(SnakeSegmentRule.originalFrame(segmentIndex: 0), 23)
        XCTAssertEqual(SnakeSegmentRule.originalFrame(segmentIndex: 23), 0)
        XCTAssertEqual(
            SnakeSegmentRule.projectileCollisionThresholdSquared(originalFrame: 24),
            105
        )
        XCTAssertEqual(SnakeSegmentRule.cascadeStartFrame(awardsPoints: true), 30)
        XCTAssertEqual(SnakeSegmentRule.cascadeStartFrame(awardsPoints: false), 300)
        XCTAssertEqual(
            SnakeSegmentRule.zeroVelocityDrawRotation,
            CGFloat.pi / 2,
            accuracy: 0.0001
        )
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

    func testSnakeHeadSteeringAndBoundaryResponsePreserveSourceHandedness() {
        let acceleration = SnakeHeadRule.sceneSteeringAcceleration(
            sourceHeading: 90,
            maximumSpeed: 3.5
        )
        XCTAssertEqual(acceleration.dx, 0, accuracy: 0.0001)
        XCTAssertEqual(acceleration.dy, -3.5, accuracy: 0.0001)
        XCTAssertEqual(SnakeHeadRule.sourceHeadingAfterTurn(90, turnDirection: 0), 94)
        XCTAssertEqual(SnakeHeadRule.sourceHeadingAfterTurn(90, turnDirection: 1), 86)
        XCTAssertEqual(SnakeHeadRule.turnDirectionAfterRoll(0, roll: 90), 0)
        XCTAssertEqual(SnakeHeadRule.turnDirectionAfterRoll(0, roll: 91), 1)

        var position = CGPoint(x: 7, y: 761)
        var velocity = CGVector(dx: -2, dy: 3)
        var sourceHeading: CGFloat = 10
        SnakeHeadRule.bounce(
            position: &position,
            velocity: &velocity,
            sourceHeading: &sourceHeading,
            arenaSize: CGSize(width: 1_024, height: 768)
        )
        XCTAssertEqual(position, CGPoint(x: 9, y: 758))
        XCTAssertEqual(velocity, CGVector(dx: 2, dy: -3))
        XCTAssertEqual(sourceHeading, 190)
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

    func testBlackHoleLifecycleRulesPreserveSourceGeometryAndThresholds() {
        XCTAssertEqual(BlackHoleRule.sizeAfterHit(size: 4.5), 3.75)
        XCTAssertEqual(BlackHoleRule.sizeAfterHit(size: 40, awardsPoints: false), 0)
        XCTAssertEqual(BlackHoleRule.shrinkSoundRate(size: 32), 1.6, accuracy: 0.000_001)
        XCTAssertEqual(
            BlackHoleRule.playerCollisionThresholdSquared(size: 20),
            628
        )

        XCTAssertEqual(
            BlackHoleRule.pulledPlayerPosition(
                player: CGPoint(x: 100, y: 100),
                blackHole: CGPoint(x: 130, y: 100),
                size: 30
            ),
            CGPoint(x: 101, y: 100)
        )
        XCTAssertEqual(
            BlackHoleRule.pulledPlayerPosition(
                player: CGPoint(x: 100, y: 100),
                blackHole: CGPoint(x: 500, y: 100),
                size: 30
            ),
            CGPoint(x: 100, y: 100)
        )

        let center = CGPoint(x: 512.25, y: 384.5)
        XCTAssertEqual(
            BlackHoleRule.explosionChildPosition(
                sceneCenter: center,
                arenaHeight: 768,
                index: 0,
                angleStep: 22.5,
                radius: 20
            ),
            CGPoint(x: 532, y: 385)
        )
        XCTAssertEqual(
            BlackHoleRule.explosionChildPosition(
                sceneCenter: center,
                arenaHeight: 768,
                index: 4,
                angleStep: 22.5,
                radius: 20
            ),
            CGPoint(x: 512, y: 365)
        )
        XCTAssertEqual(
            BlackHoleRule.explosionParticlePosition(sceneCenter: center, index: 0),
            CGPoint(x: center.x, y: center.y - 20)
        )

        let mutual = BlackHoleRule.mutuallyDeflectedVelocity(
            velocity: .zero,
            differenceToOther: CGVector(dx: 10, dy: 5),
            ownSize: 36,
            otherSize: 28,
            maximumSpeed: 2.5
        )
        let distance = sqrt(CGFloat(125)) + 0.001
        let initialX = 10 / distance
        let initialY = 5 / distance
        let expectedX = -initialX + initialY * 0.25
        let expectedY = -initialY + expectedX * 0.25
        XCTAssertEqual(mutual.dx, expectedX, accuracy: 0.000_001)
        XCTAssertEqual(mutual.dy, expectedY, accuracy: 0.000_001)
    }

    func testFloatingScoreStateMatchesOriginalVectorAnimation() {
        var score = OriginalFloatingScoreState(
            text: "200",
            sourcePosition: CGPoint(x: 512, y: 384)
        )
        XCTAssertEqual(score.life, 30)
        XCTAssertEqual(score.drawX, 482)
        XCTAssertEqual(score.drawY, 368)
        XCTAssertEqual(score.scale, 3.5)
        XCTAssertEqual(score.colorComponent, 255)

        score.advance()
        XCTAssertEqual(score.life, 29)
        XCTAssertEqual(score.drawX, 483)
        XCTAssertEqual(score.colorComponent, 255)
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
        // PointInTri omits the forward edge, so the original treats points
        // beyond it as shielded too.
        XCTAssertTrue(shield.contains(
            CGPoint(x: 200, y: 100),
            projectileVelocity: projectileVelocity
        ))
        XCTAssertEqual(shield.right.x, 164, accuracy: 0.0001)
        XCTAssertEqual(shield.right.y, 64, accuracy: 0.0001)
        XCTAssertEqual(shield.left, CGPoint(x: 164, y: 136))
    }

    func testStationaryInterceptorShieldMatchesOriginalFallbackGeometry() {
        let shield = InterceptorShieldGeometry(
            center: CGPoint(x: 40, y: 60),
            velocity: .zero
        )

        XCTAssertEqual(shield.right, CGPoint(x: 140, y: 88))
        XCTAssertEqual(shield.left, CGPoint(x: 68, y: 160))
    }

    func testInterceptorSteeringUsesSourceAnglesAndThresholds() {
        XCTAssertEqual(InterceptorRule.sourceTurnToFace(
            sceneVelocity: CGVector(dx: 1, dy: 0),
            sceneTarget: CGVector(dx: 0, dy: 1)
        ), -90)
        XCTAssertEqual(InterceptorRule.sourceTurnToFace(
            sceneVelocity: CGVector(dx: 1, dy: 0),
            sceneTarget: CGVector(dx: 0, dy: -1)
        ), 90)
        XCTAssertEqual(InterceptorRule.initialTurnRemaining(-5), 16)
        XCTAssertTrue(InterceptorRule.shouldRetarget(roll: 60, maximumSpeed: 4.45))
        XCTAssertFalse(InterceptorRule.shouldRetarget(roll: 59, maximumSpeed: 4.45))
        XCTAssertTrue(InterceptorRule.shieldIsActive(turnRemaining: -4))
        XCTAssertFalse(InterceptorRule.shieldIsActive(turnRemaining: 5))

        var heading: CGFloat = 90
        var turnRemaining = -2
        InterceptorRule.advanceTurn(
            sourceHeading: &heading,
            turnRemaining: &turnRemaining
        )
        XCTAssertEqual(heading, 86)
        XCTAssertEqual(turnRemaining, -1)

        let thrust = InterceptorRule.steeredVelocity(
            .zero,
            sourceHeading: 90,
            turnRemaining: 0,
            maximumSpeed: 4.45
        )
        XCTAssertEqual(thrust.dx, 0, accuracy: 0.0001)
        XCTAssertEqual(thrust.dy, -2, accuracy: 0.0001)
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

    func testVideoPreviewUsesOriginalSmallGridWindow() {
        let grid = GridSimulation(arenaSize: CGSize(width: 1_024, height: 768))
        let preview = grid.renderWindow(
            canvasSize: CGSize(width: 1_024, height: 768),
            columns: 48,
            rows: 36,
            offset: CGPoint(x: 128, y: 112)
        )

        XCTAssertEqual(preview.columns, 48)
        XCTAssertEqual(preview.rows, 36)
        XCTAssertEqual(preview[0, 0].position, CGPoint(x: 128, y: 112))
        XCTAssertEqual(preview[47, 35].position, CGPoint(x: 880, y: 672))
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

    func testGridUpdatePreservesBlitzMaxTopToBottomInPlaceOrder() {
        var grid = GridSimulation(arenaSize: CGSize(width: 320, height: 320))
        grid.pull(at: CGPoint(x: 160, y: 160), radiusInPoints: 4, amount: 4)

        for _ in 0..<10 {
            grid.update()
        }

        XCTAssertEqual(grid[10, 8].position.y, 124.103_107_882_786_83, accuracy: 0.0001)
        XCTAssertEqual(grid[10, 12].position.y, 194.997_892_117_213_18, accuracy: 0.0001)
    }

    func testBlitzMaxRandomGeneratorMatchesArchivedBRLAlgorithm() {
        var integers = BlitzMaxRandomNumberGenerator(seed: 1)
        XCTAssertEqual(
            (0..<10).map { _ in integers.rand(0, 100) },
            [0, 40, 88, 6, 5, 36, 33, 37, 51, 91]
        )

        var doubles = BlitzMaxRandomNumberGenerator(seed: 1)
        XCTAssertEqual(doubles.rndDouble(), 0.000_089_908_690_227_513_69, accuracy: 1e-15)
        XCTAssertEqual(doubles.rndDouble(), 0.405_410_420_644_619_3, accuracy: 1e-15)

        var words = BlitzMaxRandomNumberGenerator(seed: 1)
        XCTAssertEqual(words.next(), 413_790_348_353_315)
        XCTAssertEqual(words.next(), 16_447_326_018_131_396_856)
    }

    func testGeneratorCaptureConsumesSafeXYDirectionBeforeRotation() {
        var random = BlitzMaxRandomNumberGenerator(seed: 1)
        for _ in 0...OriginalRuntimeSettings.maximumStars {
            _ = random.rand(-100, 1_124)
            _ = random.rand(-100, 868)
        }

        XCTAssertEqual(random.rand(0, 360 * 8), 2_504)
        XCTAssertEqual(random.rand(0, 359), 34)
    }

    func testEnemySpawnStateConsumesEachOriginalKindsExactRandomCalls() {
        var pinwheelRandom = BlitzMaxRandomNumberGenerator(seed: 1)
        let pinwheel = OriginalEnemySpawnState.make(
            kind: .pinwheel,
            using: &pinwheelRandom
        )
        XCTAssertEqual(pinwheel.rotation, 90)
        XCTAssertEqual(pinwheel.direction, 0)
        XCTAssertEqual(pinwheel.magnitude, 1.108_115_630_966_928_9, accuracy: 1e-12)
        XCTAssertEqual(pinwheelRandom.rand(0, 100), 88)

        var diamondRandom = BlitzMaxRandomNumberGenerator(seed: 1)
        let diamond = OriginalEnemySpawnState.make(
            kind: .diamond,
            using: &diamondRandom
        )
        XCTAssertEqual(diamond.rotation, 0)
        XCTAssertEqual(diamond.direction, 145)
        XCTAssertEqual(diamond.magnitude, 0.903_867_107_399_324_4, accuracy: 1e-12)
        XCTAssertEqual(diamondRandom.rand(0, 100), 6)

        var interceptorRandom = BlitzMaxRandomNumberGenerator(seed: 1)
        let interceptor = OriginalEnemySpawnState.make(
            kind: .interceptor,
            using: &interceptorRandom
        )
        XCTAssertEqual(interceptor.rotation, 313)
        XCTAssertEqual(interceptor.direction, 0)
        XCTAssertEqual(interceptor.magnitude, 1.108_115_630_966_928_9, accuracy: 1e-12)
        XCTAssertEqual(interceptorRandom.rand(0, 100), 6)

        var snakeRandom = BlitzMaxRandomNumberGenerator(seed: 1)
        let snake = OriginalEnemySpawnState.make(kind: .snake, using: &snakeRandom)
        XCTAssertEqual(snake.rotation, 0)
        XCTAssertEqual(snake.direction, 0)
        XCTAssertEqual(snake.snakeTurnDirection, 0)
        XCTAssertEqual(snake.magnitude, 1.807_734_214_798_648_8, accuracy: 1e-12)
        XCTAssertEqual(snakeRandom.rand(0, 100), 1)
    }

    func testDiamondConsumesDegenerateRandCallsWithoutChangingVelocity() {
        var branchNotTaken = BlitzMaxRandomNumberGenerator(seed: 1)
        OriginalDiamondRandomRule.consumeIntegerJitter(using: &branchNotTaken)
        XCTAssertEqual(branchNotTaken.rand(0, 100), 40)

        var branchTaken = BlitzMaxRandomNumberGenerator(seed: 6_000)
        OriginalDiamondRandomRule.consumeIntegerJitter(using: &branchTaken)
        XCTAssertEqual(branchTaken.rand(0, 100), 42)
    }

    func testBasicEnemyMotionConstantsMatchEachSourceType() {
        XCTAssertEqual(OriginalBasicEnemyRule.homingAcceleration(for: .pinwheel), 0)
        XCTAssertEqual(OriginalBasicEnemyRule.homingAcceleration(for: .diamond), 0.5)
        XCTAssertEqual(OriginalBasicEnemyRule.homingAcceleration(for: .greenSquare), 1)
        XCTAssertEqual(OriginalBasicEnemyRule.homingAcceleration(for: .cube), 2.5)
        XCTAssertEqual(OriginalBasicEnemyRule.homingAcceleration(for: .seeker), 4)
        XCTAssertEqual(OriginalBasicEnemyRule.homingAcceleration(for: .butterfly), 2)

        XCTAssertEqual(
            OriginalBasicEnemyRule.separation(for: .pinwheel),
            OriginalEnemySeparationRule(thresholdSquared: 800, force: 1)
        )
        XCTAssertEqual(
            OriginalBasicEnemyRule.separation(for: .diamond),
            OriginalEnemySeparationRule(thresholdSquared: 1_300, force: 1)
        )
        XCTAssertEqual(
            OriginalBasicEnemyRule.separation(for: .greenSquare),
            OriginalEnemySeparationRule(thresholdSquared: 1_476, force: 1)
        )
        XCTAssertEqual(
            OriginalBasicEnemyRule.separation(for: .cube, cubeTier: 4),
            OriginalEnemySeparationRule(thresholdSquared: 1_220, force: 1)
        )
        XCTAssertEqual(
            OriginalBasicEnemyRule.separation(for: .seeker),
            OriginalEnemySeparationRule(thresholdSquared: 976, force: 1)
        )
        XCTAssertEqual(
            OriginalBasicEnemyRule.separation(for: .butterfly),
            OriginalEnemySeparationRule(thresholdSquared: 512, force: 0.125)
        )

        XCTAssertEqual(OriginalBasicEnemyRule.maximumSpeed(
            for: .cube,
            baseSpeed: 3,
            cubeTier: 4
        ), 2)
        XCTAssertEqual(OriginalBasicEnemyRule.maximumSpeed(
            for: .seeker,
            baseSpeed: 4.35,
            seekerMean: 1
        ), 5.35)
        XCTAssertEqual(
            OriginalBasicEnemyRule.playerCollisionThresholdSquared(for: .cube, cubeTier: 4),
            208
        )
        XCTAssertEqual(
            OriginalBasicEnemyRule.playerCollisionThresholdSquared(for: .butterfly),
            288
        )
    }

    func testCubeOrbitAndSplitOffsetsApplySourceYInversion() {
        XCTAssertEqual(
            OriginalBasicEnemyRule.cubeSceneOrbit(rotation: 0, tier: 4),
            CGVector(dx: 0, dy: -4)
        )
        XCTAssertEqual(
            OriginalBasicEnemyRule.cubeSceneOrbit(rotation: 9, tier: 4).dx,
            4,
            accuracy: 0.000_001
        )

        var random = BlitzMaxRandomNumberGenerator(seed: 1)
        XCTAssertEqual(
            OriginalCubeSplitRule.sceneOffset(using: &random),
            CGVector(dx: -30, dy: 6)
        )
        XCTAssertEqual(random.rand(0, 100), 88)
    }

    func testSourceRotationChangesHandednessAfterSceneYInversion() {
        XCTAssertEqual(
            OriginalSourceTransform.sceneRadians(sourceDegrees: 90),
            -.pi / 2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            OriginalSourceTransform.sceneRadians(sourceDegrees: 242),
            -242 * .pi / 180,
            accuracy: 0.000_001
        )
    }

    func testBoundaryBounceMatchesOriginalDoublePositionAdjustment() {
        var position = CGPoint(x: 5, y: 95)
        var velocity = CGVector(dx: -3, dy: 4)

        OriginalBoundaryRule.bounce(
            position: &position,
            velocity: &velocity,
            arenaSize: CGSize(width: 100, height: 100),
            margin: 8
        )

        XCTAssertEqual(velocity, CGVector(dx: 3, dy: -4))
        XCTAssertEqual(position, CGPoint(x: 8, y: 91))
    }

    func testGreenSquareProjectileAvoidanceMatchesRunAwayAndSpeedCap() {
        let avoided = OriginalGreenSquareRule.velocityAvoidingProjectile(
            squarePosition: CGPoint(x: 100, y: 100),
            squareVelocity: CGVector(dx: 1, dy: 0),
            projectilePosition: CGPoint(x: 80, y: 100),
            projectileVelocity: CGVector(dx: 5, dy: 0),
            maximumSpeed: 3.41
        )
        XCTAssertEqual(avoided.length, 3.41, accuracy: 0.000_001)
        XCTAssertLessThan(avoided.dx, 0)

        let distant = OriginalGreenSquareRule.velocityAvoidingProjectile(
            squarePosition: .zero,
            squareVelocity: CGVector(dx: 1, dy: 2),
            projectilePosition: CGPoint(x: 200, y: 200),
            projectileVelocity: CGVector(dx: 1, dy: 0),
            maximumSpeed: 3.41
        )
        XCTAssertEqual(distant, CGVector(dx: 1, dy: 2))
    }

    func testSpawnDirectorUsesOriginalGeneratorRandomCallOrder() {
        var random = BlitzMaxRandomNumberGenerator(seed: 1)
        var director = SpawnDirector()

        let result = director.advance(
            frame: 444,
            spawningIsBlocked: false,
            using: &random
        )

        XCTAssertEqual(result.commands, [
            .generator(
                kind: .pinwheel,
                freezeFrames: 20,
                corner: .diagonalTopRightBottomLeft,
                rate: 105,
                size: 1
            ),
        ])
        XCTAssertEqual(random.rand(0, 100), 6)
    }

    func testParticleEmissionCanConsumeExactBlitzMaxRandomSequence() {
        var random = BlitzMaxRandomNumberGenerator(seed: 1)
        var particles = ParticleSimulation(
            arenaSize: CGSize(width: 1_024, height: 768),
            capacity: 1
        )

        particles.emit(
            at: CGPoint(x: 512, y: 384),
            kind: .random,
            color: .init(red: 255, green: 255, blue: 255),
            using: &random
        )

        XCTAssertEqual(particles.particles[0].activeFrames, 20)
        XCTAssertEqual(particles.particles[0].velocity.length, 18.205_519_338_120_723, accuracy: 0.0001)
        XCTAssertLessThan(particles.particles[0].velocity.dy, 0)
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

    func testParticleVerticalBounceTransformsBlitzMaxTopDownBounds() {
        var topRandom = BlitzMaxRandomNumberGenerator(seed: 1)
        var top = ParticleSimulation(
            arenaSize: CGSize(width: 100, height: 100),
            capacity: 1
        )
        top.emit(
            at: CGPoint(x: 50, y: 70),
            kind: .radialBomb,
            color: .init(red: 255, green: 255, blue: 255),
            rotationDegrees: -90,
            using: &topRandom
        )
        top.update()
        XCTAssertEqual(top.particles[0].position.y, 70, accuracy: 0.0001)
        XCTAssertEqual(top.particles[0].velocity.dy, -30.4, accuracy: 0.0001)

        var bottomRandom = BlitzMaxRandomNumberGenerator(seed: 1)
        var bottom = ParticleSimulation(
            arenaSize: CGSize(width: 100, height: 100),
            capacity: 1
        )
        bottom.emit(
            at: CGPoint(x: 50, y: 30),
            kind: .radialBomb,
            color: .init(red: 255, green: 255, blue: 255),
            rotationDegrees: 90,
            using: &bottomRandom
        )
        bottom.update()
        XCTAssertEqual(bottom.particles[0].position.y, 30, accuracy: 0.0001)
        XCTAssertEqual(bottom.particles[0].velocity.dy, 30.4, accuracy: 0.0001)
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
        XCTAssertGreaterThan(particles.particles[0].velocity.dy, 0)

        particles.applyBlackHole(at: CGPoint(x: 200, y: 100), size: 20, frame: 1)
        XCTAssertEqual(particles.particles[1].activeFrames, 27)
        XCTAssertLessThan(particles.particles[1].velocity.dy, 0)
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

    func testCaptureFlowCanAddressOriginalScreensAtMatchingFrames() {
        var flow = OriginalScreenFlow()
        flow.configureCapture(page: .friends, frame: 600, persistentTitleFrame: 600)

        XCTAssertEqual(flow.phase, .attract(.friends))
        XCTAssertEqual(flow.frame, 600)
        XCTAssertEqual(flow.persistentTitleFrame, 600)
    }

    func testGraphicsSetsKeepOriginalFolderAndFrameDimensions() {
        XCTAssertEqual(OriginalGraphicsSet.allCases.map(\.folderName), [
            "solid", "low", "med", "high", "user",
        ])
        XCTAssertEqual(OriginalGraphicsSet.low.iconFrameSize, CGSize(width: 24, height: 24))
        XCTAssertEqual(OriginalGraphicsSet.medium.iconFrameSize, CGSize(width: 32, height: 32))
        XCTAssertEqual(OriginalGraphicsSet.high.iconFrameSize, CGSize(width: 64, height: 64))
        XCTAssertEqual(OriginalGraphicsSet.low.snakeFrameSize, CGSize(width: 32, height: 32))
        XCTAssertEqual(OriginalGraphicsSet.solid.snakeFrameSize, CGSize(width: 56, height: 56))
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

    func testMenuTextAndControllerDirectionMatchOriginalControlSource() {
        var menu = OriginalMenuModel()
        menu.open(duringGame: false)
        menu.select(0)
        _ = menu.activate()
        XCTAssertEqual(menu.title, "Sure?")

        _ = menu.back()
        menu.select(1)
        _ = menu.activate()
        menu.select(2)
        _ = menu.activate()
        menu.select(0)
        _ = menu.adjust(by: -1)
        XCTAssertEqual(menu.settings.controllerType, .hybrid)
        _ = menu.adjust(by: 1)
        XCTAssertEqual(menu.settings.controllerType, .dualAnalog)

        _ = menu.back()
        menu.select(0)
        _ = menu.activate()
        XCTAssertEqual(Array(menu.lines.prefix(2)), ["SFX Volume:", "Music Volume:"])
    }

    func testVideoSettingsUseOriginalKeepChangesAndSelectiveRollback() {
        var menu = OriginalMenuModel()
        menu.open(duringGame: false)
        menu.select(1)
        _ = menu.activate()
        menu.select(1)
        _ = menu.activate()

        menu.select(5)
        _ = menu.adjust(by: 1)
        menu.select(2)
        _ = menu.adjust(by: 1)
        XCTAssertEqual(menu.settings.playfieldSizeIndex, 1)
        XCTAssertEqual(menu.runtimeSettings.playfieldSizeIndex, 0)

        menu.select(10)
        XCTAssertEqual(menu.activate(), .none)
        XCTAssertEqual(menu.page, .confirmKeepVideo)
        XCTAssertEqual(menu.title, "Keep Changes?")
        XCTAssertEqual(menu.selection, 1)

        XCTAssertEqual(menu.activate(), .none)
        XCTAssertEqual(menu.page, .settings)
        XCTAssertEqual(menu.settings.playfieldSizeIndex, 0)
        XCTAssertEqual(menu.settings.gridStyle, 1)
    }

    func testVideoSettingsExposeAndCycleOriginalScreenModes() {
        var menu = OriginalMenuModel()
        menu.open(duringGame: false)
        menu.select(1)
        _ = menu.activate()
        menu.select(1)
        _ = menu.activate()

        XCTAssertEqual(
            menu.lines[1],
            "Screen Size: 9/34 XGA (1024X768)"
        )
        XCTAssertEqual(
            menu.lines[2],
            "Playfield Size: 1/34 1024X768"
        )
        menu.select(1)
        _ = menu.adjust(by: 1)
        XCTAssertEqual(menu.settings.screenSizeIndex, 9)
        XCTAssertEqual(menu.settings.screenWidth, 1_152)
        XCTAssertEqual(menu.settings.screenHeight, 864)
    }

    func testAcceptedGameSettingsEndAnActiveGameLikeOriginalReturnCodeTwo() {
        var menu = OriginalMenuModel()
        menu.open(duringGame: true)
        menu.select(1)
        _ = menu.activate()
        menu.select(3)
        _ = menu.activate()
        menu.select(3)
        _ = menu.adjust(by: 1)
        menu.select(5)
        XCTAssertEqual(menu.activate(), .none)
        XCTAssertEqual(menu.page, .confirmKeepGame)

        menu.select(0)
        XCTAssertEqual(menu.activate(), .endGame)
        XCTAssertTrue(menu.settings.autoFire)
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

    func testLegacyConfigFixtureParsesEveryFieldAndRoundTripsInOriginalOrder() throws {
        let text = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Config.txt"),
            encoding: .utf8
        )
        let settings = LegacyConfigCodec.decode(text)

        XCTAssertFalse(settings.windowed)
        XCTAssertEqual(settings.controllerType, .dualAnalog)
        XCTAssertTrue(settings.autoFire)
        XCTAssertEqual(settings.keyMoveLeft, 65)
        XCTAssertEqual(settings.soundEffectsVolume, 0.56, accuracy: 0.0001)
        XCTAssertEqual(settings.gridStyle, 6)
        XCTAssertEqual(settings.gridRed, 3)
        XCTAssertEqual(settings.gridOpacity, 0.23, accuracy: 0.0001)
        XCTAssertEqual(settings.particleCount, 2_200)
        XCTAssertEqual(settings.particleDecay, 0.963999987, accuracy: 0.000001)
        XCTAssertEqual(settings.joyPorts.count, 4)
        XCTAssertEqual(settings.joyPorts[0].deadZone[0], 0.0599999987, accuracy: 0.000001)
        XCTAssertEqual(settings.joyPorts[0].optionButton, 7)
        XCTAssertEqual(settings.joyPorts[3].bombButton, 2)

        let encoded = LegacyConfigCodec.encode(settings)
        XCTAssertEqual(encoded.split(whereSeparator: \Character.isNewline).count, 280)
        XCTAssertEqual(Array(encoded.split(whereSeparator: \Character.isNewline).prefix(6)).map(String.init), [
            "[Windowed]", "False", "[Control Type]", "Dual Analog", "[Hybrid Config]", "0",
        ])
        XCTAssertEqual(LegacyConfigCodec.decode(encoded), settings)
    }

    func testLegacyColoursFixtureParsesAndEmitsAllNineteenEntries() throws {
        let text = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Colours.txt"),
            encoding: .utf8
        )
        let palette = try LegacyColoursCodec.decode(text)
        XCTAssertEqual(palette[.square], ParticleColor(red: 32, green: 255, blue: 32))
        XCTAssertEqual(palette[.snakeTail], ParticleColor(red: 255, green: 180, blue: 96))
        XCTAssertEqual(palette[.trail], ParticleColor(red: 240, green: 240, blue: 100))

        let encoded = LegacyColoursCodec.encode(palette)
        XCTAssertEqual(encoded.split(whereSeparator: \Character.isNewline).count, 76)
        XCTAssertEqual(try LegacyColoursCodec.decode(encoded), palette)
    }

    func testLegacyHighScoreFixtureValidatesAllThirtyRecordsAndRoundTrips() throws {
        let text = try String(
            contentsOf: repositoryRoot.appendingPathComponent("hiscores.dat"),
            encoding: .utf8
        )
        let scores = try LegacyHighScoreTable.decode(text)
        XCTAssertEqual(scores[.easy].count, 10)
        XCTAssertEqual(scores[.medium].count, 10)
        XCTAssertEqual(scores[.hard].count, 10)
        XCTAssertEqual(scores[.easy][0].score, 200_000)
        XCTAssertEqual(scores[.easy][0].checksum, 2_925)
        XCTAssertEqual(scores[.medium][0].score, 2_012_790)
        XCTAssertEqual(scores[.hard][0].name, "?       ")
        XCTAssertEqual(try LegacyHighScoreTable.decode(scores.encode()), scores)
    }

    func testLegacyHighScoreChecksumFailureResetsWholeTable() throws {
        let original = LegacyHighScoreTable()
        var lines = original.encode().components(separatedBy: "\n")
        lines[4] = "1"
        let corrupted = lines.joined(separator: "\n")

        XCTAssertThrowsError(try LegacyHighScoreTable.decode(corrupted))
        XCTAssertEqual(LegacyHighScoreTable.decodeOrDefault(corrupted), LegacyHighScoreTable())
    }

    func testLegacyHighScoreInsertionUsesEightASCIICharactersAndRecordedSettings() {
        var scores = LegacyHighScoreTable()
        var settings = OriginalRuntimeSettings()
        settings.controllerType = .hybrid
        settings.hybridConfiguration = 2
        settings.gridStyle = 6
        settings.autoFire = true
        settings.inertia = 0.5

        let position = scores.insert(
            score: 250_000,
            playTime: LegacyHighScoreTable.playTime(frames: 50 * 65),
            name: "Älex",
            settings: settings.highScoreSettingsString(),
            difficulty: .easy
        )
        XCTAssertEqual(position, 0)
        XCTAssertEqual(scores[.easy][0].name, "?lex    ")
        XCTAssertEqual(scores[.easy][0].playTime, "1 mn, 5 secs")
        XCTAssertEqual(
            scores[.easy][0].settings,
            "5.4,1024X768,1024X768,Hybrid-2,0,0,6,1,50"
        )
        XCTAssertTrue(scores[.easy][0].isChecksumValid)
        XCTAssertNil(scores.insert(
            score: scores[.easy].last?.score ?? 0,
            playTime: "",
            name: "Nobody",
            settings: "",
            difficulty: .easy
        ))
    }

    func testOriginalHighScoreNameEntryMatchesEightCharacterEditor() {
        var entry = OriginalHighScoreNameEntry()
        XCTAssertEqual(entry.name, "        ")
        XCTAssertEqual(entry.selectedIndex, 0)

        entry.cycleCharacter(by: 1)
        XCTAssertEqual(entry.characters[0], 65)
        entry.toggleCase()
        XCTAssertEqual(entry.characters[0], 97)
        entry.moveSelection(by: -1)
        XCTAssertEqual(entry.selectedIndex, 7)
        entry.cycleCharacter(by: -1)
        XCTAssertEqual(entry.characters[7], 64)

        entry.setASCII(90)
        XCTAssertEqual(entry.name, "a      Z")
        XCTAssertEqual(entry.selectedIndex, 0)
        entry.setASCII(31)
        XCTAssertEqual(entry.name, "a      Z")
    }

    func testOriginalSoundManifestMatchesSourceIncludingItsMissingWarningAsset() {
        let soundDirectory = repositoryRoot.appendingPathComponent("sounds", isDirectory: true)
        let missing = OriginalSoundEffect.allCases.map(\.fileName).filter {
            !FileManager.default.fileExists(atPath: soundDirectory.appendingPathComponent($0).path)
        }

        // The 5.4 source loads this file, but it is absent from the shipped archive;
        // BlitzMax therefore leaves that TSound null and PlaySound2 stays silent.
        XCTAssertEqual(missing, ["shieldwarning.wav"])
        XCTAssertEqual(OriginalSoundEffect.blackHoleKilled.fileName, "Explo1.wav")
        XCTAssertEqual(OriginalSoundEffect.highScore.fileName, "bonus1.wav")
        XCTAssertEqual(OriginalSoundEffect.interceptorHit.fileName, "quarkhit2.wav")
    }

    func testOriginalSpatialAudioUsesPlayfieldRelativePanAndAttenuation() {
        XCTAssertEqual(
            OriginalSpatialAudio.mix(
                source: CGPoint(x: 512, y: 384),
                listener: CGPoint(x: 512, y: 384),
                playfieldSize: CGSize(width: 1_024, height: 768)
            ),
            OriginalAudioMix(pan: 0, volume: 1)
        )

        let mix = OriginalSpatialAudio.mix(
            source: CGPoint(x: 768, y: 768),
            listener: CGPoint(x: 512, y: 384),
            playfieldSize: CGSize(width: 1_024, height: 768)
        )
        XCTAssertEqual(mix.pan, 0.25, accuracy: 0.0001)
        XCTAssertEqual(mix.volume, 0.92625, accuracy: 0.0001)
    }

    func testConvertedTrackerMusicFilesAreReadableAndKeepOriginalDurations() throws {
        let minimumDurations: [OriginalMusicTrack: TimeInterval] = [
            .intro: 30,
            .gameplay: 261,
            .highScore: 38,
        ]
        for track in OriginalMusicTrack.allCases {
            let url = repositoryRoot
                .appendingPathComponent("music", isDirectory: true)
                .appendingPathComponent(track.fileName)
            let file = try AVAudioFile(forReading: url)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            XCTAssertGreaterThanOrEqual(duration, minimumDurations[track] ?? 0)
            XCTAssertEqual(file.processingFormat.sampleRate, 44_100, accuracy: 0.1)
            XCTAssertEqual(file.processingFormat.channelCount, 2)
        }
    }

    func testPersistenceStoreImportsLegacyDirectoryAndWritesApplicationSupportCopies() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GridWarsPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        let legacy = root.appendingPathComponent("legacy", isDirectory: true)
        let applicationSupport = root.appendingPathComponent("Application Support/GridWars", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)

        let settings = OriginalRuntimeSettings()
        try LegacyConfigCodec.encode(settings).write(
            to: legacy.appendingPathComponent(GridWarsPersistenceStore.configFileName),
            atomically: true,
            encoding: .utf8
        )
        try LegacyColoursCodec.encode(OriginalColorPalette()).write(
            to: legacy.appendingPathComponent(GridWarsPersistenceStore.coloursFileName),
            atomically: true,
            encoding: .utf8
        )
        try LegacyHighScoreTable().encode().write(
            to: legacy.appendingPathComponent(GridWarsPersistenceStore.scoresFileName),
            atomically: true,
            encoding: .utf8
        )

        let store = GridWarsPersistenceStore(
            directoryURL: applicationSupport,
            legacyDirectoryURL: legacy
        )
        var state = try store.load()
        XCTAssertEqual(state.settings, settings)
        XCTAssertTrue(FileManager.default.fileExists(atPath: applicationSupport
            .appendingPathComponent(GridWarsPersistenceStore.scoresFileName).path))

        state.settings.gridStyle = 20
        try store.save(state)
        let saved = try String(
            contentsOf: applicationSupport.appendingPathComponent(GridWarsPersistenceStore.configFileName),
            encoding: .utf8
        )
        XCTAssertEqual(LegacyConfigCodec.decode(saved).gridStyle, 20)
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

    @MainActor
    func testVectorFontUsesUnsmoothedOpenGLLikeStrokes() {
        let node = OriginalVectorFont().makeNode(
            "A",
            x: 0,
            yFromTop: 0,
            scale: 1,
            arenaHeight: 100,
            color: .white
        )

        XCTAssertFalse(node.isAntialiased)
        XCTAssertEqual(node.lineCap, .butt)
        XCTAssertEqual(node.lineJoin, .miter)
        XCTAssertEqual(node.lineWidth, 2)
    }

    func testGridDrawRectConvertsBlitzMaxTopLeftAnchor() {
        XCTAssertEqual(
            OriginalDrawRectRule.sceneRect(
                at: CGPoint(x: 128.25, y: 639.75),
                width: 3,
                height: 3
            ),
            CGRect(x: 128.25, y: 636.75, width: 3, height: 3)
        )
    }

    func testGridLineConvertsOpenGLPixelCenterAfterYInversion() {
        XCTAssertEqual(
            OriginalLineRasterRule.scenePixelCenter(CGPoint(x: 128.25, y: 639.75)),
            CGPoint(x: 128.75, y: 639.25)
        )
    }

    func testMoireGridMapsSourceRowAndBottomRightTriangleAfterYInversion() {
        XCTAssertEqual(
            OriginalMoireGridRule.sourceRow(forSceneRow: 0, rowCount: 48),
            47
        )
        XCTAssertEqual(
            OriginalMoireGridRule.sceneTriangle(
                cellPoints: [
                    CGPoint(x: 0, y: 0),
                    CGPoint(x: 16, y: 0),
                    CGPoint(x: 16, y: 16),
                    CGPoint(x: 0, y: 16),
                ],
                scale: 0.5
            ),
            [
                CGPoint(x: 16, y: 8),
                CGPoint(x: 16, y: 0),
                CGPoint(x: 8, y: 0),
            ]
        )
    }

    func testMenuTargetRotatesMax2DDeltaAroundSharedStartPoint() {
        let position = CGPoint(x: 100, y: 200)
        let pivot = OriginalTargetRule.scenePivot(position: position, size: 4)
        let endpoints = OriginalTargetRule.sceneEndpoints(
            position: position,
            frame: 0,
            size: 4
        )

        XCTAssertEqual(pivot, CGPoint(x: 96, y: 204))
        XCTAssertEqual(endpoints.count, 8)
        XCTAssertEqual(endpoints[0], CGPoint(x: 104, y: 196))
        XCTAssertEqual(endpoints[2], CGPoint(x: 88, y: 196))
        XCTAssertEqual(endpoints[4], CGPoint(x: 88, y: 212))
        XCTAssertEqual(endpoints[6], CGPoint(x: 104, y: 212))
    }

    func testMax2DLightBlendCompensatesSpriteKitPremultiplication() {
        XCTAssertEqual(
            OriginalBlendRule.spriteKitAdditiveNodeAlpha(sourceAlpha: 0.85),
            sqrt(0.85),
            accuracy: 0.000_001
        )
        XCTAssertEqual(OriginalBlendRule.spriteKitAdditiveNodeAlpha(sourceAlpha: -1), 0)
        XCTAssertEqual(OriginalBlendRule.spriteKitAdditiveNodeAlpha(sourceAlpha: 2), 1)
    }

    func testRGBSplitRedOffsetUsesSourceSideAxisAndInvertsY() {
        let origin = CGPoint(x: 100, y: 600)
        XCTAssertEqual(
            OriginalRGBSplitRule.redPoint(
                CGPoint(x: 100.5, y: 600.5),
                origin: origin,
                displacementAxis: .horizontal
            ),
            CGPoint(x: 100.5, y: 600.5)
        )
        XCTAssertEqual(
            OriginalRGBSplitRule.redPoint(
                CGPoint(x: 104, y: 596),
                origin: origin,
                displacementAxis: .horizontal
            ),
            CGPoint(x: 100, y: 600)
        )
        XCTAssertEqual(
            OriginalRGBSplitRule.redPoint(
                CGPoint(x: 104, y: 600),
                origin: origin,
                displacementAxis: .vertical
            ),
            CGPoint(x: 104, y: 600)
        )
        XCTAssertEqual(
            OriginalRGBSplitRule.redPoint(
                CGPoint(x: 100, y: 596),
                origin: origin,
                displacementAxis: .vertical
            ),
            CGPoint(x: 96, y: 600)
        )
    }

    func testGetReadyPerformsExplicitAndUpdateAllGridSteps() {
        XCTAssertEqual(OriginalGetReadyRule.ringPullFrame, 60)
        XCTAssertEqual(OriginalGetReadyRule.gridUpdatesPerFrame, 2)
    }

    func testCaptureCatalogCoversEveryFidelityCategory() {
        let scenarios = OriginalCaptureScenario.all
        XCTAssertEqual(scenarios.count, 107)
        XCTAssertEqual(Set(scenarios.map(\.name)).count, scenarios.count)
        XCTAssertEqual(
            OriginalCaptureScenario(name: "power-up-message")?.subject,
            .powerUpMessage
        )
        XCTAssertEqual(
            OriginalCaptureScenario(name: "get-ready-title")?.subject,
            .getReady(frame: 29)
        )
        XCTAssertEqual(
            OriginalCaptureScenario(name: "get-ready-rings")?.subject,
            .getReady(frame: 79)
        )

        var enemies = 0
        var enemyMotions = 0
        var blackHoleCaptures = 0
        var snakeCaptures = 0
        var interceptorCaptures = 0
        var triangleCaptures = 0
        var generators = 0
        var powerUps = 0
        var grids = 0
        var particles = 0
        var graphicsSets = 0
        var menus = 0
        for scenario in scenarios {
            XCTAssertEqual(OriginalCaptureScenario(name: scenario.name), scenario)
            switch scenario.subject {
            case .enemy: enemies += 1
            case .enemyMotion: enemyMotions += 1
            case .blackHole: blackHoleCaptures += 1
            case .snake: snakeCaptures += 1
            case .interceptor: interceptorCaptures += 1
            case .triangle: triangleCaptures += 1
            case .generator: generators += 1
            case .powerUp: powerUps += 1
            case .grid: grids += 1
            case .particleStyle: particles += 1
            case .graphicsSet: graphicsSets += 1
            case .menu: menus += 1
            default: break
            }
        }
        XCTAssertEqual(enemies, OriginalEnemyKind.allCases.count)
        XCTAssertEqual(enemyMotions, 6)
        XCTAssertEqual(blackHoleCaptures, OriginalBlackHoleCapture.allCases.count)
        XCTAssertEqual(snakeCaptures, OriginalSnakeCapture.allCases.count)
        XCTAssertEqual(interceptorCaptures, OriginalInterceptorCapture.allCases.count)
        XCTAssertEqual(triangleCaptures, OriginalTriangleCapture.allCases.count)
        XCTAssertEqual(generators, OriginalEnemyKind.allCases.count)
        XCTAssertEqual(powerUps, PowerUpKind.allCases.count)
        XCTAssertEqual(grids, 21)
        XCTAssertEqual(particles, 4)
        XCTAssertEqual(graphicsSets, OriginalGraphicsSet.allCases.count)
        XCTAssertEqual(menus, OriginalMenuCapture.allCases.count)
    }

    func testOnlyIsolatedGridAndParticleCapturesHideArenaBorder() {
        XCTAssertTrue(OriginalCaptureScenario(name: "grid-00")!.subject.hidesArenaBorder)
        XCTAssertTrue(OriginalCaptureScenario(name: "particle-0")!.subject.hidesArenaBorder)
        XCTAssertFalse(OriginalCaptureScenario(name: "gameplay")!.subject.hidesArenaBorder)
        XCTAssertFalse(OriginalCaptureScenario(name: "video")!.subject.hidesArenaBorder)
    }

    func testCaptureRandomGeneratorIsRepeatableWhenSeeded() {
        var first = GameRandomNumberGenerator(seed: 42)
        var second = GameRandomNumberGenerator(seed: 42)
        let firstValues = (0..<32).map { _ in first.next() }
        let secondValues = (0..<32).map { _ in second.next() }

        XCTAssertEqual(firstValues, secondValues)
        XCTAssertGreaterThan(Set(firstValues).count, 1)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
