@preconcurrency import SpriteKit
import ImageIO

enum OriginalGraphicsSet: Int, CaseIterable, Sendable, Equatable, Hashable {
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

@MainActor
enum OriginalGraphics {
    private struct TextureKey: Hashable {
        let name: String
        let set: OriginalGraphicsSet
    }

    private struct FrameTextureKey: Hashable {
        let sheet: String
        let frame: Int
        let columns: Int
        let rows: Int
        let set: OriginalGraphicsSet?
    }

    private enum CachedImage {
        case image(CGImage)
        case missing
    }

    private static var commonTextures: [String: SKTexture] = [:]
    private static var textures: [TextureKey: SKTexture] = [:]
    private static var images: [TextureKey: CachedImage] = [:]
    private static var frameTextures: [FrameTextureKey: SKTexture] = [:]

    static func commonTexture(named name: String) -> SKTexture {
        if let cached = commonTextures[name] {
            return cached
        }

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
        commonTextures[name] = texture
        return texture
    }

    static func texture(named name: String, setIndex: Int) -> SKTexture {
        let key = TextureKey(
            name: name,
            set: OriginalGraphicsSet(index: setIndex)
        )
        if let cached = textures[key] {
            return cached
        }

        let texture: SKTexture
        if let image = cgImage(named: name, setIndex: setIndex) {
            texture = SKTexture(cgImage: image)
        } else {
            // The top-level High assets remain a compatibility fallback for
            // test hosts and older builds made before all five sets shipped.
            texture = SKTexture(imageNamed: name)
        }
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }

    static func cgImage(named name: String, setIndex: Int) -> CGImage? {
        let set = OriginalGraphicsSet(index: setIndex)
        let key = TextureKey(name: name, set: set)
        if let cached = images[key] {
            switch cached {
            case let .image(image):
                return image
            case .missing:
                return nil
            }
        }

        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "gfx/\(set.folderName)"
        ), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            images[key] = .missing
            return nil
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            images[key] = .missing
            return nil
        }
        images[key] = .image(image)
        return image
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
        let key = FrameTextureKey(
            sheet: name,
            frame: frame,
            columns: columns,
            rows: rows,
            set: OriginalGraphicsSet(index: setIndex)
        )
        if let cached = frameTextures[key] {
            return cached
        }

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
        frameTextures[key] = texture
        return texture
    }

    static func commonFrameTexture(
        sheet name: String,
        frame: Int,
        columns: Int,
        rows: Int
    ) -> SKTexture {
        let key = FrameTextureKey(
            sheet: name,
            frame: frame,
            columns: columns,
            rows: rows,
            set: nil
        )
        if let cached = frameTextures[key] {
            return cached
        }

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
        frameTextures[key] = texture
        return texture
    }
}
