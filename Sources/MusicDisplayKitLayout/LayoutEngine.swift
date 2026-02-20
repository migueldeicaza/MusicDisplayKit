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
        defaultMeasureDurationUnits: Double = 4
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
    }
}

public struct LaidOutScore: Sendable {
    public let score: Score
    public let pageWidth: Double
    public let pageHeight: Double?
    public let systems: [LaidOutSystem]
    public let measures: [LaidOutMeasure]

    public init(
        score: Score,
        pageWidth: Double,
        pageHeight: Double?,
        systems: [LaidOutSystem],
        measures: [LaidOutMeasure]
    ) {
        self.score = score
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.systems = systems
        self.measures = measures
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

public protocol ScoreLayoutEngine {
    func layout(score: Score, options: LayoutOptions) throws -> LaidOutScore
}

public struct MusicLayoutEngine: ScoreLayoutEngine {
    public init() {}

    public func layout(score: Score, options: LayoutOptions) throws -> LaidOutScore {
        guard !score.parts.isEmpty else {
            return LaidOutScore(
                score: score,
                pageWidth: options.pageWidth,
                pageHeight: options.pageHeight,
                systems: [],
                measures: []
            )
        }

        let usableWidth = max(1, options.pageWidth - (options.pageMargin * 2))
        let maxSystemBottom = options.pageHeight.map { $0 - options.pageMargin }

        let partMeasureWidths: [[Double]] = score.parts.map { part in
            measuredWidths(for: part, usableWidth: usableWidth, options: options)
        }
        let maxMeasureCount = partMeasureWidths.map(\.count).max() ?? 0
        guard maxMeasureCount > 0 else {
            return LaidOutScore(
                score: score,
                pageWidth: options.pageWidth,
                pageHeight: options.pageHeight,
                systems: [],
                measures: []
            )
        }

        let columnWidths: [Double] = (0..<maxMeasureCount).map { measureIndex in
            let intrinsic = partMeasureWidths.compactMap { widths in
                measureIndex < widths.count ? widths[measureIndex] : nil
            }.max() ?? options.measureMinWidth
            return max(options.measureMinWidth, intrinsic)
        }
        let columnRanges = buildColumnRanges(
            columnWidths: columnWidths,
            usableWidth: usableWidth,
            measureGap: options.measureGap
        )

        let rowHeight = (Double(score.parts.count) * options.staffHeight)
            + (Double(max(0, score.parts.count - 1)) * options.partSpacing)

        var systems: [LaidOutSystem] = []
        var measures: [LaidOutMeasure] = []
        var pageIndex = 0
        var rowTopY = options.pageMargin

        for columnRange in columnRanges {
            if let maxSystemBottom,
               rowTopY > options.pageMargin,
               rowTopY + rowHeight > maxSystemBottom {
                pageIndex += 1
                rowTopY = options.pageMargin
            }

            var columnX: [Double] = []
            var currentX = options.pageMargin
            for column in columnRange {
                columnX.append(currentX)
                currentX += columnWidths[column] + options.measureGap
            }

            for (partIndex, part) in score.parts.enumerated() {
                let systemIndex = systems.count
                let systemY = rowTopY + (Double(partIndex) * (options.staffHeight + options.partSpacing))
                let systemFrame = LayoutRect(
                    x: options.pageMargin,
                    y: systemY,
                    width: usableWidth,
                    height: options.staffHeight
                )

                var systemMeasureIndices: [Int] = []
                for (offset, column) in columnRange.enumerated() {
                    guard column < part.measures.count else {
                        continue
                    }

                    let measure = part.measures[column]
                    let frame = LayoutRect(
                        x: columnX[offset],
                        y: systemY,
                        width: columnWidths[column],
                        height: options.staffHeight
                    )
                    let laidOutMeasure = LaidOutMeasure(
                        index: measures.count,
                        partIndex: partIndex,
                        measureIndexInPart: column,
                        measureNumber: measure.number,
                        systemIndex: systemIndex,
                        pageIndex: pageIndex,
                        frame: frame
                    )
                    measures.append(laidOutMeasure)
                    systemMeasureIndices.append(laidOutMeasure.index)
                }

                systems.append(
                    LaidOutSystem(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        pageIndex: pageIndex,
                        frame: systemFrame,
                        measureIndices: systemMeasureIndices
                    )
                )
            }

            rowTopY += rowHeight + options.systemSpacing
        }

        return LaidOutScore(
            score: score,
            pageWidth: options.pageWidth,
            pageHeight: options.pageHeight,
            systems: systems,
            measures: measures
        )
    }

    private func measuredWidths(
        for part: Part,
        usableWidth: Double,
        options: LayoutOptions
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
                )
            )
            widths.append(width)
        }

        return widths
    }

    private func buildColumnRanges(
        columnWidths: [Double],
        usableWidth: Double,
        measureGap: Double
    ) -> [Range<Int>] {
        guard !columnWidths.isEmpty else {
            return []
        }

        var ranges: [Range<Int>] = []
        var rangeStart = 0
        var accumulatedWidth = columnWidths[0]

        for index in 1..<columnWidths.count {
            let proposedWidth = accumulatedWidth + measureGap + columnWidths[index]
            if proposedWidth <= usableWidth {
                accumulatedWidth = proposedWidth
            } else {
                ranges.append(rangeStart..<index)
                rangeStart = index
                accumulatedWidth = columnWidths[index]
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
