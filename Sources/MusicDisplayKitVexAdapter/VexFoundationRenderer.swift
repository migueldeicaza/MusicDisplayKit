import MusicDisplayKitCore
import MusicDisplayKitLayout
import MusicDisplayKitModel
import VexFoundation

public enum RenderTarget: Sendable {
    case view(identifier: String)
    case image(width: Int, height: Int)
}

public protocol ScoreRenderer {
    func render(_ score: LaidOutScore, target: RenderTarget) throws
}

public protocol VexRenderContextProvider {
    func makeContext(width: Double, height: Double, target: RenderTarget) -> RenderContext
}

public struct HeadlessRenderContextProvider: VexRenderContextProvider {
    public init() {}

    public func makeContext(width: Double, height: Double, target: RenderTarget) -> RenderContext {
        HeadlessRenderContext(width: width, height: height)
    }
}

private final class HeadlessRenderContext: RenderContext {
    private struct State {
        let fillStyle: String
        let backgroundFillStyle: String
        let strokeStyle: String
        let shadowColor: String
        let shadowBlur: Double
        let lineWidth: Double
        let lineCap: VexLineCap
        let lineDash: [Double]
        let fontInfo: VexFoundation.FontInfo
        let scaleX: Double
        let scaleY: Double
    }

    private var stateStack: [State] = []
    private var backgroundFillStyle: String = "transparent"
    private var shadowColor: String = "transparent"
    private var shadowBlur: Double = 0
    private var lineWidth: Double = 1
    private var lineCap: VexLineCap = .butt
    private var lineDash: [Double] = []
    private var fontInfo: VexFoundation.FontInfo = VexFoundation.FontInfo()
    private var scaleX: Double = 1
    private var scaleY: Double = 1
    private var width: Double
    private var height: Double

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    var fillStyle: String = "#000000"
    var strokeStyle: String = "#000000"

    func clear() {}

    @discardableResult
    func save() -> Self {
        stateStack.append(State(
            fillStyle: fillStyle,
            backgroundFillStyle: backgroundFillStyle,
            strokeStyle: strokeStyle,
            shadowColor: shadowColor,
            shadowBlur: shadowBlur,
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineDash: lineDash,
            fontInfo: fontInfo,
            scaleX: scaleX,
            scaleY: scaleY
        ))
        return self
    }

    @discardableResult
    func restore() -> Self {
        guard let state = stateStack.popLast() else {
            return self
        }
        fillStyle = state.fillStyle
        backgroundFillStyle = state.backgroundFillStyle
        strokeStyle = state.strokeStyle
        shadowColor = state.shadowColor
        shadowBlur = state.shadowBlur
        lineWidth = state.lineWidth
        lineCap = state.lineCap
        lineDash = state.lineDash
        fontInfo = state.fontInfo
        scaleX = state.scaleX
        scaleY = state.scaleY
        return self
    }

    @discardableResult
    func setFillStyle(_ style: String) -> Self {
        fillStyle = style
        return self
    }

    @discardableResult
    func setBackgroundFillStyle(_ style: String) -> Self {
        backgroundFillStyle = style
        return self
    }

    @discardableResult
    func setStrokeStyle(_ style: String) -> Self {
        strokeStyle = style
        return self
    }

    @discardableResult
    func setShadowColor(_ color: String) -> Self {
        shadowColor = color
        return self
    }

    @discardableResult
    func setShadowBlur(_ blur: Double) -> Self {
        shadowBlur = blur
        return self
    }

    @discardableResult
    func setLineWidth(_ width: Double) -> Self {
        lineWidth = width
        return self
    }

    @discardableResult
    func setLineCap(_ capType: VexLineCap) -> Self {
        lineCap = capType
        return self
    }

    @discardableResult
    func setLineDash(_ dashPattern: [Double]) -> Self {
        lineDash = dashPattern
        return self
    }

    @discardableResult
    func scale(_ x: Double, _ y: Double) -> Self {
        scaleX *= x
        scaleY *= y
        return self
    }

    @discardableResult
    func resize(_ width: Double, _ height: Double) -> Self {
        self.width = width
        self.height = height
        return self
    }

    @discardableResult
    func beginPath() -> Self { self }

    @discardableResult
    func moveTo(_ x: Double, _ y: Double) -> Self { self }

    @discardableResult
    func lineTo(_ x: Double, _ y: Double) -> Self { self }

    @discardableResult
    func bezierCurveTo(
        _ cp1x: Double,
        _ cp1y: Double,
        _ cp2x: Double,
        _ cp2y: Double,
        _ x: Double,
        _ y: Double
    ) -> Self { self }

    @discardableResult
    func quadraticCurveTo(
        _ cpx: Double,
        _ cpy: Double,
        _ x: Double,
        _ y: Double
    ) -> Self { self }

    @discardableResult
    func arc(
        _ x: Double,
        _ y: Double,
        _ radius: Double,
        _ startAngle: Double,
        _ endAngle: Double,
        _ counterclockwise: Bool
    ) -> Self { self }

    @discardableResult
    func closePath() -> Self { self }

    @discardableResult
    func fill() -> Self { self }

    @discardableResult
    func stroke() -> Self { self }

    @discardableResult
    func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self { self }

    @discardableResult
    func fillRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self { self }

    @discardableResult
    func clearRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self { self }

    @discardableResult
    func fillText(_ text: String, _ x: Double, _ y: Double) -> Self { self }

    func measureText(_ text: String) -> TextMeasure {
        let fontSize = VexFont.convertSizeToPointValue(fontInfo.size)
        let width = Double(text.count) * max(1, fontSize * 0.55)
        let height = max(1, fontSize)
        return TextMeasure(x: 0, y: -(height * 0.75), width: width, height: height)
    }

    @discardableResult
    func setFont(
        _ family: String?,
        _ size: Double?,
        _ weight: String?,
        _ style: String?
    ) -> Self {
        fontInfo = VexFont.validate(
            family: family,
            size: size.map { "\($0)pt" },
            weight: weight,
            style: style
        )
        return self
    }

    @discardableResult
    func setFont(_ fontInfo: VexFoundation.FontInfo) -> Self {
        self.fontInfo = VexFont.validate(fontInfo: fontInfo)
        return self
    }

    func getFont() -> String {
        VexFont.toCSSString(fontInfo)
    }

    func openGroup(_ cls: String?, _ id: String?) -> Any? { nil }
    func closeGroup() {}
    func add(_ child: Any) {}
}

public enum VexConnectorKind: String, Sendable {
    case singleLeft
    case singleRight
    case brace
    case bracket
}

public struct VexStavePlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let pageIndex: Int
    public let frame: LayoutRect

    public init(systemIndex: Int, partIndex: Int, pageIndex: Int, frame: LayoutRect) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.pageIndex = pageIndex
        self.frame = frame
    }
}

public struct VexMeasurePlan: Sendable {
    public let measureIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let measureNumber: Int
    public let systemIndex: Int
    public let pageIndex: Int
    public let frame: LayoutRect

    public init(
        measureIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        measureNumber: Int,
        systemIndex: Int,
        pageIndex: Int,
        frame: LayoutRect
    ) {
        self.measureIndex = measureIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.measureNumber = measureNumber
        self.systemIndex = systemIndex
        self.pageIndex = pageIndex
        self.frame = frame
    }
}

public struct VexPartGroupConnectorPlan: Sendable {
    public let sourceGroupIndex: Int
    public let pageIndex: Int
    public let startSystemIndex: Int
    public let endSystemIndex: Int
    public let startPartIndex: Int
    public let endPartIndex: Int
    public let kind: VexConnectorKind
    public let renderOrder: Int
    public let style: PartGroupRenderStyle
    public let label: String?
    public let frame: LayoutRect

    public init(
        sourceGroupIndex: Int,
        pageIndex: Int,
        startSystemIndex: Int,
        endSystemIndex: Int,
        startPartIndex: Int,
        endPartIndex: Int,
        kind: VexConnectorKind,
        renderOrder: Int,
        style: PartGroupRenderStyle,
        label: String?,
        frame: LayoutRect
    ) {
        self.sourceGroupIndex = sourceGroupIndex
        self.pageIndex = pageIndex
        self.startSystemIndex = startSystemIndex
        self.endSystemIndex = endSystemIndex
        self.startPartIndex = startPartIndex
        self.endPartIndex = endPartIndex
        self.kind = kind
        self.renderOrder = renderOrder
        self.style = style
        self.label = label
        self.frame = frame
    }
}

public struct VexBarlineConnectorPlan: Sendable {
    public let sourceGroupIndex: Int
    public let pageIndex: Int
    public let startSystemIndex: Int
    public let endSystemIndex: Int
    public let startPartIndex: Int
    public let endPartIndex: Int
    public let kind: VexConnectorKind
    public let frame: LayoutRect

    public init(
        sourceGroupIndex: Int,
        pageIndex: Int,
        startSystemIndex: Int,
        endSystemIndex: Int,
        startPartIndex: Int,
        endPartIndex: Int,
        kind: VexConnectorKind,
        frame: LayoutRect
    ) {
        self.sourceGroupIndex = sourceGroupIndex
        self.pageIndex = pageIndex
        self.startSystemIndex = startSystemIndex
        self.endSystemIndex = endSystemIndex
        self.startPartIndex = startPartIndex
        self.endPartIndex = endPartIndex
        self.kind = kind
        self.frame = frame
    }
}

public struct VexRenderPlan: Sendable {
    public let canvasWidth: Double
    public let canvasHeight: Double
    public let pageCount: Int
    public let staves: [VexStavePlan]
    public let measures: [VexMeasurePlan]
    public let partGroupConnectors: [VexPartGroupConnectorPlan]
    public let barlineConnectors: [VexBarlineConnectorPlan]

    public init(
        canvasWidth: Double,
        canvasHeight: Double,
        pageCount: Int,
        staves: [VexStavePlan],
        measures: [VexMeasurePlan],
        partGroupConnectors: [VexPartGroupConnectorPlan],
        barlineConnectors: [VexBarlineConnectorPlan]
    ) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.pageCount = pageCount
        self.staves = staves
        self.measures = measures
        self.partGroupConnectors = partGroupConnectors
        self.barlineConnectors = barlineConnectors
    }
}

public struct VexFactoryExecution {
    public let factory: Factory
    public let staves: [Stave]
    public let partGroupConnectors: [StaveConnector]
    public let barlineConnectors: [StaveConnector]

    public init(
        factory: Factory,
        staves: [Stave],
        partGroupConnectors: [StaveConnector],
        barlineConnectors: [StaveConnector]
    ) {
        self.factory = factory
        self.staves = staves
        self.partGroupConnectors = partGroupConnectors
        self.barlineConnectors = barlineConnectors
    }
}

public struct VexFoundationRenderer: ScoreRenderer {
    public let contextProvider: any VexRenderContextProvider

    public init(contextProvider: any VexRenderContextProvider = HeadlessRenderContextProvider()) {
        self.contextProvider = contextProvider
    }

    public func makeRenderPlan(from score: LaidOutScore, target: RenderTarget) -> VexRenderPlan {
        let staves = score.systems.map { system in
            VexStavePlan(
                systemIndex: system.systemIndex,
                partIndex: system.partIndex,
                pageIndex: system.pageIndex,
                frame: system.frame
            )
        }

        let measures = score.measures.map { measure in
            VexMeasurePlan(
                measureIndex: measure.index,
                partIndex: measure.partIndex,
                measureIndexInPart: measure.measureIndexInPart,
                measureNumber: measure.measureNumber,
                systemIndex: measure.systemIndex,
                pageIndex: measure.pageIndex,
                frame: measure.frame
            )
        }

        let partGroupConnectors = score.partGroups
            .sorted { lhs, rhs in
                if lhs.pageIndex != rhs.pageIndex {
                    return lhs.pageIndex < rhs.pageIndex
                }
                if lhs.renderOrder != rhs.renderOrder {
                    return lhs.renderOrder < rhs.renderOrder
                }
                return lhs.sourceGroupIndex < rhs.sourceGroupIndex
            }
            .map { group in
                VexPartGroupConnectorPlan(
                    sourceGroupIndex: group.sourceGroupIndex,
                    pageIndex: group.pageIndex,
                    startSystemIndex: group.startSystemIndex,
                    endSystemIndex: group.endSystemIndex,
                    startPartIndex: group.startPartIndex,
                    endPartIndex: group.endPartIndex,
                    kind: partGroupConnectorKind(for: group.symbol),
                    renderOrder: group.renderOrder,
                    style: group.renderStyle,
                    label: group.name,
                    frame: group.frame
                )
            }

        let barlineConnectors = score.barlineConnectors
            .sorted { lhs, rhs in
                if lhs.pageIndex != rhs.pageIndex {
                    return lhs.pageIndex < rhs.pageIndex
                }
                if lhs.sourceGroupIndex != rhs.sourceGroupIndex {
                    return lhs.sourceGroupIndex < rhs.sourceGroupIndex
                }
                return lhs.side == .left && rhs.side == .right
            }
            .map { connector in
                VexBarlineConnectorPlan(
                    sourceGroupIndex: connector.sourceGroupIndex,
                    pageIndex: connector.pageIndex,
                    startSystemIndex: connector.startSystemIndex,
                    endSystemIndex: connector.endSystemIndex,
                    startPartIndex: connector.startPartIndex,
                    endPartIndex: connector.endPartIndex,
                    kind: connector.side == .left ? .singleLeft : .singleRight,
                    frame: connector.frame
                )
            }

        let pageCount = computedPageCount(for: score)
        let canvasWidth: Double
        let canvasHeight: Double
        switch target {
        case .image(let width, let height):
            canvasWidth = Double(width)
            canvasHeight = Double(height)
        case .view:
            canvasWidth = score.pageWidth
            if let pageHeight = score.pageHeight {
                canvasHeight = pageHeight * Double(pageCount)
            } else {
                canvasHeight = computedContentHeight(for: score)
            }
        }

        return VexRenderPlan(
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            pageCount: pageCount,
            staves: staves,
            measures: measures,
            partGroupConnectors: partGroupConnectors,
            barlineConnectors: barlineConnectors
        )
    }

    public func executeRenderPlan(_ plan: VexRenderPlan) -> VexFactoryExecution {
        let factory = Factory(
            options: FactoryOptions(width: plan.canvasWidth, height: plan.canvasHeight)
        )

        let createdStaves = plan.staves
            .sorted { $0.systemIndex < $1.systemIndex }
            .map { stavePlan in
                factory.Stave(
                    x: stavePlan.frame.x,
                    y: stavePlan.frame.y,
                    width: stavePlan.frame.width
                )
            }

        let stavesBySystemIndex = Dictionary(
            uniqueKeysWithValues: zip(
                plan.staves.sorted { $0.systemIndex < $1.systemIndex }.map(\.systemIndex),
                createdStaves
            )
        )

        let partGroupConnectors: [StaveConnector] = plan.partGroupConnectors.compactMap { connectorPlan in
            guard let topStave = stavesBySystemIndex[connectorPlan.startSystemIndex],
                  let bottomStave = stavesBySystemIndex[connectorPlan.endSystemIndex] else {
                return nil
            }

            let connector = factory.StaveConnector(
                topStave: topStave,
                bottomStave: bottomStave,
                type: connectorType(for: connectorPlan.kind)
            )
            connector.connectorWidth = connectorPlan.frame.width
            connector.thickness = connectorPlan.style.strokeWidth
            _ = connector.setXShift(
                connectorXShift(
                    targetX: connectorPlan.frame.x,
                    topStave: topStave,
                    kind: connectorPlan.kind
                )
            )
            if let label = connectorPlan.label, !label.isEmpty {
                _ = connector.setText(label)
            }
            return connector
        }

        let barlineConnectors: [StaveConnector] = plan.barlineConnectors.compactMap { connectorPlan in
            guard let topStave = stavesBySystemIndex[connectorPlan.startSystemIndex],
                  let bottomStave = stavesBySystemIndex[connectorPlan.endSystemIndex] else {
                return nil
            }

            let connector = factory.StaveConnector(
                topStave: topStave,
                bottomStave: bottomStave,
                type: connectorType(for: connectorPlan.kind)
            )
            connector.connectorWidth = connectorPlan.frame.width
            connector.thickness = 1
            _ = connector.setXShift(
                connectorXShift(
                    targetX: connectorPlan.frame.x,
                    topStave: topStave,
                    kind: connectorPlan.kind
                )
            )
            return connector
        }

        return VexFactoryExecution(
            factory: factory,
            staves: createdStaves,
            partGroupConnectors: partGroupConnectors,
            barlineConnectors: barlineConnectors
        )
    }

    public func render(_ score: LaidOutScore, target: RenderTarget) throws {
        let plan = makeRenderPlan(from: score, target: target)
        let execution = executeRenderPlan(plan)
        let context = contextProvider.makeContext(
            width: plan.canvasWidth,
            height: plan.canvasHeight,
            target: target
        )
        _ = execution.factory.setContext(context)
        try execution.factory.draw()
    }

    private func partGroupConnectorKind(for symbol: PartGroupSymbol?) -> VexConnectorKind {
        switch symbol {
        case .brace:
            return .brace
        case .bracket, .square:
            return .bracket
        case .line, .unknown, .none:
            return .singleLeft
        }
    }

    private func computedPageCount(for score: LaidOutScore) -> Int {
        let maxPage = max(
            score.systems.map(\.pageIndex).max() ?? 0,
            score.measures.map(\.pageIndex).max() ?? 0,
            score.partGroups.map(\.pageIndex).max() ?? 0,
            score.barlineConnectors.map(\.pageIndex).max() ?? 0
        )
        return max(1, maxPage + 1)
    }

    private func computedContentHeight(for score: LaidOutScore) -> Double {
        let maxSystemY = score.systems.map { $0.frame.y + $0.frame.height }.max() ?? 0
        let maxGroupY = score.partGroups.map { $0.frame.y + $0.frame.height }.max() ?? 0
        let maxConnectorY = score.barlineConnectors.map { $0.frame.y + $0.frame.height }.max() ?? 0
        let maxY = max(maxSystemY, maxGroupY, maxConnectorY)
        return max(200, maxY + 40)
    }

    private func connectorType(for kind: VexConnectorKind) -> ConnectorType {
        switch kind {
        case .singleLeft:
            return .singleLeft
        case .singleRight:
            return .singleRight
        case .brace:
            return .brace
        case .bracket:
            return .bracket
        }
    }

    private func connectorXShift(targetX: Double, topStave: Stave, kind: VexConnectorKind) -> Double {
        switch kind {
        case .singleRight:
            return targetX - (topStave.getX() + topStave.getWidth())
        case .singleLeft, .brace, .bracket:
            return targetX - topStave.getX()
        }
    }
}

#if DEBUG && canImport(SwiftUI)
import SwiftUI

private struct SwiftUICanvasRenderContextProvider: VexRenderContextProvider {
    let context: SwiftUICanvasContext

    func makeContext(width: Double, height: Double, target: RenderTarget) -> RenderContext {
        _ = context.resize(width, height)
        return context
    }
}

private struct VexFoundationRendererPreviewView: View {
    var body: some View {
        VexCanvas(width: 560, height: 240) { ctx in
            ctx.clear()

            let score = makePreviewScore()
            do {
                let laidOut = try MusicLayoutEngine().layout(
                    score: score,
                    options: LayoutOptions(
                        pageWidth: 540,
                        pageHeight: 240,
                        pageMargin: 24,
                        systemSpacing: 16,
                        partSpacing: 36
                    )
                )
                let renderer = VexFoundationRenderer(
                    contextProvider: SwiftUICanvasRenderContextProvider(context: ctx)
                )
                try renderer.render(laidOut, target: .view(identifier: "preview"))
            } catch {
                ctx.setFillStyle("#B00020")
                ctx.setFont("Menlo", 12, "normal", "normal")
                ctx.fillText("Preview render failed: \(error)", 12, 20)
            }
        }
        .padding(12)
        .background(Color(white: 0.96))
    }

    private func makePreviewScore() -> Score {
        let attributes = MeasureAttributes(time: TimeSignature(beats: 4, beatType: 4))

        return Score(
            title: "Renderer Preview",
            parts: [
                Part(
                    id: "P1",
                    name: "Piano RH",
                    measures: [
                        Measure(number: 1, attributes: attributes),
                    ]
                ),
                Part(
                    id: "P2",
                    name: "Piano LH",
                    measures: [
                        Measure(number: 1, attributes: attributes),
                    ]
                ),
            ],
            partGroups: [
                PartGroup(
                    number: 1,
                    startPartID: "P1",
                    endPartID: "P2",
                    symbol: .bracket,
                    barline: true,
                    name: "Piano"
                ),
                PartGroup(
                    number: 2,
                    startPartID: "P1",
                    endPartID: "P2",
                    symbol: .brace,
                    barline: nil,
                    name: nil
                ),
            ]
        )
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("VexFoundationRenderer", traits: .sizeThatFitsLayout) {
    VexFoundationRendererPreviewView()
}
#endif
