import Foundation
import MusicDisplayKitCore
import MusicDisplayKitModel

public struct LayoutOptions: Sendable {
    public var pageWidth: Double
    public var pageHeight: Double?
    public var pageMargin: Double
    public var systemSpacing: Double
    public var partSpacing: Double
    public var staffHeight: Double
    public var measureGap: Double
    public var measureMinWidth: Double
    public var durationWidthScale: Double
    public var defaultMeasureDurationUnits: Double
    public var partGroupGap: Double
    public var partGroupWidth: Double
    public var partGroupBraceWidth: Double
    public var partGroupBracketWidth: Double
    public var partGroupLineWidth: Double
    public var partGroupSquareWidth: Double
    public var partGroupNestingOffset: Double
    public var partGroupStrokeWidth: Double
    public var partGroupBraceStrokeWidth: Double
    public var partGroupBracketHookLength: Double
    public var partGroupSquareCornerRadius: Double

    /// When non-nil, only the parts at these indices are rendered.
    /// All other parts are hidden from layout and rendering.
    public var visiblePartIndices: IndexSet?

    /// When non-nil, only measures in this range are rendered.
    /// Measure indices are 0-based and refer to position in the part's measure array.
    public var measureRange: Range<Int>?

    /// Zoom scale factor (1.0 = 100%). Applies uniformly to the entire output.
    public var zoom: Double

    /// When true, uses VexFoundation's automatic beaming instead of MusicXML beam markers.
    public var autoBeam: Bool

    /// Engraving rules controlling spacing, collision avoidance, and visibility.
    public var engravingRules: EngravingRules

    public init(
        pageWidth: Double = 1200,
        pageHeight: Double? = nil,
        pageMargin: Double = 40,
        systemSpacing: Double = 28,
        partSpacing: Double = 48,
        staffHeight: Double = 72,
        measureGap: Double = 12,
        measureMinWidth: Double = 72,
        durationWidthScale: Double = 44,
        defaultMeasureDurationUnits: Double = 4,
        partGroupGap: Double = 8,
        partGroupWidth: Double = 8,
        partGroupBraceWidth: Double = 12,
        partGroupBracketWidth: Double = 10,
        partGroupLineWidth: Double = 2,
        partGroupSquareWidth: Double = 10,
        partGroupNestingOffset: Double = 4,
        partGroupStrokeWidth: Double = 1.4,
        partGroupBraceStrokeWidth: Double = 1.8,
        partGroupBracketHookLength: Double = 8,
        partGroupSquareCornerRadius: Double = 1.5,
        visiblePartIndices: IndexSet? = nil,
        measureRange: Range<Int>? = nil,
        zoom: Double = 1.0,
        autoBeam: Bool = false,
        engravingRules: EngravingRules = .default
    ) {
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.pageMargin = pageMargin
        self.systemSpacing = systemSpacing
        self.partSpacing = partSpacing
        self.staffHeight = staffHeight
        self.measureGap = measureGap
        self.measureMinWidth = measureMinWidth
        self.durationWidthScale = durationWidthScale
        self.defaultMeasureDurationUnits = defaultMeasureDurationUnits
        self.partGroupGap = partGroupGap
        self.partGroupWidth = partGroupWidth
        self.partGroupBraceWidth = partGroupBraceWidth
        self.partGroupBracketWidth = partGroupBracketWidth
        self.partGroupLineWidth = partGroupLineWidth
        self.partGroupSquareWidth = partGroupSquareWidth
        self.partGroupNestingOffset = partGroupNestingOffset
        self.partGroupStrokeWidth = partGroupStrokeWidth
        self.partGroupBraceStrokeWidth = partGroupBraceStrokeWidth
        self.partGroupBracketHookLength = partGroupBracketHookLength
        self.partGroupSquareCornerRadius = partGroupSquareCornerRadius
        self.visiblePartIndices = visiblePartIndices
        self.measureRange = measureRange
        self.zoom = zoom
        self.autoBeam = autoBeam
        self.engravingRules = engravingRules
    }

    /// Returns a copy of these options with values overridden by MusicXML `<defaults>`.
    public func applying(defaults: ScoreDefaults) -> LayoutOptions {
        var options = self
        let convert: (Double) -> Double? = defaults.tenthsToPixels
        if let pageWidth = defaults.pageWidth.flatMap(convert) {
            options.pageWidth = pageWidth
        }
        if let pageHeight = defaults.pageHeight.flatMap(convert) {
            options.pageHeight = pageHeight
        }
        if let margin = defaults.pageMarginLeft.flatMap(convert) {
            options.pageMargin = margin
        }
        if let systemDistance = defaults.systemDistance.flatMap(convert) {
            options.systemSpacing = systemDistance
        }
        if let staffDistance = defaults.staffDistance.flatMap(convert) {
            options.partSpacing = staffDistance
        }
        return options
    }

    /// Default layout preset — balanced spacing for general-purpose rendering.
    public static var `default`: LayoutOptions { LayoutOptions() }

    /// Compact preset — tighter spacing for dense scores or smaller displays.
    public static var compact: LayoutOptions {
        LayoutOptions(
            systemSpacing: 16,
            partSpacing: 32,
            staffHeight: 60,
            measureGap: 8,
            measureMinWidth: 56,
            durationWidthScale: 32,
            partGroupGap: 4
        )
    }

    /// Leadsheet preset — generous spacing for lead sheets and simple arrangements.
    public static var leadsheet: LayoutOptions {
        LayoutOptions(
            pageWidth: 1200,
            systemSpacing: 40,
            partSpacing: 56,
            staffHeight: 80,
            measureGap: 16,
            measureMinWidth: 96,
            durationWidthScale: 52
        )
    }
}

public struct LaidOutScore: Sendable {
    public let score: Score
    public let pageWidth: Double
    public let pageHeight: Double?
    public let autoBeam: Bool
    public let systems: [LaidOutSystem]
    public let measures: [LaidOutMeasure]
    public let partGroups: [LaidOutPartGroup]
    public let barlineConnectors: [LaidOutBarlineConnector]

    public init(
        score: Score,
        pageWidth: Double,
        pageHeight: Double?,
        autoBeam: Bool = false,
        systems: [LaidOutSystem],
        measures: [LaidOutMeasure],
        partGroups: [LaidOutPartGroup],
        barlineConnectors: [LaidOutBarlineConnector]
    ) {
        self.score = score
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.autoBeam = autoBeam
        self.systems = systems
        self.measures = measures
        self.partGroups = partGroups
        self.barlineConnectors = barlineConnectors
    }
}

public struct LayoutRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct LaidOutSystem: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let pageIndex: Int
    public let frame: LayoutRect
    public var measureIndices: [Int]

    public init(
        systemIndex: Int,
        partIndex: Int,
        pageIndex: Int,
        frame: LayoutRect,
        measureIndices: [Int]
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.pageIndex = pageIndex
        self.frame = frame
        self.measureIndices = measureIndices
    }
}

public struct LaidOutMeasure: Sendable {
    public let index: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let measureNumber: Int
    public let systemIndex: Int
    public let pageIndex: Int
    public let frame: LayoutRect

    public init(
        index: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        measureNumber: Int,
        systemIndex: Int,
        pageIndex: Int,
        frame: LayoutRect
    ) {
        self.index = index
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.measureNumber = measureNumber
        self.systemIndex = systemIndex
        self.pageIndex = pageIndex
        self.frame = frame
    }
}

public struct LaidOutPartGroup: Sendable {
    public let sourceGroupIndex: Int
    public let number: Int?
    public let symbol: PartGroupSymbol?
    public let name: String?
    public let barline: Bool?
    public let startPartIndex: Int
    public let endPartIndex: Int
    public let startSystemIndex: Int
    public let endSystemIndex: Int
    public let pageIndex: Int
    public let nestingLevel: Int
    public let renderOrder: Int
    public let renderStyle: PartGroupRenderStyle
    public let frame: LayoutRect

    public init(
        sourceGroupIndex: Int,
        number: Int?,
        symbol: PartGroupSymbol?,
        name: String?,
        barline: Bool?,
        startPartIndex: Int,
        endPartIndex: Int,
        startSystemIndex: Int,
        endSystemIndex: Int,
        pageIndex: Int,
        nestingLevel: Int,
        renderOrder: Int,
        renderStyle: PartGroupRenderStyle,
        frame: LayoutRect
    ) {
        self.sourceGroupIndex = sourceGroupIndex
        self.number = number
        self.symbol = symbol
        self.name = name
        self.barline = barline
        self.startPartIndex = startPartIndex
        self.endPartIndex = endPartIndex
        self.startSystemIndex = startSystemIndex
        self.endSystemIndex = endSystemIndex
        self.pageIndex = pageIndex
        self.nestingLevel = nestingLevel
        self.renderOrder = renderOrder
        self.renderStyle = renderStyle
        self.frame = frame
    }
}

public struct PartGroupRenderStyle: Sendable {
    public let strokeWidth: Double
    public let hookLength: Double
    public let cornerRadius: Double
    public let curvature: Double
    public let isClosed: Bool

    public init(
        strokeWidth: Double,
        hookLength: Double,
        cornerRadius: Double,
        curvature: Double,
        isClosed: Bool
    ) {
        self.strokeWidth = strokeWidth
        self.hookLength = hookLength
        self.cornerRadius = cornerRadius
        self.curvature = curvature
        self.isClosed = isClosed
    }
}

public enum BarlineConnectorSide: Equatable, Sendable {
    case left
    case right
}

public struct LaidOutBarlineConnector: Sendable {
    public let sourceGroupIndex: Int
    public let pageIndex: Int
    public let side: BarlineConnectorSide
    public let startPartIndex: Int
    public let endPartIndex: Int
    public let startSystemIndex: Int
    public let endSystemIndex: Int
    public let frame: LayoutRect

    public init(
        sourceGroupIndex: Int,
        pageIndex: Int,
        side: BarlineConnectorSide,
        startPartIndex: Int,
        endPartIndex: Int,
        startSystemIndex: Int,
        endSystemIndex: Int,
        frame: LayoutRect
    ) {
        self.sourceGroupIndex = sourceGroupIndex
        self.pageIndex = pageIndex
        self.side = side
        self.startPartIndex = startPartIndex
        self.endPartIndex = endPartIndex
        self.startSystemIndex = startSystemIndex
        self.endSystemIndex = endSystemIndex
        self.frame = frame
    }
}

public protocol ScoreLayoutEngine {
    func layout(score: Score, options: LayoutOptions) throws -> LaidOutScore
}

public struct MusicLayoutEngine: ScoreLayoutEngine {
    public init() {}

    public func layout(score: Score, options: LayoutOptions) throws -> LaidOutScore {
        let options = score.defaults.map { options.applying(defaults: $0) } ?? options
        let zoom = max(0.1, options.zoom)

        // Determine which part indices are visible.
        let visibleParts: [(index: Int, part: Part)]
        if let visibleIndices = options.visiblePartIndices {
            visibleParts = score.parts.enumerated().compactMap { index, part in
                visibleIndices.contains(index) ? (index, part) : nil
            }
        } else {
            visibleParts = score.parts.enumerated().map { ($0, $1) }
        }

        guard !visibleParts.isEmpty else {
            return LaidOutScore(
                score: score,
                pageWidth: options.pageWidth * zoom,
                pageHeight: options.pageHeight.map { $0 * zoom },
                autoBeam: options.autoBeam,
                systems: [],
                measures: [],
                partGroups: [],
                barlineConnectors: []
            )
        }

        let usableWidth = max(1, (options.pageWidth - (options.pageMargin * 2)) * zoom)
        let maxSystemBottom = options.pageHeight.map { ($0 - options.pageMargin) * zoom }

        let partMeasureWidths: [[Double]] = visibleParts.map { _, part in
            measuredWidths(for: part, usableWidth: usableWidth, options: options, zoom: zoom)
        }
        let maxMeasureCount: Int
        let fullMaxMeasureCount = partMeasureWidths.map(\.count).max() ?? 0
        if let measureRange = options.measureRange {
            maxMeasureCount = min(fullMaxMeasureCount, measureRange.upperBound)
        } else {
            maxMeasureCount = fullMaxMeasureCount
        }
        let measureStart = options.measureRange?.lowerBound ?? 0
        guard maxMeasureCount > measureStart else {
            return LaidOutScore(
                score: score,
                pageWidth: options.pageWidth * zoom,
                pageHeight: options.pageHeight.map { $0 * zoom },
                autoBeam: options.autoBeam,
                systems: [],
                measures: [],
                partGroups: [],
                barlineConnectors: []
            )
        }

        let scaledMinWidth = options.measureMinWidth * zoom
        let columnWidths: [Double] = (measureStart..<maxMeasureCount).map { measureIndex in
            let intrinsic = partMeasureWidths.compactMap { widths in
                measureIndex < widths.count ? widths[measureIndex] : nil
            }.max() ?? scaledMinWidth
            return max(scaledMinWidth, intrinsic)
        }
        // Collect system/page break hints from the first visible part's measures.
        let firstVisiblePart = visibleParts[0].part
        let breakHints: [Bool] = (measureStart..<maxMeasureCount).map { measureIndex in
            guard measureIndex < firstVisiblePart.measures.count else { return false }
            return firstVisiblePart.measures[measureIndex].newSystem
                || firstVisiblePart.measures[measureIndex].newPage
        }

        let columnRanges = buildColumnRanges(
            columnWidths: columnWidths,
            usableWidth: usableWidth,
            measureGap: options.measureGap * zoom,
            breakHints: breakHints
        )

        // Pass 2 (3.8): Proportional spacing — redistribute column widths
        // within each system so measures expand to fill the usable width.
        // Only active when noteSpacingMultiplier != 1.0 (opt-in).
        var adjustedColumnWidths = columnWidths
        let spacingMultiplier = options.engravingRules.noteSpacingMultiplier
        if spacingMultiplier != 1.0 {
            for columnRange in columnRanges {
                let scaledGap = options.measureGap * zoom
                let measuresInSystem = columnRange.count
                let totalGap = scaledGap * Double(max(0, measuresInSystem - 1))
                let naturalWidth = columnRange.reduce(0.0) { $0 + adjustedColumnWidths[$1] }
                let availableForContent = usableWidth - totalGap
                guard naturalWidth > 0, availableForContent > 0 else { continue }
                let scale = (availableForContent / naturalWidth) * spacingMultiplier
                for col in columnRange {
                    adjustedColumnWidths[col] = adjustedColumnWidths[col] * scale
                }
            }
        }

        let scaledStaffHeight = options.staffHeight * zoom
        let scaledPartSpacing = options.partSpacing * zoom
        let scaledPageMargin = options.pageMargin * zoom
        let scaledSystemSpacing = options.systemSpacing * zoom
        let rowHeight = (Double(visibleParts.count) * scaledStaffHeight)
            + (Double(max(0, visibleParts.count - 1)) * scaledPartSpacing)

        var systems: [LaidOutSystem] = []
        var measures: [LaidOutMeasure] = []
        var laidOutPartGroups: [LaidOutPartGroup] = []
        var barlineConnectors: [LaidOutBarlineConnector] = []
        var pageIndex = 0
        var rowTopY = scaledPageMargin
        let resolvedPartGroups = resolvePartGroups(score: score)

        for columnRange in columnRanges {
            // Force page break from MusicXML <print new-page="yes">.
            let firstMeasureInRange = columnRange.lowerBound + measureStart
            let hasPageBreakHint = firstMeasureInRange < firstVisiblePart.measures.count
                && firstVisiblePart.measures[firstMeasureInRange].newPage
            if let maxSystemBottom,
               rowTopY > scaledPageMargin,
               (hasPageBreakHint || rowTopY + rowHeight > maxSystemBottom) {
                pageIndex += 1
                rowTopY = scaledPageMargin
            }

            var columnX: [Double] = []
            var currentX = scaledPageMargin
            for column in columnRange {
                columnX.append(currentX)
                currentX += adjustedColumnWidths[column] + options.measureGap * zoom
            }

            let rowSystemIndex = (systems.last?.systemIndex ?? -1) + 1
            var rowSystemArrayIndicesByPartIndex: [Int: Int] = [:]
            for (visibleIndex, visibleEntry) in visibleParts.enumerated() {
                let partIndex = visibleEntry.index
                let part = visibleEntry.part
                let systemArrayIndex = systems.count
                rowSystemArrayIndicesByPartIndex[partIndex] = systemArrayIndex
                let systemY = rowTopY + (Double(visibleIndex) * (scaledStaffHeight + scaledPartSpacing))
                let systemFrame = LayoutRect(
                    x: scaledPageMargin,
                    y: systemY,
                    width: usableWidth,
                    height: scaledStaffHeight
                )

                var systemMeasureIndices: [Int] = []
                for (offset, column) in columnRange.enumerated() {
                    let sourceMeasureIndex = column + measureStart
                    guard sourceMeasureIndex < part.measures.count else {
                        continue
                    }

                    let measure = part.measures[sourceMeasureIndex]
                    let frame = LayoutRect(
                        x: columnX[offset],
                        y: systemY,
                        width: adjustedColumnWidths[column],
                        height: scaledStaffHeight
                    )
                    let laidOutMeasure = LaidOutMeasure(
                        index: measures.count,
                        partIndex: partIndex,
                        measureIndexInPart: sourceMeasureIndex,
                        measureNumber: measure.number,
                        systemIndex: rowSystemIndex,
                        pageIndex: pageIndex,
                        frame: frame
                    )
                    measures.append(laidOutMeasure)
                    systemMeasureIndices.append(laidOutMeasure.index)
                }

                systems.append(
                    LaidOutSystem(
                        systemIndex: rowSystemIndex,
                        partIndex: partIndex,
                        pageIndex: pageIndex,
                        frame: systemFrame,
                        measureIndices: systemMeasureIndices
                    )
                )
            }

            // Use zoomed options for part group geometry.
            var zoomedOptions = options
            zoomedOptions.pageMargin = scaledPageMargin
            zoomedOptions.staffHeight = scaledStaffHeight
            zoomedOptions.partSpacing = scaledPartSpacing
            zoomedOptions.partGroupGap *= zoom
            zoomedOptions.partGroupWidth *= zoom
            zoomedOptions.partGroupBraceWidth *= zoom
            zoomedOptions.partGroupBracketWidth *= zoom
            zoomedOptions.partGroupLineWidth *= zoom
            zoomedOptions.partGroupSquareWidth *= zoom
            zoomedOptions.partGroupNestingOffset *= zoom
            zoomedOptions.partGroupStrokeWidth *= zoom
            zoomedOptions.partGroupBraceStrokeWidth *= zoom
            zoomedOptions.partGroupBracketHookLength *= zoom
            let rowGroups = buildLaidOutPartGroupsForRow(
                resolvedGroups: resolvedPartGroups,
                rowSystemArrayIndicesByPartIndex: rowSystemArrayIndicesByPartIndex,
                systems: systems,
                measures: measures,
                options: zoomedOptions,
                pageIndex: pageIndex
            )
            laidOutPartGroups.append(contentsOf: rowGroups.groups)
            barlineConnectors.append(contentsOf: rowGroups.connectors)

            rowTopY += rowHeight + scaledSystemSpacing
        }

        return LaidOutScore(
            score: score,
            pageWidth: options.pageWidth * zoom,
            pageHeight: options.pageHeight.map { $0 * zoom },
            autoBeam: options.autoBeam,
            systems: systems,
            measures: measures,
            partGroups: laidOutPartGroups,
            barlineConnectors: barlineConnectors
        )
    }

    private struct ResolvedPartGroup {
        let sourceGroupIndex: Int
        let group: PartGroup
        let startPartIndex: Int
        let endPartIndex: Int
        let nestingLevel: Int
    }

    private func measuredWidths(
        for part: Part,
        usableWidth: Double,
        options: LayoutOptions,
        zoom: Double = 1.0
    ) -> [Double] {
        var widths: [Double] = []
        var effectiveDivisions: Int?
        var effectiveTime: TimeSignature?

        for measure in part.measures {
            if let divisions = measure.divisions, divisions > 0 {
                effectiveDivisions = divisions
            }
            if let time = measure.attributes?.time {
                effectiveTime = time
            }

            let width = min(
                usableWidth,
                computedMeasureWidth(
                    measure: measure,
                    effectiveDivisions: effectiveDivisions,
                    effectiveTime: effectiveTime,
                    options: options
                ) * zoom
            )
            widths.append(width)
        }

        return widths
    }

    private func resolvePartGroups(score: Score) -> [ResolvedPartGroup] {
        let partIndexByID = Dictionary(
            uniqueKeysWithValues: score.parts.enumerated().map { ($1.id, $0) }
        )

        var resolved: [ResolvedPartGroup] = []
        for (groupIndex, group) in score.partGroups.enumerated() {
            guard let startIndex = partIndexByID[group.startPartID],
                  let endIndex = partIndexByID[group.endPartID] else {
                continue
            }
            let low = min(startIndex, endIndex)
            let high = max(startIndex, endIndex)
            resolved.append(
                ResolvedPartGroup(
                    sourceGroupIndex: groupIndex,
                    group: group,
                    startPartIndex: low,
                    endPartIndex: high,
                    nestingLevel: 0
                )
            )
        }

        for index in resolved.indices {
            var nesting = 0
            for other in resolved where other.sourceGroupIndex != resolved[index].sourceGroupIndex {
                if resolved[index].startPartIndex <= other.startPartIndex,
                   resolved[index].endPartIndex >= other.endPartIndex,
                   (resolved[index].startPartIndex < other.startPartIndex
                    || resolved[index].endPartIndex > other.endPartIndex) {
                    nesting += 1
                }
            }
            for other in resolved where other.sourceGroupIndex != resolved[index].sourceGroupIndex {
                if other.startPartIndex == resolved[index].startPartIndex,
                   other.endPartIndex == resolved[index].endPartIndex,
                   shouldRenderOutsideForSameSpan(resolved[index], other) {
                    nesting += 1
                }
            }

            resolved[index] = ResolvedPartGroup(
                sourceGroupIndex: resolved[index].sourceGroupIndex,
                group: resolved[index].group,
                startPartIndex: resolved[index].startPartIndex,
                endPartIndex: resolved[index].endPartIndex,
                nestingLevel: nesting
            )
        }

        return resolved
    }

    private func shouldRenderOutsideForSameSpan(
        _ lhs: ResolvedPartGroup,
        _ rhs: ResolvedPartGroup
    ) -> Bool {
        let lhsRank = partGroupSymbolPrecedenceRank(lhs.group.symbol)
        let rhsRank = partGroupSymbolPrecedenceRank(rhs.group.symbol)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs.sourceGroupIndex < rhs.sourceGroupIndex
    }

    private func partGroupSymbolPrecedenceRank(_ symbol: PartGroupSymbol?) -> Int {
        switch symbol {
        case .bracket:
            return 0
        case .square:
            return 1
        case .brace:
            return 2
        case .line:
            return 3
        case .unknown, .none:
            return 4
        }
    }

    private func buildLaidOutPartGroupsForRow(
        resolvedGroups: [ResolvedPartGroup],
        rowSystemArrayIndicesByPartIndex: [Int: Int],
        systems: [LaidOutSystem],
        measures: [LaidOutMeasure],
        options: LayoutOptions,
        pageIndex: Int
    ) -> (groups: [LaidOutPartGroup], connectors: [LaidOutBarlineConnector]) {
        guard !resolvedGroups.isEmpty else {
            return ([], [])
        }

        var output: [LaidOutPartGroup] = []
        var connectors: [LaidOutBarlineConnector] = []
        let orderedGroups = resolvedGroups.sorted { lhs, rhs in
            if lhs.nestingLevel != rhs.nestingLevel {
                return lhs.nestingLevel > rhs.nestingLevel
            }
            if lhs.startPartIndex != rhs.startPartIndex {
                return lhs.startPartIndex < rhs.startPartIndex
            }
            if lhs.endPartIndex != rhs.endPartIndex {
                return lhs.endPartIndex > rhs.endPartIndex
            }
            let lhsRank = partGroupSymbolPrecedenceRank(lhs.group.symbol)
            let rhsRank = partGroupSymbolPrecedenceRank(rhs.group.symbol)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.sourceGroupIndex < rhs.sourceGroupIndex
        }

        for (renderOrder, resolved) in orderedGroups.enumerated() {
            guard let startSystemArrayIndex = rowSystemArrayIndicesByPartIndex[resolved.startPartIndex],
                  let endSystemArrayIndex = rowSystemArrayIndicesByPartIndex[resolved.endPartIndex] else {
                continue
            }
            let startSystem = systems[startSystemArrayIndex]
            let endSystem = systems[endSystemArrayIndex]
            let startFrame = startSystem.frame
            let endFrame = endSystem.frame
            let startSystemIndex = startSystem.systemIndex
            let endSystemIndex = endSystem.systemIndex
            let groupWidth = partGroupWidth(for: resolved.group.symbol, options: options)
            let frame = LayoutRect(
                x: options.pageMargin
                    - options.partGroupGap
                    - groupWidth
                    - (Double(resolved.nestingLevel) * (groupWidth + options.partGroupNestingOffset)),
                y: startFrame.y,
                width: groupWidth,
                height: max(
                    options.staffHeight,
                    (endFrame.y + endFrame.height) - startFrame.y
                )
            )

            output.append(
                LaidOutPartGroup(
                    sourceGroupIndex: resolved.sourceGroupIndex,
                    number: resolved.group.number,
                    symbol: resolved.group.symbol,
                    name: resolved.group.name,
                    barline: resolved.group.barline,
                    startPartIndex: resolved.startPartIndex,
                    endPartIndex: resolved.endPartIndex,
                    startSystemIndex: startSystemIndex,
                    endSystemIndex: endSystemIndex,
                    pageIndex: pageIndex,
                    nestingLevel: resolved.nestingLevel,
                    renderOrder: renderOrder,
                    renderStyle: partGroupRenderStyle(for: resolved.group.symbol, options: options),
                    frame: frame
                )
            )

            if resolved.group.barline == true {
                if let leftX = rowMeasureBoundaryX(
                    rowSystemArrayIndicesByPartIndex: rowSystemArrayIndicesByPartIndex,
                    partStartIndex: resolved.startPartIndex,
                    partEndIndex: resolved.endPartIndex,
                    systems: systems,
                    measures: measures,
                    useRightBoundary: false
                ) {
                    connectors.append(
                        LaidOutBarlineConnector(
                            sourceGroupIndex: resolved.sourceGroupIndex,
                            pageIndex: pageIndex,
                            side: .left,
                            startPartIndex: resolved.startPartIndex,
                            endPartIndex: resolved.endPartIndex,
                            startSystemIndex: startSystemIndex,
                            endSystemIndex: endSystemIndex,
                            frame: LayoutRect(
                                x: leftX,
                                y: frame.y,
                                width: 1,
                                height: frame.height
                            )
                        )
                    )
                }

                if let rightX = rowMeasureBoundaryX(
                    rowSystemArrayIndicesByPartIndex: rowSystemArrayIndicesByPartIndex,
                    partStartIndex: resolved.startPartIndex,
                    partEndIndex: resolved.endPartIndex,
                    systems: systems,
                    measures: measures,
                    useRightBoundary: true
                ) {
                    connectors.append(
                        LaidOutBarlineConnector(
                            sourceGroupIndex: resolved.sourceGroupIndex,
                            pageIndex: pageIndex,
                            side: .right,
                            startPartIndex: resolved.startPartIndex,
                            endPartIndex: resolved.endPartIndex,
                            startSystemIndex: startSystemIndex,
                            endSystemIndex: endSystemIndex,
                            frame: LayoutRect(
                                x: rightX,
                                y: frame.y,
                                width: 1,
                                height: frame.height
                            )
                        )
                    )
                }
            }
        }
        return (output, connectors)
    }

    private func partGroupRenderStyle(
        for symbol: PartGroupSymbol?,
        options: LayoutOptions
    ) -> PartGroupRenderStyle {
        switch symbol {
        case .brace:
            return PartGroupRenderStyle(
                strokeWidth: options.partGroupBraceStrokeWidth,
                hookLength: 0,
                cornerRadius: 0,
                curvature: 0.9,
                isClosed: false
            )
        case .bracket:
            return PartGroupRenderStyle(
                strokeWidth: options.partGroupStrokeWidth,
                hookLength: options.partGroupBracketHookLength,
                cornerRadius: 0,
                curvature: 0,
                isClosed: false
            )
        case .square:
            return PartGroupRenderStyle(
                strokeWidth: options.partGroupStrokeWidth,
                hookLength: options.partGroupBracketHookLength,
                cornerRadius: options.partGroupSquareCornerRadius,
                curvature: 0,
                isClosed: true
            )
        case .line:
            return PartGroupRenderStyle(
                strokeWidth: options.partGroupStrokeWidth,
                hookLength: 0,
                cornerRadius: 0,
                curvature: 0,
                isClosed: false
            )
        case .unknown, .none:
            return PartGroupRenderStyle(
                strokeWidth: options.partGroupStrokeWidth,
                hookLength: 0,
                cornerRadius: 0,
                curvature: 0,
                isClosed: false
            )
        }
    }

    private func partGroupWidth(
        for symbol: PartGroupSymbol?,
        options: LayoutOptions
    ) -> Double {
        switch symbol {
        case .brace:
            return options.partGroupBraceWidth
        case .bracket:
            return options.partGroupBracketWidth
        case .line:
            return options.partGroupLineWidth
        case .square:
            return options.partGroupSquareWidth
        case .unknown, .none:
            return options.partGroupWidth
        }
    }

    private func rowMeasureBoundaryX(
        rowSystemArrayIndicesByPartIndex: [Int: Int],
        partStartIndex: Int,
        partEndIndex: Int,
        systems: [LaidOutSystem],
        measures: [LaidOutMeasure],
        useRightBoundary: Bool
    ) -> Double? {
        var values: [Double] = []
        for partIndex in partStartIndex...partEndIndex {
            guard let systemArrayIndex = rowSystemArrayIndicesByPartIndex[partIndex] else {
                continue
            }
            let system = systems[systemArrayIndex]
            for measureIndex in system.measureIndices {
                let frame = measures[measureIndex].frame
                values.append(useRightBoundary ? (frame.x + frame.width) : frame.x)
            }
        }
        return useRightBoundary ? values.max() : values.min()
    }

    private func buildColumnRanges(
        columnWidths: [Double],
        usableWidth: Double,
        measureGap: Double,
        breakHints: [Bool] = []
    ) -> [Range<Int>] {
        guard !columnWidths.isEmpty else {
            return []
        }

        var ranges: [Range<Int>] = []
        var rangeStart = 0
        var accumulatedWidth = columnWidths[0]

        for index in 1..<columnWidths.count {
            // Force a system break if MusicXML has new-system or new-page hint.
            let forceBreak = index < breakHints.count && breakHints[index]
            let proposedWidth = accumulatedWidth + measureGap + columnWidths[index]
            if forceBreak || proposedWidth > usableWidth {
                ranges.append(rangeStart..<index)
                rangeStart = index
                accumulatedWidth = columnWidths[index]
            } else {
                accumulatedWidth = proposedWidth
            }
        }

        ranges.append(rangeStart..<columnWidths.count)
        return ranges
    }

    private func computedMeasureWidth(
        measure: Measure,
        effectiveDivisions: Int?,
        effectiveTime: TimeSignature?,
        options: LayoutOptions
    ) -> Double {
        let durationUnits = inferredDurationUnits(
            measure: measure,
            effectiveDivisions: effectiveDivisions,
            effectiveTime: effectiveTime,
            defaultUnits: options.defaultMeasureDurationUnits
        )
        return max(options.measureMinWidth, durationUnits * options.durationWidthScale)
    }

    private func inferredDurationUnits(
        measure: Measure,
        effectiveDivisions: Int?,
        effectiveTime: TimeSignature?,
        defaultUnits: Double
    ) -> Double {
        let currentTime = measure.attributes?.time ?? effectiveTime
        if let time = currentTime, time.beatType > 0 {
            let units = (Double(time.beats) * 4) / Double(time.beatType)
            if units > 0 {
                return units
            }
        }

        if !measure.noteEvents.isEmpty {
            let maxEndDivisions = measure.noteEvents.reduce(0) { currentMax, note in
                let duration = max(0, note.durationDivisions ?? 0)
                return max(currentMax, note.onsetDivisions + duration)
            }
            if maxEndDivisions > 0 {
                if let effectiveDivisions, effectiveDivisions > 0 {
                    return max(0.25, Double(maxEndDivisions) / Double(effectiveDivisions))
                }
                return Double(maxEndDivisions)
            }
        }

        return max(0.25, defaultUnits)
    }
}
