@preconcurrency import SpriteKit
import ImageIO

enum OriginalGraphicsSet: Int, CaseIterable, Sendable, Equatable {
    case solid
    case low
    case medium
    case high
    case user

    init(index: Int) {
        self = OriginalGraphicsSet(rawValue: index) ?? .solid
    }

    var folderName: String {
        switch self {
        case .solid: "solid"
        case .low: "low"
        case .medium: "med"
        case .high: "high"
        case .user: "user"
        }
    }

    var snakeFrameSize: CGSize {
        switch self {
        case .low, .medium: CGSize(width: 32, height: 32)
        case .solid, .high, .user: CGSize(width: 56, height: 56)
        }
    }

    var iconFrameSize: CGSize {
        switch self {
        case .low: CGSize(width: 24, height: 24)
        case .medium: CGSize(width: 32, height: 32)
        case .solid, .high, .user: CGSize(width: 64, height: 64)
        }
    }
}

enum OriginalGraphics {
    static func commonTexture(named name: String) -> SKTexture {
        let texture: SKTexture
        if let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "gfx"
        ), let loadedTexture = loadTexture(contentsOf: url) {
            texture = loadedTexture
        } else {
            texture = SKTexture(imageNamed: name)
        }
        texture.filteringMode = .linear
        return texture
    }

    static func texture(named name: String, setIndex: Int) -> SKTexture {
        let set = OriginalGraphicsSet(index: setIndex)
        let texture: SKTexture
        if let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "gfx/\(set.folderName)"
        ), let loadedTexture = loadTexture(contentsOf: url) {
            texture = loadedTexture
        } else {
            // The top-level High assets remain a compatibility fallback for
            // test hosts and older builds made before all five sets shipped.
            texture = SKTexture(imageNamed: name)
        }
        texture.filteringMode = .linear
        return texture
    }

    private static func loadTexture(contentsOf url: URL) -> SKTexture? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return SKTexture(cgImage: image)
    }

    static func frameTexture(
        sheet name: String,
        frame: Int,
        columns: Int,
        rows: Int,
        setIndex: Int
    ) -> SKTexture {
        let sheet = texture(named: name, setIndex: setIndex)
        let column = frame % columns
        let rowFromTop = frame / columns
        let texture = SKTexture(
            rect: CGRect(
                x: CGFloat(column) / CGFloat(columns),
                y: CGFloat(rows - 1 - rowFromTop) / CGFloat(rows),
                width: 1 / CGFloat(columns),
                height: 1 / CGFloat(rows)
            ),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }

    static func commonFrameTexture(
        sheet name: String,
        frame: Int,
        columns: Int,
        rows: Int
    ) -> SKTexture {
        let sheet = commonTexture(named: name)
        let column = frame % columns
        let rowFromTop = frame / columns
        let texture = SKTexture(
            rect: CGRect(
                x: CGFloat(column) / CGFloat(columns),
                y: CGFloat(rows - 1 - rowFromTop) / CGFloat(rows),
                width: 1 / CGFloat(columns),
                height: 1 / CGFloat(rows)
            ),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }
}
