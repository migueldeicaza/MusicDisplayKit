#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import Foundation
import ImageIO
import MusicDisplayKitLayout
import VexFoundation

/// Errors from CoreGraphics-based rendering.
public enum VexCGRenderError: Error {
    case contextCreationFailed
    case imageCreationFailed
    case pngEncodingFailed
    case pdfContextCreationFailed
}

/// Headless CoreGraphics-based rendering for PNG export without SwiftUI dependency.
/// Works on macOS 13+ and iOS 16+ without requiring iOS 17/macOS 14.
public struct VexCGContextProvider {
    public let width: Int
    public let height: Int
    public let scale: Double

    private var cgContext: CGContext?

    public init(width: Int, height: Int, scale: Double = 2.0) {
        self.width = width
        self.height = height
        self.scale = max(1, scale)
    }

    /// Creates a bitmap CGContext and wraps it in a headless render context.
    public mutating func makeCGContext() throws -> (RenderContext, CGContext) {
        let scaledWidth = Int(Double(width) * scale)
        let scaledHeight = Int(Double(height) * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: scaledWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw VexCGRenderError.contextCreationFailed
        }

        // Flip coordinate system (CoreGraphics is bottom-up, VexFoundation is top-down).
        ctx.translateBy(x: 0, y: CGFloat(scaledHeight))
        ctx.scaleBy(x: CGFloat(scale), y: CGFloat(-scale))

        // Fill with white background.
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        self.cgContext = ctx

        let renderContext = CGBackedHeadlessRenderContext(width: Double(width), height: Double(height))
        return (renderContext, ctx)
    }

    /// Extracts the rendered image as PNG data.
    public func extractPNGData() throws -> Data {
        guard let ctx = cgContext else {
            throw VexCGRenderError.contextCreationFailed
        }
        guard let image = ctx.makeImage() else {
            throw VexCGRenderError.imageCreationFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.png" as CFString,
            1,
            nil
        ) else {
            throw VexCGRenderError.pngEncodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw VexCGRenderError.pngEncodingFailed
        }
        return data as Data
    }
}

/// Minimal render context for CG-based headless rendering.
private final class CGBackedHeadlessRenderContext: RenderContext {
    private var width: Double
    private var height: Double
    private var currentFont = FontInfo()

    var fillStyle: String = "#000000"
    var strokeStyle: String = "#000000"

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    func clear() {}
    @discardableResult func save() -> Self { self }
    @discardableResult func restore() -> Self { self }
    @discardableResult func setFillStyle(_ style: String) -> Self { fillStyle = style; return self }
    @discardableResult func setBackgroundFillStyle(_ style: String) -> Self { self }
    @discardableResult func setStrokeStyle(_ style: String) -> Self { strokeStyle = style; return self }
    @discardableResult func setShadowColor(_ color: String) -> Self { self }
    @discardableResult func setShadowBlur(_ blur: Double) -> Self { self }
    @discardableResult func setLineWidth(_ width: Double) -> Self { self }
    @discardableResult func setLineCap(_ capType: VexLineCap) -> Self { self }
    @discardableResult func setLineDash(_ dashPattern: [Double]) -> Self { self }
    @discardableResult func scale(_ x: Double, _ y: Double) -> Self { self }
    @discardableResult func resize(_ w: Double, _ h: Double) -> Self { width = w; height = h; return self }
    @discardableResult func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { self }
    @discardableResult func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { self }
    @discardableResult func clearRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { self }
    @discardableResult func beginPath() -> Self { self }
    @discardableResult func moveTo(_ x: Double, _ y: Double) -> Self { self }
    @discardableResult func lineTo(_ x: Double, _ y: Double) -> Self { self }
    @discardableResult func bezierCurveTo(_ cp1x: Double, _ cp1y: Double, _ cp2x: Double, _ cp2y: Double, _ x: Double, _ y: Double) -> Self { self }
    @discardableResult func quadraticCurveTo(_ cpx: Double, _ cpy: Double, _ x: Double, _ y: Double) -> Self { self }
    @discardableResult func arc(_ x: Double, _ y: Double, _ radius: Double, _ startAngle: Double, _ endAngle: Double, _ counterclockwise: Bool) -> Self { self }
    @discardableResult func fill() -> Self { self }
    @discardableResult func stroke() -> Self { self }
    @discardableResult func closePath() -> Self { self }
    func measureText(_ text: String) -> TextMeasure { TextMeasure(x: 0, y: 0, width: Double(text.count) * 7, height: 12) }
    @discardableResult func fillText(_ text: String, _ x: Double, _ y: Double) -> Self { self }
    @discardableResult func setFont(_ family: String?, _ size: Double?, _ weight: String?, _ style: String?) -> Self { self }
    @discardableResult func setFont(_ fontInfo: FontInfo) -> Self { currentFont = fontInfo; return self }
    func getFont() -> String { VexFont.toCSSString(currentFont) }
    func openGroup(_ cls: String?, _ id: String?) -> Any? { nil }
    func closeGroup() {}
    func add(_ child: Any) {}
}

extension VexFoundationRenderer {
    /// Renders the score to PNG data using CoreGraphics (no SwiftUI dependency).
    public func renderPNGDataCG(
        _ score: LaidOutScore,
        scale: Double = 2.0
    ) throws -> Data {
        let plan = makeRenderPlan(from: score, target: .image(width: Int(score.pageWidth), height: 0))
        var provider = VexCGContextProvider(
            width: Int(plan.canvasWidth),
            height: Int(plan.canvasHeight),
            scale: scale
        )

        let (context, _) = try provider.makeCGContext()
        let execution = executeRenderPlan(plan)
        _ = execution.factory.setContext(context)
        try execution.factory.draw()
        for wedge in execution.directionWedges {
            _ = wedge.setContext(context)
            try wedge.draw()
        }

        return try provider.extractPNGData()
    }
}
#endif
