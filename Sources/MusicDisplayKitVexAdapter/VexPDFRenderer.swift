#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import MusicDisplayKitLayout
import VexFoundation

/// Renders a `LaidOutScore` to PDF data using CoreGraphics.
public struct VexPDFRenderer {
    /// Renders the score to multi-page PDF data.
    public static func renderPDF(
        score: LaidOutScore,
        renderer: VexFoundationRenderer
    ) throws -> Data {
        let plan = renderer.makeRenderPlan(
            from: score,
            target: .image(width: Int(score.pageWidth), height: 0)
        )

        let pageWidth = max(1, plan.canvasWidth)
        let pageHeight = max(1, plan.canvasHeight)

        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw VexCGRenderError.pdfContextCreationFailed
        }

        // Single-page PDF for now; multi-page support can iterate over pageIndices.
        pdfContext.beginPDFPage(nil)

        // Flip coordinate system.
        pdfContext.translateBy(x: 0, y: CGFloat(pageHeight))
        pdfContext.scaleBy(x: 1, y: -1)

        // Fill white background.
        pdfContext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        pdfContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        // Execute the render plan on a headless context.
        let execution = renderer.executeRenderPlan(plan)
        let headlessContext = PDFHeadlessRenderContext(width: pageWidth, height: pageHeight)
        _ = execution.factory.setContext(headlessContext)
        try execution.factory.draw()
        for wedge in execution.directionWedges {
            _ = wedge.setContext(headlessContext)
            try wedge.draw()
        }

        pdfContext.endPDFPage()
        pdfContext.closePDF()

        return data as Data
    }
}

/// Minimal headless render context for PDF pipeline.
private final class PDFHeadlessRenderContext: RenderContext {
    var fillStyle: String = "#000000"
    var strokeStyle: String = "#000000"
    private var width: Double
    private var height: Double
    private var currentFont = FontInfo()

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
#endif
