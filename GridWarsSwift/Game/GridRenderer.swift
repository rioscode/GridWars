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

    private var moirePhase: CGFloat = 0
    private var rgbPhase: CGFloat = 0

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
            addStretchGrid(simulation, mode: .edges)
        case .stretchedGrid:
            addStretchGrid(simulation, mode: .outlines)
        case .stretchedDiagonal:
            addStretchGrid(simulation, mode: .diagonals)
        case .rgbSplit:
            addRGBSpiral(simulation, alpha: alpha)
        case .solidQuads:
            addAlternatingQuads(simulation, color: solidColor, alpha: alpha)
        case .solidQuadsCycling:
            addAlternatingQuads(simulation, color: cyclingColor, alpha: alpha)
        case .stretchedQuads:
            addStretchGrid(simulation, mode: .filled)
        case .sineQuads:
            addSineQuads(simulation, color: solidColor, alpha: alpha)
        case .moireTriangles:
            addMoireTriangles(simulation, alpha: alpha)
        case .thickStrips:
            addThickStrips(simulation, color: solidColor, alpha: alpha)
        case .none:
            break
        }
    }

    private enum StretchMode {
        case edges
        case outlines
        case diagonals
        case filled
    }

    private func addPointGrid(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat,
        particleStyle: Bool
    ) {
        let regular = CGMutablePath()
        let highlight = CGMutablePath()
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let point = grid[column, row].position
                let isHighlight = column.isMultiple(of: 4) || row.isMultiple(of: 4)
                let side: CGFloat = particleStyle ? (isHighlight ? 6 : 4.5) : (isHighlight ? 3 : 2)
                let rect = CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
                (isHighlight ? highlight : regular).addRect(rect)
            }
        }
        addShape(path: regular, fill: color, alpha: alpha)
        addShape(path: highlight, fill: color, alpha: min(1, alpha + 0.25))
    }

    private func addMajorLines(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let path = CGMutablePath()
        for column in stride(from: 0, through: grid.columns, by: 4) {
            appendLineStrip(to: path, points: (0...grid.rows).map { grid[column, $0].position })
        }
        for row in stride(from: 0, through: grid.rows, by: 4) {
            appendLineStrip(to: path, points: (0...grid.columns).map { grid[$0, row].position })
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
        for column in 0...grid.columns {
            appendLineStrip(
                to: column.isMultiple(of: 4) ? highlight : regular,
                points: (0...grid.rows).map { grid[column, $0].position }
            )
        }
        for row in 0...grid.rows {
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
        addLineGrid(grid, color: color, alpha: alpha)
        let diagonals = diagonalPaths(grid)
        addShape(path: diagonals, stroke: color, alpha: alpha, lineWidth: 1.5)
    }

    private func addTriangularMesh(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let path = CGMutablePath()
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let p00 = grid[column, row].position
                let p10 = grid[column + 1, row].position
                let p11 = grid[column + 1, row + 1].position
                let p01 = grid[column, row + 1].position
                path.move(to: p10)
                path.addLine(to: p11)
                path.addLine(to: p01)
                path.addLine(to: p10)
                path.move(to: p00)
                path.addLine(to: p11)
            }
        }
        addShape(path: path, stroke: color, alpha: alpha, lineWidth: 2)
    }

    private func addStretchGrid(_ grid: GridSimulation, mode: StretchMode) {
        let buckets = (0..<5).map { _ in CGMutablePath() }
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                let points = cellPoints(grid, column: column, row: row)
                let intensity = stretchIntensity(points, spacing: grid.spacing)
                let bucket = min(4, Int(intensity * 4.999))
                switch mode {
                case .edges:
                    buckets[bucket].move(to: points[1])
                    buckets[bucket].addLine(to: points[2])
                    buckets[bucket].move(to: points[2])
                    buckets[bucket].addLine(to: points[3])
                case .outlines:
                    addClosedPolygon(points, to: buckets[bucket])
                case .diagonals:
                    buckets[bucket].move(to: points[0])
                    buckets[bucket].addLine(to: points[2])
                    buckets[bucket].move(to: points[3])
                    buckets[bucket].addLine(to: points[1])
                case .filled:
                    addClosedPolygon(points, to: buckets[bucket])
                }
            }
        }

        for (index, path) in buckets.enumerated() {
            let intensity = CGFloat(index) / 4
            let color: SKColor
            let alpha: CGFloat
            switch mode {
            case .diagonals:
                color = SKColor(
                    red: (128 + 127 * intensity) / 255,
                    green: (15 + 105 * intensity) / 255,
                    blue: (63 - 23 * intensity) / 255,
                    alpha: 1
                )
                alpha = 0.6 + intensity * 0.2
            default:
                color = SKColor(
                    red: (20 + 235 * intensity) / 255,
                    green: (20 + 100 * intensity) / 255,
                    blue: (180 - 140 * intensity) / 255,
                    alpha: 1
                )
                alpha = mode == .outlines ? 0.7 + (1 - intensity) * 0.3 : 0.5
            }
            if mode == .filled {
                addShape(path: path, fill: color, alpha: 0.85)
            } else {
                addShape(path: path, stroke: color, alpha: alpha, lineWidth: 1 + intensity * 2)
            }
        }
    }

    private func addAlternatingQuads(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let path = CGMutablePath()
        for column in 0..<grid.columns {
            for row in 0..<grid.rows where (row - column).isMultiple(of: 2) {
                addClosedPolygon(cellPoints(grid, column: column, row: row), to: path)
            }
        }
        addShape(path: path, fill: color, alpha: alpha)
    }

    private func addSineQuads(
        _ grid: GridSimulation,
        color: SKColor,
        alpha: CGFloat
    ) {
        let buckets = (0..<5).map { _ in CGMutablePath() }
        var sequence = 0
        for column in 0..<grid.columns {
            for row in 0..<grid.rows where (row - column).isMultiple(of: 2) {
                sequence += 2
                let wave = (sin((CGFloat(sequence) + CGFloat(row)) * .pi / 180) + 1) / 2
                let bucket = min(4, Int(wave * 4.999))
                addClosedPolygon(cellPoints(grid, column: column, row: row), to: buckets[bucket])
            }
        }
        for (index, path) in buckets.enumerated() {
            addShape(
                path: path,
                fill: color,
                alpha: max(0, alpha - 0.25 * CGFloat(index) / 4)
            )
        }
    }

    private func addMoireTriangles(_ grid: GridSimulation, alpha: CGFloat) {
        moirePhase = (moirePhase + 0.05).truncatingRemainder(dividingBy: 360)
        let phase = 36 * sin(moirePhase * .pi / 180)
        let colors = [
            SKColor(white: 0.3, alpha: 1),
            SKColor(red: 0.3, green: 0.3, blue: 0, alpha: 1),
            SKColor(red: 0.3, green: 0, blue: 0, alpha: 1),
        ]
        let paths = colors.map { _ in CGMutablePath() }
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
                for index in paths.indices {
                    let triangle = [vertices[index], vertices[(index + 1) % 3], vertices[(index + 2) % 3]]
                    addClosedPolygon(triangle, to: paths[index])
                }
            }
        }
        for index in paths.indices {
            addShape(path: paths[index], fill: colors[index], alpha: alpha / 3)
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
        rgbPhase = (rgbPhase + 3).truncatingRemainder(dividingBy: 360)
        let deformed = spiralPoints(grid, useOrigins: false)
        let original = spiralPoints(grid, useOrigins: true)
        let red = CGMutablePath()
        let green = CGMutablePath()
        let blue = CGMutablePath()
        appendLineStrip(to: red, points: deformed.map { CGPoint(x: $0.x - 4, y: $0.y - 4) })
        appendLineStrip(to: green, points: deformed)
        appendLineStrip(to: blue, points: original.map { CGPoint(x: $0.x - 4, y: $0.y - 4) })
        let pulse = 0.3 + 0.2 * sin(rgbPhase * .pi / 180)
        addShape(path: red, stroke: SKColor(red: pulse, green: 0.05, blue: 0.05, alpha: 1), alpha: alpha, lineWidth: 2)
        addShape(path: green, stroke: SKColor(red: 0.05, green: pulse, blue: 0.05, alpha: 1), alpha: alpha, lineWidth: 2)
        addShape(path: blue, stroke: SKColor(red: 0.05, green: 0.05, blue: pulse, alpha: 1), alpha: alpha, lineWidth: 2)
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

    private func addShape(
        path: CGPath,
        stroke: SKColor = .clear,
        fill: SKColor = .clear,
        alpha: CGFloat,
        lineWidth: CGFloat = 1
    ) {
        let shape = SKShapeNode(path: path)
        shape.strokeColor = stroke
        shape.fillColor = fill
        shape.alpha = max(0, min(1, alpha))
        shape.lineWidth = lineWidth
        shape.glowWidth = lineWidth > 1 ? 0.7 : 0.3
        shape.blendMode = .add
        node.addChild(shape)
    }
}
