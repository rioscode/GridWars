import CoreGraphics
import XCTest

final class MetalEffectsPrototypeTests: XCTestCase {
    func testRuntimeShaderSourceIsPackaged() throws {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(
            forResource: "GridWarsEffects",
            withExtension: "metal"
        ))
        let source = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(source.contains("gridWarsEffectVertex"))
        XCTAssertTrue(source.contains("gridWarsEffectFragment"))
    }

    func testMetalPrototypeIsOptInAndCanBeOverriddenByArguments() {
        XCTAssertFalse(MetalEffectsConfiguration.resolved(
            environment: [:],
            arguments: []
        ).isEnabled)
        XCTAssertTrue(MetalEffectsConfiguration.resolved(
            environment: [MetalEffectsConfiguration.environmentKey: "yes"],
            arguments: []
        ).isEnabled)
        XCTAssertTrue(MetalEffectsConfiguration.resolved(
            environment: [:],
            arguments: [MetalEffectsConfiguration.enableArgument]
        ).isEnabled)
        XCTAssertFalse(MetalEffectsConfiguration.resolved(
            environment: [MetalEffectsConfiguration.environmentKey: "1"],
            arguments: [MetalEffectsConfiguration.disableArgument]
        ).isEnabled)
    }

    func testPointsCyclingGridUsesSourceOrderedPointAndHighlightPasses() {
        let grid = GridSimulation(arenaSize: CGSize(width: 80, height: 80), spacing: 16)
        let frame = MetalEffectsFrame.make(
            pointsCyclingGrid: grid,
            cyclingColor: MetalEffectColor(red: 250, green: 20, blue: 30),
            gridOpacity: 0.85,
            particleLinesStyleOne: nil
        )

        XCTAssertEqual(frame.coverage, [.pointsCyclingGrid])
        XCTAssertEqual(frame.gridInstances.count, 35)
        XCTAssertTrue(frame.particleInstances.isEmpty)
        XCTAssertEqual(frame.gridInstances[0].geometry, SIMD4(0, -2, 2, 2))
        XCTAssertEqual(frame.gridInstances[25].geometry, SIMD4(64, -3, 3, 3))
        XCTAssertEqual(frame.gridInstances[30].geometry, SIMD4(0, 61, 3, 3))
    }

    func testParticleStyleOneProducesOnePixelAlignedWideLinePerActiveParticle() {
        var particles = ParticleSimulation(
            arenaSize: CGSize(width: 1_024, height: 768),
            capacity: 1,
            particleLife: 40,
            decay: 0.95
        )
        var random = BlitzMaxRandomNumberGenerator(seed: 7)
        particles.emit(
            at: CGPoint(x: 100, y: 200),
            kind: .directed,
            color: ParticleColor(red: 200, green: 64, blue: 255),
            rotationDegrees: 0,
            using: &random
        )
        let particle = particles.particles[0]
        let frame = MetalEffectsFrame.make(
            pointsCyclingGrid: nil,
            cyclingColor: MetalEffectColor(red: 0, green: 0, blue: 0),
            gridOpacity: 0,
            particleLinesStyleOne: particles
        )

        XCTAssertEqual(frame.coverage, [.particleLinesStyleOne])
        XCTAssertEqual(frame.particleInstances.count, 1)
        let instance = frame.particleInstances[0]
        let start = OriginalLineRasterRule.scenePixelCenter(particle.position)
        XCTAssertEqual(instance.geometry.x, Float(start.x), accuracy: 0.000_1)
        XCTAssertEqual(instance.geometry.y, Float(start.y), accuracy: 0.000_1)
        XCTAssertEqual(
            instance.geometry.z,
            Float(start.x + particle.velocity.dx * 2),
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            instance.geometry.w,
            Float(start.y + particle.velocity.dy * 2),
            accuracy: 0.000_1
        )
        XCTAssertEqual(instance.parameters.x, MetalEffectInstance.Kind.line.rawValue)
        XCTAssertEqual(instance.parameters.y, 2)
        XCTAssertEqual(instance.color.w, 0.9, accuracy: 0.000_1)
    }

    func testInstanceMemoryLayoutMatchesMetalShader() {
        XCTAssertEqual(MemoryLayout<MetalEffectInstance>.stride, 48)
        XCTAssertEqual(MemoryLayout<MetalEffectInstance>.alignment, 16)
    }

    func testViewportPreservesSpriteKitAspectFitAndCameraOffset() {
        let viewport = MetalEffectsViewport(
            sceneSize: CGSize(width: 1_024, height: 768),
            drawableSize: CGSize(width: 2_400, height: 1_200),
            cameraOffset: CGPoint(x: 128, y: 96)
        )

        XCTAssertEqual(viewport.scale, 1.5625, accuracy: 0.000_1)
        XCTAssertEqual(viewport.contentOffset, SIMD2(400, 0))
        XCTAssertEqual(viewport.cameraOffset, SIMD2(128, 96))
    }
}
