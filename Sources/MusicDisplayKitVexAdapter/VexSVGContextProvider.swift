import MusicDisplayKitLayout
import VexFoundation

/// Render context provider that uses VexFoundation's `SVGRenderContext`
/// for deterministic SVG output.
public final class VexSVGContextProvider: VexRenderContextProvider {
    private let options: SVGRenderOptions

    /// The SVG context created during the last `makeContext` call.
    /// Access after rendering to retrieve the SVG string.
    public private(set) var svgContext: SVGRenderContext?

    public init(options: SVGRenderOptions = SVGRenderOptions()) {
        self.options = options
    }

    public func makeContext(width: Double, height: Double, target: RenderTarget) -> RenderContext {
        let ctx = SVGRenderContext(width: width, height: height, options: options)
        svgContext = ctx
        return ctx
    }
}

extension VexFoundationRenderer {
    /// Renders the score to an SVG string.
    ///
    /// - Parameters:
    ///   - score: The laid-out score to render.
    ///   - options: SVG serialization options.
    /// - Returns: The SVG string.
    public func renderSVG(
        _ score: LaidOutScore,
        options svgOptions: SVGRenderOptions = SVGRenderOptions()
    ) throws -> String {
        let provider = VexSVGContextProvider(options: svgOptions)
        let plan = makeRenderPlan(from: score, target: .image(width: Int(score.pageWidth), height: 0))
        let execution = executeRenderPlan(plan)
        let context = provider.makeContext(
            width: plan.canvasWidth,
            height: plan.canvasHeight,
            target: .image(width: Int(plan.canvasWidth), height: Int(plan.canvasHeight))
        )
        _ = execution.factory.setContext(context)
        try execution.factory.draw()
        for wedge in execution.directionWedges {
            _ = wedge.setContext(context)
            try wedge.draw()
        }

        guard let svgContext = provider.svgContext else {
            return ""
        }
        return svgContext.getSVG()
    }
}
