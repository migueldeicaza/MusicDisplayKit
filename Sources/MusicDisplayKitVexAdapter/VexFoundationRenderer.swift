import MusicDisplayKitCore
import MusicDisplayKitLayout
import VexFoundation

public enum RenderTarget: Sendable {
    case view(identifier: String)
    case image(width: Int, height: Int)
}

public protocol ScoreRenderer {
    func render(_ score: LaidOutScore, target: RenderTarget) throws
}

public struct VexFoundationRenderer: ScoreRenderer {
    public init() {}

    public func render(_ score: LaidOutScore, target: RenderTarget) throws {
        _ = score
        _ = target
        throw NotImplementedError("VexFoundation rendering parity")
    }
}
