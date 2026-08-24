import XCTest

final class GameRulesTests: XCTestCase {
    func testMultiplierIncreasesEveryTwentyFiveKills() {
        var session = GameSession()

        for _ in 0..<25 {
            session.registerEnemyDestroyed(baseScore: 100)
        }

        XCTAssertEqual(session.multiplier, 2)
        XCTAssertEqual(session.score, 2_600)
    }

    func testPlayerHitCostsLifeAndResetsMultiplier() {
        var session = GameSession()
        for _ in 0..<50 {
            session.registerEnemyDestroyed(baseScore: 10)
        }

        session.registerPlayerHit()

        XCTAssertEqual(session.lives, 2)
        XCTAssertEqual(session.multiplier, 1)
        XCTAssertEqual(session.killsSinceDamage, 0)
    }

    func testBombCannotBeUsedAfterSupplyIsEmpty() {
        var session = GameSession()

        XCTAssertTrue(session.useBomb())
        XCTAssertTrue(session.useBomb())
        XCTAssertTrue(session.useBomb())
        XCTAssertFalse(session.useBomb())
        XCTAssertEqual(session.bombs, 0)
    }

    func testExtraLifeIsGrantedAtScoreThreshold() {
        var session = GameSession()

        session.registerEnemyDestroyed(baseScore: 100_000)

        XCTAssertEqual(session.lives, 4)
        XCTAssertEqual(session.nextExtraLifeScore, 200_000)
    }

    func testSpawnPacingHasSafeLowerAndUpperBounds() {
        XCTAssertEqual(SpawnPacing.interval(forElapsedTime: 10_000), 0.34)
        XCTAssertEqual(SpawnPacing.maximumEnemies(forElapsedTime: 10_000), 80)
    }
}
