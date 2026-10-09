import CoreGraphics
import Foundation

struct GridPointState: Equatable {
    let origin: CGPoint
    var position: CGPoint
    var previousPosition: CGPoint
    var velocity = CGVector.zero

    init(
        origin: CGPoint,
        position: CGPoint,
        velocity: CGVector = .zero,
        previousPosition: CGPoint? = nil
    ) {
        self.origin = origin
        self.position = position
        self.previousPosition = previousPosition ?? position
        self.velocity = velocity
    }

    func presentationPosition(interpolationAlpha: CGFloat) -> CGPoint {
        OriginalPresentationRule.interpolate(
            from: previousPosition,
            to: position,
            alpha: interpolationAlpha
        )
    }
}

struct GridSimulation: Equatable {
    let arenaSize: CGSize
    let spacing: CGFloat
    let columns: Int
    let rows: Int

    private(set) var points: [GridPointState]

    init(arenaSize: CGSize, spacing: CGFloat = 16) {
        precondition(spacing > 0)
        self.arenaSize = arenaSize
        self.spacing = spacing
        columns = Int(arenaSize.width / spacing)
        rows = Int(arenaSize.height / spacing)
        points = []
        points.reserveCapacity((columns + 1) * (rows + 1))
        for column in 0...columns {
            for row in 0...rows {
                let origin = CGPoint(x: CGFloat(column) * spacing, y: CGFloat(row) * spacing)
                points.append(GridPointState(origin: origin, position: origin))
            }
        }
    }

    private init(
        arenaSize: CGSize,
        spacing: CGFloat,
        columns: Int,
        rows: Int,
        points: [GridPointState]
    ) {
        self.arenaSize = arenaSize
        self.spacing = spacing
        self.columns = columns
        self.rows = rows
        self.points = points
    }

    func renderWindow(
        canvasSize: CGSize,
        columns requestedColumns: Int,
        rows requestedRows: Int,
        offset: CGPoint
    ) -> GridSimulation {
        let visibleColumns = min(columns, max(0, requestedColumns))
        let visibleRows = min(rows, max(0, requestedRows))
        var visiblePoints: [GridPointState] = []
        visiblePoints.reserveCapacity((visibleColumns + 1) * (visibleRows + 1))
        for column in 0...visibleColumns {
            for row in 0...visibleRows {
                let source = self[column, row]
                visiblePoints.append(GridPointState(
                    origin: CGPoint(
                        x: source.origin.x + offset.x,
                        y: source.origin.y + offset.y
                    ),
                    position: CGPoint(
                        x: source.position.x + offset.x,
                        y: source.position.y + offset.y
                    ),
                    velocity: source.velocity,
                    previousPosition: CGPoint(
                        x: source.previousPosition.x + offset.x,
                        y: source.previousPosition.y + offset.y
                    )
                ))
            }
        }
        return GridSimulation(
            arenaSize: canvasSize,
            spacing: spacing,
            columns: visibleColumns,
            rows: visibleRows,
            points: visiblePoints
        )
    }

    subscript(column: Int, row: Int) -> GridPointState {
        points[index(column: column, row: row)]
    }

    /// Flattened storage offset for a lattice coordinate. Renderers use this to
    /// walk `points` directly instead of copying a whole `GridPointState`.
    func pointIndex(column: Int, row: Int) -> Int {
        index(column: column, row: row)
    }

    /// Display-space position of one stored point without copying its velocity
    /// or origin alongside it.
    func interpolatedPosition(at index: Int, interpolationAlpha: CGFloat) -> CGPoint {
        points[index].presentationPosition(interpolationAlpha: interpolationAlpha)
    }

    mutating func reset() {
        for index in points.indices {
            points[index].position = points[index].origin
            points[index].previousPosition = points[index].origin
            points[index].velocity = .zero
        }
    }

    mutating func beginPresentationStep() {
        for index in points.indices {
            points[index].previousPosition = points[index].position
        }
    }

    mutating func update() {
        guard columns > 1, rows > 1 else { return }
        for column in 1..<columns {
            // BlitzMax rows grow down from the top of the screen. SpriteKit's
            // world y-axis grows upward, so descending here preserves the
            // original visible in-place update order.
            for row in stride(from: rows - 1, through: 1, by: -1) {
                let neighborX = (
                    self[column - 1, row].position.x
                        + self[column, row - 1].position.x
                        + self[column, row + 1].position.x
                        + self[column + 1, row].position.x
                ) / 4
                let neighborY = (
                    self[column - 1, row].position.y
                        + self[column, row - 1].position.y
                        + self[column, row + 1].position.y
                        + self[column + 1, row].position.y
                ) / 4
                updatePoint(column: column, row: row, neighbor: CGPoint(x: neighborX, y: neighborY))
            }
        }
    }

    mutating func pull(at center: CGPoint, radiusInPoints: Int = 4, amount: CGFloat = 4) {
        let centerColumn = Int(center.x / spacing)
        let centerRow = Int(center.y / spacing)
        for columnOffset in -radiusInPoints...radiusInPoints {
            for rowOffset in -radiusInPoints...radiusInPoints {
                let column = centerColumn + columnOffset
                let row = centerRow + rowOffset
                guard isInteriorOrFarEdge(column: column, row: row),
                      columnOffset * columnOffset + rowOffset * rowOffset
                        < radiusInPoints * radiusInPoints else { continue }
                let difference = CGVector(
                    dx: self[column, row].position.x - center.x,
                    dy: self[column, row].position.y - center.y
                )
                let distance = difference.length
                guard distance > 0 else { continue }
                points[index(column: column, row: row)].velocity =
                    self[column, row].velocity - difference / distance * amount
            }
        }
    }

    mutating func push(at center: CGPoint, radiusInPoints: Int = 4, amount: CGFloat = 1) {
        let centerColumn = Int(center.x / spacing)
        let centerRow = Int(center.y / spacing)
        // The source visits the whole square neighbourhood and then rejects every
        // point whose origin is 50 or more scene units from the centre. Clamping
        // the loops to the intersection of the square and that open disc visits
        // the identical set of points, in the identical order, while skipping the
        // rejected corners.
        guard let columnRange = pushedColumnRange(center: center.x, centerIndex: centerColumn, radiusInPoints: radiusInPoints, lastIndex: columns),
              let rowRange = pushedColumnRange(center: center.y, centerIndex: centerRow, radiusInPoints: radiusInPoints, lastIndex: rows) else {
            return
        }
        let stride = rows + 1
        for column in columnRange {
            let rowBase = column * stride
            for row in rowRange {
                let pointIndex = rowBase + row
                let point = points[pointIndex]
                let fromCenter = CGVector(
                    dx: point.origin.x - center.x,
                    dy: point.origin.y - center.y
                )
                let centerDistanceSquared = fromCenter.dx * fromCenter.dx
                    + fromCenter.dy * fromCenter.dy
                let fromCurrent = CGVector(
                    dx: point.origin.x - point.position.x,
                    dy: point.origin.y - point.position.y
                )
                let displacementSquared = fromCurrent.dx * fromCurrent.dx
                    + fromCurrent.dy * fromCurrent.dy
                guard centerDistanceSquared > 1,
                      displacementSquared < 400,
                      centerDistanceSquared < 50 * 50 else { continue }
                points[pointIndex].velocity = point.velocity + fromCenter * amount
            }
        }
    }

    /// Integer lattice indices whose origin lies within the push reach of one
    /// axis, intersected with the source square neighbourhood and the arena.
    /// Returns `nil` when the intersection is empty.
    private func pushedColumnRange(
        center: CGFloat,
        centerIndex: Int,
        radiusInPoints: Int,
        lastIndex: Int
    ) -> ClosedRange<Int>? {
        let reach: CGFloat = 50
        var low = max(1, centerIndex - radiusInPoints)
        var high = min(lastIndex, centerIndex + radiusInPoints)
        low = max(low, Int(floor((center - reach) / spacing)) + 1)
        high = min(high, Int(ceil((center + reach) / spacing)) - 1)
        guard low <= high else { return nil }
        return low...high
    }

    mutating func shockwave(at center: CGPoint) {
        let centerColumn = Int(center.x / spacing)
        let centerRow = Int(center.y / spacing)
        for columnOffset in -3...3 {
            for rowOffset in -3...3 {
                guard columnOffset * columnOffset + rowOffset * rowOffset < 10 else { continue }
                let column = centerColumn + columnOffset
                let row = centerRow + rowOffset
                guard isInteriorOrFarEdge(column: column, row: row) else { continue }
                let point = self[column, row]
                disrupt(
                    column: column,
                    row: row,
                    impulse: CGVector(
                        dx: 4 * (point.position.x - center.x),
                        dy: 4 * (point.position.y - center.y)
                    )
                )
            }
        }
    }

    mutating func bombShockwave(at center: CGPoint) {
        for column in 1...columns {
            for row in 1...rows {
                let point = self[column, row]
                disrupt(
                    column: column,
                    row: row,
                    impulse: CGVector(
                        dx: 0.6 * (point.position.x - center.x),
                        dy: 0.6 * (point.position.y - center.y)
                    )
                )
            }
        }
    }

    private func index(column: Int, row: Int) -> Int {
        column * (rows + 1) + row
    }

    private func isInteriorOrFarEdge(column: Int, row: Int) -> Bool {
        column > 0 && column <= columns && row > 0 && row <= rows
    }

    private mutating func updatePoint(column: Int, row: Int, neighbor: CGPoint) {
        let pointIndex = index(column: column, row: row)
        var point = points[pointIndex]

        if abs(neighbor.x - point.position.x) > 2 {
            point.velocity.dx += sign(neighbor.x - point.position.x)
        }
        if abs(neighbor.y - point.position.y) > 2 {
            point.velocity.dy += sign(neighbor.y - point.position.y)
        }

        if abs(point.origin.x - point.position.x) > 1 {
            point.position.x += sign(point.origin.x - point.position.x)
            point.velocity.dx += sign(point.origin.x - point.position.x) / 2
        } else {
            point.position.x = point.origin.x
        }
        if abs(point.origin.y - point.position.y) > 1 {
            point.position.y += sign(point.origin.y - point.position.y)
            point.velocity.dy += sign(point.origin.y - point.position.y) / 2
        } else {
            point.position.y = point.origin.y
        }

        point.velocity = point.velocity * 0.899
        point.position.x += point.velocity.dx
        point.position.y += point.velocity.dy
        points[pointIndex] = point
    }

    private mutating func disrupt(column: Int, row: Int, impulse: CGVector) {
        var adjusted = impulse
        if abs(adjusted.dx) > 8 { adjusted.dx /= 16 }
        if abs(adjusted.dy) > 8 { adjusted.dy /= 16 }

        let pointIndex = index(column: column, row: row)
        points[pointIndex].velocity = points[pointIndex].velocity + adjusted
        let speedSquared = points[pointIndex].velocity.dx * points[pointIndex].velocity.dx
            + points[pointIndex].velocity.dy * points[pointIndex].velocity.dy
        if speedSquared > 160 {
            points[pointIndex].velocity = points[pointIndex].velocity / speedSquared * 128
        }
    }

    private func sign(_ value: CGFloat) -> CGFloat {
        if value < 0 { return -1 }
        if value > 0 { return 1 }
        return 0
    }
}

/// Source-ordered rectangle plan for the point Grid styles.
///
/// The original draws three additive passes in a fixed order: every base
/// point, then every fourth non-zero column, then every fourth non-zero row.
/// The plan stores the resulting lattice offsets once per topology so a
/// renderer can replay the passes without recomputing the loop bounds and the
/// `isMultiple(of: 4)` predicates for every displayed frame.
struct GridPointQuadPlan: Equatable {
    struct Quad: Equatable {
        /// Offset into `GridSimulation.points`.
        let pointIndex: Int
        /// Square side length in scene points.
        let side: CGFloat
    }

    let columns: Int
    let rows: Int
    let quads: [Quad]

    var rectangleCount: Int { quads.count }

    init(grid: GridSimulation) {
        self.init(columns: grid.columns, rows: grid.rows, pointStride: grid.rows + 1)
    }

    init(columns: Int, rows: Int, pointStride: Int) {
        self.columns = columns
        self.rows = rows

        var quads: [Quad] = []
        quads.reserveCapacity((columns + (columns / 4)) * (rows + (rows / 4)))

        for column in 0..<max(0, columns) {
            for row in 0..<max(0, rows) {
                quads.append(Quad(pointIndex: column * pointStride + row, side: 2))
            }
        }
        for column in 1..<max(1, columns) where column.isMultiple(of: 4) {
            for row in 0..<max(0, rows) {
                quads.append(Quad(pointIndex: column * pointStride + row, side: 3))
            }
        }
        for row in 1..<max(1, rows) where row.isMultiple(of: 4) {
            for column in 0..<max(0, columns) {
                quads.append(Quad(pointIndex: column * pointStride + row, side: 3))
            }
        }

        self.quads = quads
    }
}
