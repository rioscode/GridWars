@preconcurrency import SpriteKit

enum GridStyle: Int, CaseIterable {
    case pointsSolid
    case pointsCycling
    case particlesSolid
    case particlesCycling
    case majorLinesSolid
    case majorLinesCycling
    case lineQuadsSolid
    case lineQuadsCycling
    case denseMeshSolid
    case denseMeshBlue
    case stretchedOriginal
    case stretchedGrid
    case stretchedDiagonal
    case rgbSplit
    case solidQuads
    case solidQuadsCycling
    case stretchedQuads
    case sineQuads
    case moireTriangles
    case thickStrips
    case none
}

@MainActor
final class GridRenderer {
    private struct RGBSpiralVertex {
        let position: CGPoint
        let origin: CGPoint
        let redDisplacementAxis: OriginalRGBSplitRule.DisplacementAxis
    }

    let node = SKNode()

    private let stretchBucketCount = 64
    private var animationFrame = 0
    private lazy var particleImage = OriginalGraphics.cgImage(named: "particle", setIndex: 0)
    private var renderedStyle: GridStyle?
    private var reusableNodes: [SKNode] = []
    private var reusableNodeIndex = 0
    private var presentationInterpolationAlpha: CGFloat = 1
    private let maximumSpritePointQuadCount = 5_000
    private var pointTextures: [Int: SKTexture] = [:]
    private var pointQuadPlan: GridPointQuadPlan?
    /// Last rectangle written into each pooled point sprite. A pooled slot
    /// always maps to the same lattice position while the topology is stable,
    /// so an unchanged rectangle skips every SpriteKit setter.
    private var pointSlotRects: [CGRect] = []
    private var pointSlotColor: SIMD4<Double>?
    private var pointSlotAlpha: CGFloat?
    private var pointColorChanged = true
    private var pointAlphaChanged = true
    private var hiddenSlotStart: Int?

    func advanceAnimation() {
        animationFrame = (animationFrame + 1) % 7_200
    }

    func resetAnimation() {
        animationFrame = 0
    }

    func render(
        simulation: GridSimulation,
        style: GridStyle,
        solidColor: SKColor,
        cyclingColor: SKColor,
        opacity: CGFloat,
        interpolationAlpha: CGFloat = 1
    ) {
        beginFrame(style: style)
        presentationInterpolationAlpha = interpolationAlpha
        let alpha = abs(opacity)

        switch style {
        case .pointsSolid:
            addPointGrid(simulation, color: solidColor, alpha: alpha, particleStyle: false)
        case .pointsCycling:
            addPointGrid(simulation, color: cyclingColor, alpha: alpha, particleStyle: false)
        case .particlesSolid:
            addPointGrid(simulation, color: solidColor, alpha: alpha, particleStyle: true)
        case .particlesCycling:
            addPointGrid(simulation, color: cyclingColor, alpha: alpha, particleStyle: true)
        case .majorLinesSolid:
            addMajorLines(simulation, color: solidColor, alpha: 0.9)
        case .majorLinesCycling:
            addMajorLines(simulation, color: cyclingColor, alpha: 0.9)
        case .lineQuadsSolid:
            addLineGrid(simulation, color: solidColor, alpha: alpha)
        case .lineQuadsCycling:
            addLineGrid(simulation, color: cyclingColor, alpha: alpha)
        case .denseMeshSolid:
            addDenseMesh(
                simulation,
                color: solidColor,
                alpha: OriginalBlendRule.spriteKitAdditiveNodeAlpha(sourceAlpha: alpha)
            )
        case .denseMeshBlue:
            addTriangularMesh(
                simulation,
                color: SKColor(red: 0.005, green: 0.05, blue: 0.3, alpha: 1),
                alpha: 1
            )
        case .stretchedOriginal:
            addStretchedEdges(simulation)
        case .stretchedGrid:
            addStretchedCheckerLines(simulation, diagonals: false)
        case .stretchedDiagonal:
            addStretchedCheckerLines(simulation, diagonals: true)
        case .rgbSplit:
            addRGBSpiral(simulation, alpha: 1)
        case .solidQuads:
            addAlternatingQuads(simulation, color: solidColor, alpha: alpha)
        case .solidQuadsCycling:
            addAlternatingQuads(simulation, color: cyclingColor, alpha: alpha)
        case .stretchedQuads:
            addStretchedQuads(simulation, alpha: alpha)
        case .sineQuads:
            addSineQuads(
                simulation,
                color: solidColor,
                cyclingColor: cyclingColor,
                alpha: alpha
            )
        case .moireTriangles:
            addMoireTriangles(
                simulation,
                alpha: OriginalBlendRule.spriteKitAdditiveNodeAlpha(sourceAlpha: alpha)
            )
        case .thickStrips:
            addThickStrips(simulation, color: solidColor, alpha: alpha)
        case .none:
            break
        }
        finishFrame()
    }

    private func beginFrame(style: GridStyle) {
        if renderedStyle != style {
            node.removeAllChildren()
            reusableNodes.removeAll(keepingCapacity: true)
            renderedStyle = style
            resetPointSpriteCache()
        }
        hiddenSlotStart = nil
        reusableNodeIndex = 0
    }

    private func finishFrame() {
        guard reusableNodeIndex < reusableNodes.count else {
            hiddenSlotStart = nil
            return
        }
        for index in reusableNodeIndex..<reusableNodes.count {
            reusableNodes[index].isHidden = true
        }
        hiddenSlotStart = reusableNodeIndex
    }

    private func addPointGrid(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat,
        particleStyle: Bool
    ) {
        if particleStyle {
            addParticleImageGrid(grid, color: color, alpha: alpha)
            return
        }

        if shouldUseSpritePointGrid(grid), addSpritePointGrid(grid, color: color, alpha: alpha) {
            return
        }
        resetPointSpriteCache()

        let base = CGMutablePath()
        let columnHighlights = CGMutablePath()
        let rowHighlights = CGMutablePath()
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let point = presentationPoint(grid, column: column, row: row)
                base.addRect(OriginalDrawRectRule.sceneRect(at: point, width: 2, height: 2))
                if column > 0, column.isMultiple(of: 4) {
                    columnHighlights.addRect(
                        OriginalDrawRectRule.sceneRect(at: point, width: 3, height: 3)
                    )
                }
                if row > 0, row.isMultiple(of: 4) {
                    rowHighlights.addRect(
                        OriginalDrawRectRule.sceneRect(at: point, width: 3, height: 3)
                    )
                }
            }
        }
        addShape(path: base, fill: color, alpha: alpha)
        addShape(path: columnHighlights, fill: color, alpha: alpha)
        addShape(path: rowHighlights, fill: color, alpha: alpha)
    }

    /// Opt-in pooled-sprite representation of the point grid.
    ///
    /// Rebuilding one large CGPath every display frame makes SpriteKit
    /// retessellate every rectangle, so this path reuses one nearest-filtered
    /// pixel texture and the same node pool across the original three additive
    /// passes. Measured against the `SKShapeNode` path it is 4.6x more expensive
    /// because SpriteKit still traverses and sorts thousands of nodes per frame.
    /// It is therefore reachable only through `--grid-sprite-points` and is kept
    /// only so the comparison can be repeated on a device.
    ///
    /// Returns `false` when the required textures could not be created so the
    /// caller can fall back to the original `SKShapeNode` representation.
    @discardableResult
    private func addSpritePointGrid(_ grid: GridSimulation, color: SKColor, alpha: CGFloat) -> Bool {
        let plan = cachedPointQuadPlan(for: grid)
        let baseTexture = pointTexture(side: 2)
        let highlightTexture = pointTexture(side: 3)
        guard let baseTexture, let highlightTexture else {
            resetPointSpriteCache()
            return false
        }

        let clampedAlpha = max(0, min(1, alpha))
        let frameColor = Self.rgba(of: color)
        pointColorChanged = frameColor == nil || pointSlotColor != frameColor
        pointAlphaChanged = pointSlotAlpha != clampedAlpha
        pointSlotColor = frameColor
        pointSlotAlpha = clampedAlpha

        let points = grid.points
        let interpolationAlpha = presentationInterpolationAlpha
        for quad in plan.quads {
            let position = points[quad.pointIndex].presentationPosition(
                interpolationAlpha: interpolationAlpha
            )
            addPointSprite(
                rect: OriginalDrawRectRule.sceneRect(
                    at: position,
                    width: quad.side,
                    height: quad.side
                ),
                texture: quad.side == 2 ? baseTexture : highlightTexture,
                color: color,
                alpha: clampedAlpha
            )
        }
        return true
    }

    private func addPointSprite(
        rect: CGRect,
        texture: SKTexture,
        color: SKColor,
        alpha: CGFloat
    ) {
        let slot = reusableNodeIndex
        let previousRect: CGRect?
        if slot < reusableNodes.count, let sprite = reusableNodes[slot] as? SKSpriteNode {
            reusableNodeIndex += 1
            if let hiddenSlotStart, slot >= hiddenSlotStart {
                sprite.isHidden = false
            }
            if sprite.texture !== texture {
                sprite.texture = texture
                sprite.size = texture.size()
            }
            previousRect = slot < pointSlotRects.count ? pointSlotRects[slot] : nil
            if previousRect == rect, !pointColorChanged, !pointAlphaChanged {
                return
            }
            if previousRect != rect {
                sprite.position = rect.origin
            }
            growPointSlotRects(to: slot, rect: rect)
            if pointColorChanged {
                sprite.color = color
            }
            if pointAlphaChanged {
                sprite.alpha = alpha
            }
            return
        }

        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = .zero
        sprite.blendMode = .add
        sprite.colorBlendFactor = 1
        sprite.zPosition = 0
        sprite.size = texture.size()
        sprite.position = rect.origin
        sprite.color = color
        sprite.alpha = alpha
        insertReusableNode(sprite)
        growPointSlotRects(to: slot, rect: rect)
    }

    private func growPointSlotRects(to slot: Int, rect: CGRect) {
        if slot < pointSlotRects.count {
            pointSlotRects[slot] = rect
        } else {
            pointSlotRects.append(rect)
        }
    }

    private func cachedPointQuadPlan(for grid: GridSimulation) -> GridPointQuadPlan {
        if let pointQuadPlan, pointQuadPlan.columns == grid.columns, pointQuadPlan.rows == grid.rows {
            return pointQuadPlan
        }
        let plan = GridPointQuadPlan(grid: grid)
        pointQuadPlan = plan
        resetPointSpriteCache()
        return plan
    }

    private func resetPointSpriteCache() {
        pointSlotRects.removeAll(keepingCapacity: true)
        pointSlotColor = nil
        pointSlotAlpha = nil
        pointColorChanged = true
        pointAlphaChanged = true
    }

    private func shouldUseSpritePointGrid(_ grid: GridSimulation) -> Bool {
        // Measured on the deterministic projectile benchmark with the default
        // 4,496-rectangle grid: the pooled-sprite representation cost 514 ms of
        // main-thread time per 11 s against 111 ms for the original SKShapeNode
        // path. It is therefore never the default and stays an explicit opt-in so
        // the comparison can be repeated on a device without rewriting it.
        // See docs/iOS-Performance/MEASUREMENTS-GRID-SPRITE-2026-10-09.md.
        guard ProcessInfo.processInfo.arguments.contains(Self.spritePointGridArgument) else {
            return false
        }
        return pointGridQuadCount(grid) <= maximumSpritePointQuadCount
    }

    private static let spritePointGridArgument = "--grid-sprite-points"

    private func pointGridQuadCount(_ grid: GridSimulation) -> Int {
        let base = grid.columns * grid.rows
        let highlightedColumns = max(0, (grid.columns - 1) / 4) * grid.rows
        let highlightedRows = max(0, (grid.rows - 1) / 4) * grid.columns
        return base + highlightedColumns + highlightedRows
    }

    private func pointTexture(side: Int) -> SKTexture? {
        if let cached = pointTextures[side] {
            return cached
        }
        guard let texture = Self.makePointTexture(side: side) else { return nil }
        pointTextures[side] = texture
        return texture
    }

    private static func rgba(of color: SKColor) -> SIMD4<Double>? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #if canImport(UIKit)
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        #else
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif
        return SIMD4(Double(red), Double(green), Double(blue), Double(alpha))
    }

    private static func makePointTexture(side: Int) -> SKTexture? {
        let side = max(1, side)
        let pixels = [UInt8](repeating: 255, count: side * side * 4)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: side,
                height: side,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private func addParticleImageGrid(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        guard grid.columns > 1,
              grid.rows > 1,
              let particle = particleImage,
              let coloredParticle = coloredParticleImage(particle, color: color) else {
            return
        }
        let width = max(1, Int(grid.arenaSize.width.rounded()))
        let height = max(1, Int(grid.arenaSize.height.rounded()))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        context.setFillColor(SKColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.setBlendMode(.plusLighter)
        let particleSize: CGFloat = 22.5
        for column in 1..<grid.columns {
            for row in 1..<grid.rows {
                let point = presentationPoint(grid, column: column, row: row)
                let highlights = (column.isMultiple(of: 4) ? 1 : 0)
                    + (row.isMultiple(of: 4) ? 1 : 0)
                context.setAlpha(min(1, alpha + CGFloat(highlights) * 0.25))
                context.draw(
                    coloredParticle,
                    in: CGRect(
                        x: point.x - particleSize / 2,
                        y: point.y - particleSize / 2,
                        width: particleSize,
                        height: particleSize
                    )
                )
            }
        }

        guard let image = context.makeImage() else { return }

        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        let sprite = reusableSpriteNode()
        sprite.texture = texture
        sprite.anchorPoint = .zero
        sprite.position = .zero
        sprite.size = grid.arenaSize
        sprite.color = .white
        sprite.colorBlendFactor = 0
        sprite.alpha = 1
        sprite.blendMode = .add
    }

    private func coloredParticleImage(_ particle: CGImage, color: SKColor) -> CGImage? {
        let width = particle.width
        let height = particle.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(particle, in: CGRect(x: 0, y: 0, width: width, height: height))
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        context.setBlendMode(.multiply)
        context.setFillColor(red: red, green: green, blue: blue, alpha: alpha)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func addMajorLines(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let path = CGMutablePath()
        for column in stride(from: 4, to: grid.columns, by: 4) {
            appendLineStrip(
                to: path,
                points: stride(from: 0, through: grid.rows, by: 4).map {
                    presentationPoint(grid, column: column, row: $0)
                }
            )
        }
        for row in stride(from: 4, to: grid.rows, by: 4) {
            appendLineStrip(
                to: path,
                points: stride(from: 0, through: grid.columns, by: 4).map {
                    presentationPoint(grid, column: $0, row: row)
                }
            )
        }
        addShape(path: path, stroke: color, alpha: alpha, lineWidth: 2)
    }

    private func addLineGrid(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let regular = CGMutablePath()
        let highlight = CGMutablePath()
        for column in 0..<grid.columns {
            appendLineStrip(
                to: column.isMultiple(of: 4) ? highlight : regular,
                points: (0...grid.rows).map {
                    presentationPoint(grid, column: column, row: $0)
                }
            )
        }
        for row in 0..<grid.rows {
            appendLineStrip(
                to: row.isMultiple(of: 4) ? highlight : regular,
                points: (0...grid.columns).map {
                    presentationPoint(grid, column: $0, row: row)
                }
            )
        }
        addShape(path: regular, stroke: color, alpha: alpha, lineWidth: 1)
        addShape(path: highlight, stroke: color, alpha: min(1, alpha + 0.25), lineWidth: 1)
    }

    private func addDenseMesh(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let orthogonal = CGMutablePath()
        for row in 0..<grid.rows {
            appendLineStrip(
                to: orthogonal,
                points: (0...grid.columns).map {
                    presentationPoint(grid, column: $0, row: row)
                }
            )
        }
        for column in 0..<grid.columns {
            appendLineStrip(
                to: orthogonal,
                points: (0...grid.rows).map {
                    presentationPoint(grid, column: column, row: $0)
                }
            )
        }
        addShape(path: orthogonal, stroke: color, alpha: alpha, lineWidth: 2)
        let diagonals = diagonalPaths(grid)
        addShape(path: diagonals, stroke: color, alpha: alpha, lineWidth: 1.5)
    }

    private func addTriangularMesh(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let paths = (0..<stretchBucketCount).map { _ in CGMutablePath() }
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let points = cellPoints(grid, column: column, row: row)
                let bucket = stretchBucket(points)
                let path = paths[bucket]
                let p00 = points[0]
                let p10 = points[1]
                let p11 = points[2]
                let p01 = points[3]
                path.move(to: p10)
                path.addLine(to: p11)
                path.addLine(to: p01)
                path.addLine(to: p10)
                path.move(to: p00)
                path.addLine(to: p11)
            }
        }
        for (bucket, path) in paths.enumerated() {
            addShape(
                path: path,
                stroke: color,
                alpha: alpha,
                lineWidth: 1 + bucketIntensity(bucket)
            )
        }
    }

    private func addStretchedEdges(_ grid: GridSimulation) {
        let regular = (0..<stretchBucketCount).map { _ in CGMutablePath() }
        let highlighted = (0..<stretchBucketCount).map { _ in CGMutablePath() }
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let points = cellPoints(grid, column: column, row: row)
                let bucket = stretchBucket(points)
                if column < grid.columns - 1 {
                    let path = (column + 1).isMultiple(of: 4)
                        ? highlighted[bucket] : regular[bucket]
                    path.move(to: points[1])
                    path.addLine(to: points[2])
                }
                if row < grid.rows - 1 {
                    let path = (row + 1).isMultiple(of: 4)
                        ? highlighted[bucket] : regular[bucket]
                    path.move(to: points[2])
                    path.addLine(to: points[3])
                }
            }
        }
        for bucket in 0..<stretchBucketCount {
            let intensity = bucketIntensity(bucket)
            let color = blueStretchColor(intensity)
            let lineWidth = 1 + intensity * 1.5
            addShape(
                path: regular[bucket],
                stroke: color,
                alpha: 0.5,
                lineWidth: lineWidth,
                pixelAlignedStroke: true
            )
            addShape(
                path: highlighted[bucket],
                stroke: color,
                alpha: 1,
                lineWidth: lineWidth,
                pixelAlignedStroke: true
            )
        }
    }

    private func addStretchedCheckerLines(_ grid: GridSimulation, diagonals: Bool) {
        let paths = (0..<stretchBucketCount).map { _ in CGMutablePath() }
        for column in 0..<grid.columns {
            for row in 0..<grid.rows where isAlternatingCell(column, row, rows: grid.rows) {
                let points = cellPoints(grid, column: column, row: row)
                let path = paths[stretchBucket(points)]
                if diagonals {
                    path.move(to: points[0])
                    path.addLine(to: points[2])
                    path.move(to: points[3])
                    path.addLine(to: points[1])
                } else {
                    addClosedPolygon(points, to: path)
                }
            }
        }
        for (bucket, path) in paths.enumerated() {
            let intensity = bucketIntensity(bucket)
            addShape(
                path: path,
                stroke: diagonals ? raspberryStretchColor(intensity) : blueStretchColor(intensity),
                alpha: diagonals ? 0.6 + intensity * 0.2 : 1 - intensity * 0.3,
                lineWidth: 1 + intensity * (diagonals ? 1.5 : 2),
                pixelAlignedStroke: true,
                antialiased: diagonals
            )
        }
    }

    private func addStretchedQuads(_ grid: GridSimulation, alpha: CGFloat) {
        for column in 0..<grid.columns {
            for row in 0..<grid.rows where isAlternatingCell(column, row, rows: grid.rows) {
                let points = cellPoints(grid, column: column, row: row)
                let path = CGMutablePath()
                addClosedPolygon(points, to: path)
                addShape(
                    path: path,
                    fill: blueStretchColor(stretchIntensity(points, spacing: 16)),
                    alpha: alpha
                )
            }
        }
    }

    private func addAlternatingQuads(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        for column in 0..<grid.columns {
            for row in 0..<grid.rows where isAlternatingCell(column, row, rows: grid.rows) {
                let path = CGMutablePath()
                addClosedPolygon(cellPoints(grid, column: column, row: row), to: path)
                addShape(path: path, fill: color, alpha: alpha)
            }
        }
    }

    private func addSineQuads(
        _ grid: GridSimulation,
        color: SKColor,
        cyclingColor: SKColor,
        alpha: CGFloat
    ) {
        var sequence = 0
        var columnSequence = 0
        var cyclingRed: CGFloat = 0
        var cyclingGreen: CGFloat = 0
        var cyclingBlue: CGFloat = 0
        var cyclingAlpha: CGFloat = 0
        cyclingColor.getRed(
            &cyclingRed,
            green: &cyclingGreen,
            blue: &cyclingBlue,
            alpha: &cyclingAlpha
        )
        let greenPhase = Int((cyclingGreen * 255).rounded())
        for column in 0..<grid.columns {
            columnSequence += 1
            // Source b increases from the top; scene rows therefore descend.
            // Keep each DrawPoly separate so overlapping quads add repeatedly.
            for row in stride(from: grid.rows - 1, through: 0, by: -1)
                where isAlternatingCell(column, row, rows: grid.rows) {
                sequence += 2
                let cellAlpha = alpha - 0.25 * (
                    sin(CGFloat(greenPhase + sequence) * .pi / 180)
                        + cos(CGFloat(columnSequence) * .pi / 180)
                )
                let path = CGMutablePath()
                addClosedPolygon(cellPoints(grid, column: column, row: row), to: path)
                addShape(
                    path: path,
                    fill: color,
                    alpha: cellAlpha
                )
            }
        }
    }

    private func addMoireTriangles(_ grid: GridSimulation, alpha: CGFloat) {
        let moirePhase = (CGFloat(max(1, animationFrame)) * 0.05)
            .truncatingRemainder(dividingBy: 360)
        let phase = 36 * sin(moirePhase * .pi / 180)
        let paths = (0..<100).map { _ in CGMutablePath() }
        let divisions = 6
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let points = cellPoints(grid, column: column, row: row)
                let sourceRow = OriginalMoireGridRule.sourceRow(
                    forSceneRow: row,
                    rowCount: grid.rows
                )
                let scale = 0.5 + 0.25
                    * sin(phase * CGFloat(column * sourceRow) * .pi / 180)
                let vertices = OriginalMoireGridRule.sceneTriangle(
                    cellPoints: points,
                    scale: scale
                )
                func subdividedPoint(_ firstWeight: Int, _ secondWeight: Int) -> CGPoint {
                    let first = CGFloat(firstWeight) / CGFloat(divisions)
                    let second = CGFloat(secondWeight) / CGFloat(divisions)
                    let origin = 1 - first - second
                    return CGPoint(
                        x: vertices[0].x * origin + vertices[1].x * first + vertices[2].x * second,
                        y: vertices[0].y * origin + vertices[1].y * first + vertices[2].y * second
                    )
                }
                func addSubtriangle(_ weights: [(Int, Int)]) {
                    let averageFirst = CGFloat(weights.map(\.0).reduce(0, +))
                        / CGFloat(weights.count * divisions)
                    let averageSecond = CGFloat(weights.map(\.1).reduce(0, +))
                        / CGFloat(weights.count * divisions)
                    let green = 0.3 * (1 - averageSecond)
                    let blue = 0.3 * (1 - averageFirst - averageSecond)
                    let greenBucket = min(9, max(0, Int((green / 0.3 * 9).rounded())))
                    let blueBucket = min(9, max(0, Int((blue / 0.3 * 9).rounded())))
                    addClosedPolygon(
                        weights.map { subdividedPoint($0.0, $0.1) },
                        to: paths[greenBucket * 10 + blueBucket]
                    )
                }
                for first in 0..<divisions {
                    for second in 0..<(divisions - first) {
                        addSubtriangle([(first, second), (first + 1, second), (first, second + 1)])
                        if first + second < divisions - 1 {
                            addSubtriangle([
                                (first + 1, second),
                                (first + 1, second + 1),
                                (first, second + 1),
                            ])
                        }
                    }
                }
            }
        }
        for greenBucket in 0..<10 {
            for blueBucket in 0..<10 {
                addShape(
                    path: paths[greenBucket * 10 + blueBucket],
                    fill: SKColor(
                        red: 0.3,
                        green: 0.3 * CGFloat(greenBucket) / 9,
                        blue: 0.3 * CGFloat(blueBucket) / 9,
                        alpha: 1
                    ),
                    alpha: alpha
                )
            }
        }
    }

    private func addThickStrips(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let path = CGMutablePath()
        guard grid.rows > 1 else { return }
        for row in 1..<grid.rows {
            appendLineStrip(
                to: path,
                points: (0...grid.columns).map {
                    presentationPoint(grid, column: $0, row: row)
                }
            )
        }
        addShape(path: path, stroke: color, alpha: alpha, lineWidth: 16)
    }

    private func addRGBSpiral(_ grid: GridSimulation, alpha: CGFloat) {
        let rgbPhase = (CGFloat(max(1, animationFrame)) * 3)
            .truncatingRemainder(dividingBy: 360)
        let vertices = rgbSpiralVertices(grid)
        let bucketCount = 64
        let red = (0..<bucketCount).map { _ in CGMutablePath() }
        let green = (0..<bucketCount).map { _ in CGMutablePath() }
        let blue = (0..<bucketCount).map { _ in CGMutablePath() }
        var phase = rgbPhase
        for index in 1..<vertices.count {
            phase = (phase + 6).truncatingRemainder(dividingBy: 360)
            let pulse = 0.3 + 0.2 * sin(phase * .pi / 180)
            let bucket = min(
                bucketCount - 1,
                max(0, Int((pulse - 0.1) / 0.4 * CGFloat(bucketCount)))
            )
            let redStart = OriginalRGBSplitRule.redPoint(
                vertices[index - 1].position,
                origin: vertices[index - 1].origin,
                displacementAxis: vertices[index - 1].redDisplacementAxis
            )
            let redEnd = OriginalRGBSplitRule.redPoint(
                vertices[index].position,
                origin: vertices[index].origin,
                displacementAxis: vertices[index].redDisplacementAxis
            )
            appendSegment(to: red[bucket], from: redStart, to: redEnd)
            appendSegment(
                to: green[bucket],
                from: vertices[index - 1].position,
                to: vertices[index].position
            )
            appendSegment(
                to: blue[bucket],
                from: vertices[index - 1].origin,
                to: vertices[index].origin
            )
        }
        for bucket in 0..<bucketCount {
            let pulse = 0.1 + CGFloat(bucket) / CGFloat(bucketCount - 1) * 0.4
            addShape(
                path: red[bucket],
                stroke: SKColor(red: pulse, green: 0.05, blue: 0.05, alpha: 1),
                alpha: alpha,
                lineWidth: 2
            )
            addShape(
                path: green[bucket],
                stroke: SKColor(red: 0.05, green: pulse, blue: 0.05, alpha: 1),
                alpha: alpha,
                lineWidth: 2
            )
            addShape(
                path: blue[bucket],
                stroke: SKColor(red: 0.05, green: 0.05, blue: pulse, alpha: 1),
                alpha: alpha,
                lineWidth: 2
            )
        }
    }

    private func diagonalPaths(_ grid: GridSimulation) -> CGPath {
        let path = CGMutablePath()
        for startColumn in 0...grid.columns {
            var points: [CGPoint] = []
            var column = startColumn
            var row = 0
            while column <= grid.columns, row <= grid.rows {
                points.append(presentationPoint(grid, column: column, row: row))
                column += 1
                row += 1
            }
            appendLineStrip(to: path, points: points)
        }
        if grid.rows > 0 {
            for startRow in 1...grid.rows {
                var points: [CGPoint] = []
                var column = 0
                var row = startRow
                while column <= grid.columns, row <= grid.rows {
                    points.append(presentationPoint(grid, column: column, row: row))
                    column += 1
                    row += 1
                }
                appendLineStrip(to: path, points: points)
            }
        }
        for startColumn in 0...grid.columns {
            var points: [CGPoint] = []
            var column = startColumn
            var row = 0
            while column >= 0, row <= grid.rows {
                points.append(presentationPoint(grid, column: column, row: row))
                column -= 1
                row += 1
            }
            appendLineStrip(to: path, points: points)
        }
        if grid.rows > 0 {
            for startRow in 1...grid.rows {
                var points: [CGPoint] = []
                var column = grid.columns
                var row = startRow
                while column >= 0, row <= grid.rows {
                    points.append(presentationPoint(grid, column: column, row: row))
                    column -= 1
                    row += 1
                }
                appendLineStrip(to: path, points: points)
            }
        }
        return path
    }

    private func rgbSpiralVertices(_ grid: GridSimulation) -> [RGBSpiralVertex] {
        var result: [RGBSpiralVertex] = []
        var left = 1
        var right = max(1, grid.columns - 1)
        var bottom = 1
        var top = max(1, grid.rows - 1)
        func append(
            column: Int,
            row: Int,
            axis: OriginalRGBSplitRule.DisplacementAxis
        ) {
            let point = grid[column, row]
            result.append(RGBSpiralVertex(
                position: point.presentationPosition(
                    interpolationAlpha: presentationInterpolationAlpha
                ),
                origin: point.origin,
                redDisplacementAxis: axis
            ))
        }
        while left <= right, bottom < top {
            for column in left...right {
                append(column: column, row: top, axis: .horizontal)
            }
            top -= 1
            for row in stride(from: top, through: bottom, by: -1) {
                append(column: right, row: row, axis: .vertical)
            }
            for column in stride(from: right, through: left, by: -1) {
                append(column: column, row: bottom, axis: .horizontal)
            }
            right -= 1
            bottom += 1
            if bottom <= top {
                for row in bottom...top {
                    append(column: left, row: row, axis: .vertical)
                }
            }
            left += 1
        }
        if left <= right, bottom <= top {
            for column in left...right {
                append(column: column, row: top, axis: .horizontal)
            }
        }
        return result
    }

    private func cellPoints(
        _ grid: GridSimulation,
        column: Int,
        row: Int
    ) -> [CGPoint] {
        [
            presentationPoint(grid, column: column, row: row),
            presentationPoint(grid, column: column + 1, row: row),
            presentationPoint(grid, column: column + 1, row: row + 1),
            presentationPoint(grid, column: column, row: row + 1),
        ]
    }

    private func presentationPoint(
        _ grid: GridSimulation,
        column: Int,
        row: Int
    ) -> CGPoint {
        grid[column, row].presentationPosition(
            interpolationAlpha: presentationInterpolationAlpha
        )
    }

    private func stretchIntensity(_ points: [CGPoint], spacing: CGFloat) -> CGFloat {
        guard points.count == 4 else { return 0 }
        let delta = max(
            points[2].x - points[0].x - spacing,
            points[2].y - points[0].y - spacing
        )
        let degrees = min(90, max(0, delta))
        return sin(degrees * .pi / 180)
    }

    private func stretchBucket(_ points: [CGPoint]) -> Int {
        min(
            stretchBucketCount - 1,
            max(0, Int(stretchIntensity(points, spacing: 16) * CGFloat(stretchBucketCount)))
        )
    }

    private func bucketIntensity(_ bucket: Int) -> CGFloat {
        CGFloat(bucket) / CGFloat(stretchBucketCount - 1)
    }

    private func blueStretchColor(_ intensity: CGFloat) -> SKColor {
        SKColor(
            red: (20 + 235 * intensity) / 255,
            green: (20 + 100 * intensity) / 255,
            blue: (180 - 140 * intensity) / 255,
            alpha: 1
        )
    }

    private func raspberryStretchColor(_ intensity: CGFloat) -> SKColor {
        SKColor(
            red: (128 + 127 * intensity) / 255,
            green: (15 + 105 * intensity) / 255,
            blue: (63 - 23 * intensity) / 255,
            alpha: 1
        )
    }

    private func isAlternatingCell(_ column: Int, _ row: Int, rows: Int) -> Bool {
        ((rows - 1 - row) - column).isMultiple(of: 2)
    }

    private func addClosedPolygon(_ points: [CGPoint], to path: CGMutablePath) {
        guard let first = points.first else { return }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
    }

    private func appendLineStrip(to path: CGMutablePath, points: [CGPoint]) {
        guard let first = points.first else { return }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
    }

    private func appendSegment(to path: CGMutablePath, from start: CGPoint, to end: CGPoint) {
        path.move(to: start)
        path.addLine(to: end)
    }

    private func addShape(
        path: CGPath,
        stroke: SKColor = .clear,
        fill: SKColor = .clear,
        alpha: CGFloat,
        lineWidth: CGFloat = 1,
        glowWidth: CGFloat = 0,
        pixelAlignedStroke: Bool = false,
        antialiased: Bool = true
    ) {
        guard !path.isEmpty else { return }
        let shape = reusableShapeNode()
        shape.path = path
        shape.strokeColor = stroke
        shape.fillColor = fill
        shape.alpha = max(0, min(1, alpha))
        shape.lineWidth = lineWidth
        shape.glowWidth = glowWidth
        shape.isAntialiased = antialiased
        shape.blendMode = .add
        shape.position = pixelAlignedStroke
            ? OriginalLineRasterRule.scenePixelCenter(.zero)
            : .zero
    }

    private func reusableShapeNode() -> SKShapeNode {
        if reusableNodeIndex < reusableNodes.count,
           let shape = reusableNodes[reusableNodeIndex] as? SKShapeNode {
            reusableNodeIndex += 1
            shape.isHidden = false
            return shape
        }

        let shape = SKShapeNode()
        insertReusableNode(shape)
        return shape
    }

    private func reusableSpriteNode() -> SKSpriteNode {
        if reusableNodeIndex < reusableNodes.count,
           let sprite = reusableNodes[reusableNodeIndex] as? SKSpriteNode {
            reusableNodeIndex += 1
            sprite.isHidden = false
            return sprite
        }

        let sprite = SKSpriteNode()
        insertReusableNode(sprite)
        return sprite
    }

    private func insertReusableNode(_ child: SKNode) {
        if reusableNodeIndex < reusableNodes.count {
            // A style's node type/order is stable. This only handles a changed
            // grid topology defensively without leaking the previous node's
            // SpriteKit render state into the new slot.
            let replaced = reusableNodes.remove(at: reusableNodeIndex)
            replaced.removeFromParent()
        }
        reusableNodes.insert(child, at: reusableNodeIndex)
        node.insertChild(child, at: reusableNodeIndex)
        reusableNodeIndex += 1
        child.isHidden = false
    }
}
