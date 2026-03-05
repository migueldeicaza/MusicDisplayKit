import MusicDisplayKitLayout
import VexFoundation

public struct VexMeasureContentSpan: Sendable {
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let systemIndex: Int
    public let startX: Double
    public let endX: Double

    public init(
        partIndex: Int,
        measureIndexInPart: Int,
        systemIndex: Int,
        startX: Double,
        endX: Double
    ) {
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.systemIndex = systemIndex
        self.startX = startX
        self.endX = endX
    }
}

public extension VexFoundationRenderer {
    func measureContentSpans(from score: LaidOutScore) -> [VexMeasureContentSpan] {
        let renderPlan = makeRenderPlan(
            from: score,
            target: .view(identifier: "music-display-timeline-map")
        )

        struct StaveLookupKey: Hashable {
            let systemIndex: Int
            let partIndex: Int
        }

        let tabStaveKeys = Set(
            renderPlan.tabPositions.map { tabPositionPlan in
                StaveLookupKey(
                    systemIndex: tabPositionPlan.systemIndex,
                    partIndex: tabPositionPlan.partIndex
                )
            }
        )

        var noteStartXByStaveKey: [StaveLookupKey: Double] = [:]
        for stavePlan in renderPlan.staves {
            let key = StaveLookupKey(
                systemIndex: stavePlan.systemIndex,
                partIndex: stavePlan.partIndex
            )
            let isTabStave = tabStaveKeys.contains(key)

            let stave: Stave
            if isTabStave {
                let tabStave = TabStave(
                    x: stavePlan.frame.x,
                    y: stavePlan.frame.y,
                    width: stavePlan.frame.width
                )
                _ = tabStave.setNumLines(6)
                _ = tabStave.addTabGlyph()
                stave = tabStave
            } else {
                let standardStave = Stave(
                    x: stavePlan.frame.x,
                    y: stavePlan.frame.y,
                    width: stavePlan.frame.width
                )

                if let clefRaw = stavePlan.initialClef,
                   let clefName = ClefName(parsing: clefRaw) {
                    let annotation = stavePlan.initialClefAnnotation.flatMap {
                        ClefAnnotation(rawValue: $0)
                    }
                    _ = standardStave.addClef(clefName, annotation: annotation)
                }

                if let keySignature = stavePlan.initialKeySignature,
                   Tables.hasKeySignature(keySignature) {
                    _ = standardStave.addKeySignature(keySignature)
                }

                if let timeSignature = stavePlan.initialTimeSignature,
                   let timeSignatureSpec = TimeSignatureSpec(parsing: timeSignature, validate: false) {
                    _ = standardStave.addTimeSignature(timeSignatureSpec)
                }

                stave = standardStave
            }

            noteStartXByStaveKey[key] = stave.getNoteStartX()
        }

        var firstMeasureIndexByStaveKey: [StaveLookupKey: Int] = [:]
        for measurePlan in renderPlan.measures {
            let key = StaveLookupKey(
                systemIndex: measurePlan.systemIndex,
                partIndex: measurePlan.partIndex
            )
            let currentFirstMeasure = firstMeasureIndexByStaveKey[key] ?? Int.max
            if measurePlan.measureIndexInPart < currentFirstMeasure {
                firstMeasureIndexByStaveKey[key] = measurePlan.measureIndexInPart
            }
        }

        let contentPaddingX = 6.0
        let firstMeasureLeadingInset = 2.0

        return renderPlan.measures.map { measurePlan in
            let key = StaveLookupKey(
                systemIndex: measurePlan.systemIndex,
                partIndex: measurePlan.partIndex
            )
            let isFirstMeasureInSystem = firstMeasureIndexByStaveKey[key] == measurePlan.measureIndexInPart
            let baseStartX = measurePlan.frame.x + contentPaddingX
            let startX: Double

            if isFirstMeasureInSystem,
               let staveNoteStartX = noteStartXByStaveKey[key] {
                startX = max(baseStartX, staveNoteStartX + firstMeasureLeadingInset)
            } else {
                startX = baseStartX
            }

            let endX = measurePlan.frame.x + measurePlan.frame.width
            let clampedStartX = min(max(startX, measurePlan.frame.x), endX)

            return VexMeasureContentSpan(
                partIndex: measurePlan.partIndex,
                measureIndexInPart: measurePlan.measureIndexInPart,
                systemIndex: measurePlan.systemIndex,
                startX: clampedStartX,
                endX: endX
            )
        }
    }
}
