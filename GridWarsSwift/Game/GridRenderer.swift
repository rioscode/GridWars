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
    let node = SKNode()

    private var animationFrame = 0
    private lazy var particleImage = OriginalGraphics.cgImage(named: "particle", setIndex: 0)

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
        opacity: CGFloat
    ) {
        node.removeAllChildren()
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
            addDenseMesh(simulation, color: solidColor, alpha: alpha)
        case .denseMeshBlue:
            addTriangularMesh(
                simulation,
                color: SKColor(red: 0.005, green: 0.05, blue: 0.3, alpha: 1),
                alpha: alpha
            )
        case .stretchedOriginal:
            addStretchedEdges(simulation)
        case .stretchedGrid:
            addStretchedCheckerLines(simulation, diagonals: false)
        case .stretchedDiagonal:
            addStretchedCheckerLines(simulation, diagonals: true)
        case .rgbSplit:
            addRGBSpiral(simulation, alpha: alpha)
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
            addMoireTriangles(simulation, alpha: alpha)
        case .thickStrips:
            addThickStrips(simulation, color: solidColor, alpha: alpha)
        case .none:
            break
        }
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

        let base = CGMutablePath()
        let columnHighlights = CGMutablePath()
        let rowHighlights = CGMutablePath()
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let point = grid[column, row].position
                base.addRect(OriginalDrawRectRule.sceneRect(at: point, width: 2, height: 2))
                if column.isMultiple(of: 4) {
                    columnHighlights.addRect(
                        OriginalDrawRectRule.sceneRect(at: point, width: 3, height: 3)
                    )
                }
                if row.isMultiple(of: 4) {
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
                let point = grid[column, row].position
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
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = .zero
        sprite.position = .zero
        sprite.size = grid.arenaSize
        sprite.blendMode = .add
        node.addChild(sprite)
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
                    grid[column, $0].position
                }
            )
        }
        for row in stride(from: 4, to: grid.rows, by: 4) {
            appendLineStrip(
                to: path,
                points: stride(from: 0, through: grid.columns, by: 4).map {
                    grid[$0, row].position
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
                points: (0...grid.rows).map { grid[column, $0].position }
            )
        }
        for row in 0..<grid.rows {
            appendLineStrip(
                to: row.isMultiple(of: 4) ? highlight : regular,
                points: (0...grid.columns).map { grid[$0, row].position }
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
                points: (0...grid.columns).map { grid[$0, row].position }
            )
        }
        for column in 0..<grid.columns {
            appendLineStrip(
                to: orthogonal,
                points: (0...grid.rows).map { grid[column, $0].position }
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
        let paths = (0..<16).map { _ in CGMutablePath() }
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
        let regular = (0..<16).map { _ in CGMutablePath() }
        let highlighted = (0..<16).map { _ in CGMutablePath() }
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
        for bucket in 0..<16 {
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
        let paths = (0..<16).map { _ in CGMutablePath() }
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
                pixelAlignedStroke: true
            )
        }
    }

    private func addStretchedQuads(_ grid: GridSimulation, alpha: CGFloat) {
        let paths = (0..<128).map { _ in CGMutablePath() }
        for column in 0..<grid.columns {
            for row in 0..<grid.rows where isAlternatingCell(column, row, rows: grid.rows) {
                let points = cellPoints(grid, column: column, row: row)
                let bucket = stretchBucket(points)
                addClosedPolygon(points, to: paths[bucket * 8 + overlapGroup(column, row)])
            }
        }
        for bucket in 0..<16 {
            let color = blueStretchColor(bucketIntensity(bucket))
            for group in 0..<8 {
                addShape(path: paths[bucket * 8 + group], fill: color, alpha: alpha)
            }
        }
    }

    private func addAlternatingQuads(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let paths = (0..<8).map { _ in CGMutablePath() }
        for column in 0..<grid.columns {
            for row in 0..<grid.rows where isAlternatingCell(column, row, rows: grid.rows) {
                addClosedPolygon(
                    cellPoints(grid, column: column, row: row),
                    to: paths[overlapGroup(column, row)]
                )
            }
        }
        for path in paths {
            addShape(path: path, fill: color, alpha: alpha)
        }
    }

    private func addSineQuads(
        _ grid: GridSimulation,
        color: SKColor,
        cyclingColor: SKColor,
        alpha: CGFloat
    ) {
        let paths = (0..<128).map { _ in CGMutablePath() }
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
            for row in 0..<grid.rows where isAlternatingCell(column, row, rows: grid.rows) {
                sequence += 2
                let cellAlpha = alpha - 0.25 * (
                    sin(CGFloat(greenPhase + sequence) * .pi / 180)
                        + cos(CGFloat(columnSequence) * .pi / 180)
                )
                let bucket = min(15, max(0, Int(max(0, min(1, cellAlpha)) * 15.999)))
                addClosedPolygon(
                    cellPoints(grid, column: column, row: row),
                    to: paths[bucket * 8 + overlapGroup(column, row)]
                )
            }
        }
        for bucket in 0..<16 {
            for group in 0..<8 {
                addShape(
                    path: paths[bucket * 8 + group],
                    fill: color,
                    alpha: CGFloat(bucket) / 15
                )
            }
        }
    }

    private func addMoireTriangles(_ grid: GridSimulation, alpha: CGFloat) {
        let moirePhase = (CGFloat(max(1, animationFrame)) * 0.05)
            .truncatingRemainder(dividingBy: 360)
        let phase = 36 * sin(moirePhase * .pi / 180)
        let paths = (0..<100).map { _ in CGMutablePath() }
        let divisions = 3
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let points = cellPoints(grid, column: column, row: row)
                let scale = 0.5 + 0.25 * sin(phase * CGFloat(column * row) * .pi / 180)
                let top = CGPoint(
                    x: points[1].x,
                    y: points[2].y + (points[1].y - points[2].y) * scale
                )
                let side = CGPoint(
                    x: points[2].x + (points[3].x - points[2].x) * scale,
                    y: points[3].y
                )
                let vertices = [top, points[2], side]
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
            appendLineStrip(to: path, points: (0...grid.columns).map { grid[$0, row].position })
        }
        addShape(path: path, stroke: color, alpha: alpha, lineWidth: 16)
    }

    private func addRGBSpiral(_ grid: GridSimulation, alpha: CGFloat) {
        let rgbPhase = (CGFloat(max(1, animationFrame)) * 3)
            .truncatingRemainder(dividingBy: 360)
        let deformed = spiralPoints(grid, useOrigins: false)
        let original = spiralPoints(grid, useOrigins: true)
        let red = (0..<16).map { _ in CGMutablePath() }
        let green = (0..<16).map { _ in CGMutablePath() }
        let blue = (0..<16).map { _ in CGMutablePath() }
        var phase = rgbPhase
        for index in 1..<min(deformed.count, original.count) {
            phase = (phase + 6).truncatingRemainder(dividingBy: 360)
            let pulse = 0.3 + 0.2 * sin(phase * .pi / 180)
            let bucket = min(15, max(0, Int((pulse - 0.1) / 0.4 * 15.999)))
            let redStart = rgbRedPoint(deformed[index - 1], origin: original[index - 1])
            let redEnd = rgbRedPoint(deformed[index], origin: original[index])
            appendSegment(to: red[bucket], from: redStart, to: redEnd)
            appendSegment(to: green[bucket], from: deformed[index - 1], to: deformed[index])
            appendSegment(to: blue[bucket], from: original[index - 1], to: original[index])
        }
        for bucket in 0..<16 {
            let pulse = 0.1 + CGFloat(bucket) / 15 * 0.4
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
                points.append(grid[column, row].position)
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
                    points.append(grid[column, row].position)
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
                points.append(grid[column, row].position)
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
                    points.append(grid[column, row].position)
                    column -= 1
                    row += 1
                }
                appendLineStrip(to: path, points: points)
            }
        }
        return path
    }

    private func spiralPoints(_ grid: GridSimulation, useOrigins: Bool) -> [CGPoint] {
        var result: [CGPoint] = []
        var left = 1
        var right = max(1, grid.columns - 1)
        var bottom = 1
        var top = max(1, grid.rows - 1)
        while left <= right, bottom <= top {
            for column in left...right { result.append(point(grid, column, bottom, useOrigins)) }
            bottom += 1
            guard bottom <= top else { break }
            for row in bottom...top { result.append(point(grid, right, row, useOrigins)) }
            right -= 1
            guard left <= right else { break }
            for column in stride(from: right, through: left, by: -1) {
                result.append(point(grid, column, top, useOrigins))
            }
            top -= 1
            guard bottom <= top else { break }
            for row in stride(from: top, through: bottom, by: -1) {
                result.append(point(grid, left, row, useOrigins))
            }
            left += 1
        }
        return result
    }

    private func point(
        _ grid: GridSimulation,
        _ column: Int,
        _ row: Int,
        _ useOrigin: Bool
    ) -> CGPoint {
        useOrigin ? grid[column, row].origin : grid[column, row].position
    }

    private func cellPoints(
        _ grid: GridSimulation,
        column: Int,
        row: Int
    ) -> [CGPoint] {
        [
            grid[column, row].position,
            grid[column + 1, row].position,
            grid[column + 1, row + 1].position,
            grid[column, row + 1].position,
        ]
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
        min(15, max(0, Int(stretchIntensity(points, spacing: 16) * 15.999)))
    }

    private func bucketIntensity(_ bucket: Int) -> CGFloat {
        CGFloat(bucket) / 15
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

    private func overlapGroup(_ column: Int, _ row: Int) -> Int {
        (column % 4) * 2 + (row % 4) / 2
    }

    private func isAlternatingCell(_ column: Int, _ row: Int, rows: Int) -> Bool {
        ((rows - 1 - row) - column).isMultiple(of: 2)
    }

    private func rgbRedPoint(_ point: CGPoint, origin: CGPoint) -> CGPoint {
        guard abs(point.x - origin.x) > 1 || abs(point.y - origin.y) > 1 else {
            return point
        }
        return CGPoint(x: point.x - 4, y: point.y - 4)
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
        pixelAlignedStroke: Bool = false
    ) {
        let shape = SKShapeNode(path: path)
        shape.strokeColor = stroke
        shape.fillColor = fill
        shape.alpha = max(0, min(1, alpha))
        shape.lineWidth = lineWidth
        shape.glowWidth = glowWidth
        shape.blendMode = .add
        if pixelAlignedStroke {
            shape.position = OriginalLineRasterRule.scenePixelCenter(.zero)
        }
        node.addChild(shape)
    }
}
