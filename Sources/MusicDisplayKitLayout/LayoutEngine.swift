import MusicDisplayKitCore
import MusicDisplayKitModel

public struct LayoutOptions: Sendable {
    public var pageWidth: Double
    public var pageHeight: Double?

    public init(pageWidth: Double = 1200, pageHeight: Double? = nil) {
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
    }
}

public struct LaidOutScore: Sendable {
    public let score: Score

    public init(score: Score) {
        self.score = score
    }
}

public protocol ScoreLayoutEngine {
    func layout(score: Score, options: LayoutOptions) throws -> LaidOutScore
}

public struct MusicLayoutEngine: ScoreLayoutEngine {
    public init() {}

    public func layout(score: Score, options: LayoutOptions) throws -> LaidOutScore {
        _ = score
        _ = options
        throw NotImplementedError("Engraving/layout parity")
    }
}
