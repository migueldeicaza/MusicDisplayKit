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

public struct VexFoundationRenderer: ScoreRenderer {
    public init() {}

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

    public func render(_ score: LaidOutScore, target: RenderTarget) throws {
        _ = makeRenderPlan(from: score, target: target)
        throw NotImplementedError("VexFoundation rendering parity")
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
}
