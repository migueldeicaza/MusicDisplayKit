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

        var systems: [LaidOutSystem] = []
        var measures: [LaidOutMeasure] = []

        var pageIndex = 0
        var currentY = options.pageMargin

        for (partIndex, part) in score.parts.enumerated() {
            var currentX = options.pageMargin
            var currentSystemIndex: Int?
            var effectiveDivisions: Int?
            var effectiveTime: TimeSignature?

            for (measureIndex, measure) in part.measures.enumerated() {
                if let divisions = measure.divisions, divisions > 0 {
                    effectiveDivisions = divisions
                }
                if let time = measure.attributes?.time {
                    effectiveTime = time
                }

                let measureWidth = min(
                    usableWidth,
                    computedMeasureWidth(
                        measure: measure,
                        effectiveDivisions: effectiveDivisions,
                        effectiveTime: effectiveTime,
                        options: options
                    )
                )

                let needsLineBreak = currentSystemIndex != nil
                    && (currentX + measureWidth > options.pageWidth - options.pageMargin)

                if currentSystemIndex == nil || needsLineBreak {
                    if currentSystemIndex != nil {
                        currentY += options.staffHeight + options.systemSpacing
                    }

                    if let maxSystemBottom,
                       currentY + options.staffHeight > maxSystemBottom {
                        pageIndex += 1
                        currentY = options.pageMargin
                    }

                    let systemIndex = systems.count
                    let systemFrame = LayoutRect(
                        x: options.pageMargin,
                        y: currentY,
                        width: usableWidth,
                        height: options.staffHeight
                    )
                    systems.append(
                        LaidOutSystem(
                            systemIndex: systemIndex,
                            partIndex: partIndex,
                            pageIndex: pageIndex,
                            frame: systemFrame,
                            measureIndices: []
                        )
                    )
                    currentSystemIndex = systemIndex
                    currentX = options.pageMargin
                }

                let systemIndex = currentSystemIndex ?? 0
                let frame = LayoutRect(
                    x: currentX,
                    y: currentY,
                    width: measureWidth,
                    height: options.staffHeight
                )
                let laidOutMeasure = LaidOutMeasure(
                    index: measures.count,
                    partIndex: partIndex,
                    measureIndexInPart: measureIndex,
                    measureNumber: measure.number,
                    systemIndex: systemIndex,
                    pageIndex: pageIndex,
                    frame: frame
                )
                measures.append(laidOutMeasure)
                systems[systemIndex].measureIndices.append(laidOutMeasure.index)

                currentX += measureWidth + options.measureGap
            }

            if partIndex < score.parts.count - 1 {
                currentY += options.staffHeight + options.partSpacing
                if let maxSystemBottom,
                   currentY + options.staffHeight > maxSystemBottom {
                    pageIndex += 1
                    currentY = options.pageMargin
                }
            }
        }

        return LaidOutScore(
            score: score,
            pageWidth: options.pageWidth,
            pageHeight: options.pageHeight,
            systems: systems,
            measures: measures
        )
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
