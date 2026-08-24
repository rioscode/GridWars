import Foundation
@preconcurrency import SpriteKit

struct OriginalVectorSegment: Equatable {
    let start: CGPoint
    let end: CGPoint
}

struct OriginalVectorFontData: Equatable {
    let glyphs: [Int: [OriginalVectorSegment]]

    static func parse(_ source: String) -> OriginalVectorFontData {
        guard let marker = source.range(of: "#letterdata") else {
            return OriginalVectorFontData(glyphs: [:])
        }

        var glyphs: [Int: [OriginalVectorSegment]] = [:]
        var ascii = 32
        for rawLine in source[marker.upperBound...].split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("DefData"), ascii <= 127 else { continue }
            let payload = line.dropFirst("DefData".count)
            let values = payload.split(separator: ",").compactMap { field -> CGFloat? in
                let trimmed = field.trimmingCharacters(in: .whitespaces)
                guard let number = Double(trimmed) else { return nil }
                return CGFloat(number)
            }
            guard let first = values.first else { continue }
            let count = max(0, Int(first))
            guard values.count >= 1 + count * 4 else { continue }
            var segments: [OriginalVectorSegment] = []
            segments.reserveCapacity(count)
            for index in 0..<count {
                let offset = 1 + index * 4
                segments.append(OriginalVectorSegment(
                    start: CGPoint(x: values[offset], y: values[offset + 1]),
                    end: CGPoint(x: values[offset + 2], y: values[offset + 3])
                ))
            }
            glyphs[ascii] = segments
            ascii += 1
        }
        return OriginalVectorFontData(glyphs: glyphs)
    }
}

@MainActor
final class OriginalVectorFont {
    private let data: OriginalVectorFontData

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "vectorfont", withExtension: "bmx"),
           let source = try? String(contentsOf: url, encoding: .utf8) {
            data = OriginalVectorFontData.parse(source)
        } else {
            data = OriginalVectorFontData(glyphs: [:])
        }
    }

    func makeNode(
        _ text: String,
        x: CGFloat,
        yFromTop: CGFloat,
        scale: CGFloat,
        arenaHeight: CGFloat,
        color: SKColor,
        lineWidth: CGFloat = 2
    ) -> SKShapeNode {
        let path = CGMutablePath()
        for (index, scalar) in text.unicodeScalars.enumerated() {
            let ascii = Int(scalar.value)
            guard let segments = data.glyphs[ascii] else { continue }
            for segment in segments {
                path.move(to: CGPoint(
                    x: x + (segment.start.x + CGFloat(index) * 5) * scale,
                    y: arenaHeight - yFromTop - segment.start.y * scale
                ))
                path.addLine(to: CGPoint(
                    x: x + (segment.end.x + CGFloat(index) * 5) * scale,
                    y: arenaHeight - yFromTop - segment.end.y * scale
                ))
            }
        }
        let shape = SKShapeNode(path: path)
        shape.strokeColor = color
        shape.fillColor = .clear
        shape.lineWidth = lineWidth
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.blendMode = .add
        return shape
    }
}
