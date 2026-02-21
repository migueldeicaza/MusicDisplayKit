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

public enum VexStaveBarlineKind: String, Sendable {
    case single
    case repeatBegin
    case repeatEnd
    case repeatBoth
}

public struct VexStavePlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let pageIndex: Int
    public let frame: LayoutRect
    public let startMeasureNumber: Int?
    public let initialClef: String?
    public let initialClefAnnotation: String?
    public let initialKeySignature: String?
    public let initialTimeSignature: String?
    public let beginBarline: VexStaveBarlineKind?
    public let endBarline: VexStaveBarlineKind?

    public init(
        systemIndex: Int,
        partIndex: Int,
        pageIndex: Int,
        frame: LayoutRect,
        startMeasureNumber: Int? = nil,
        initialClef: String? = nil,
        initialClefAnnotation: String? = nil,
        initialKeySignature: String? = nil,
        initialTimeSignature: String? = nil,
        beginBarline: VexStaveBarlineKind? = nil,
        endBarline: VexStaveBarlineKind? = nil
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.pageIndex = pageIndex
        self.frame = frame
        self.startMeasureNumber = startMeasureNumber
        self.initialClef = initialClef
        self.initialClefAnnotation = initialClefAnnotation
        self.initialKeySignature = initialKeySignature
        self.initialTimeSignature = initialTimeSignature
        self.beginBarline = beginBarline
        self.endBarline = endBarline
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

public struct VexMeasureBoundaryPlan: Sendable {
    public let measureIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let measureNumber: Int
    public let systemIndex: Int
    public let pageIndex: Int
    public let x: Double

    public init(
        measureIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        measureNumber: Int,
        systemIndex: Int,
        pageIndex: Int,
        x: Double
    ) {
        self.measureIndex = measureIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.measureNumber = measureNumber
        self.systemIndex = systemIndex
        self.pageIndex = pageIndex
        self.x = x
    }
}

public struct VexNotePlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let measureNumber: Int
    public let pageIndex: Int
    public let measureFrame: LayoutRect
    public let isFirstMeasureInSystem: Bool
    public let voice: Int
    public let entryIndexInVoice: Int
    public let onsetDivisions: Int
    public let durationDivisions: Int
    public let divisions: Int
    public let isRest: Bool
    public let keyTokens: [String]
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        measureNumber: Int,
        pageIndex: Int,
        measureFrame: LayoutRect,
        isFirstMeasureInSystem: Bool,
        voice: Int,
        entryIndexInVoice: Int,
        onsetDivisions: Int,
        durationDivisions: Int,
        divisions: Int,
        isRest: Bool,
        keyTokens: [String],
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.measureNumber = measureNumber
        self.pageIndex = pageIndex
        self.measureFrame = measureFrame
        self.isFirstMeasureInSystem = isFirstMeasureInSystem
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.onsetDivisions = onsetDivisions
        self.durationDivisions = durationDivisions
        self.divisions = divisions
        self.isRest = isRest
        self.keyTokens = keyTokens
        self.sourceOrder = sourceOrder
    }
}

public struct VexBeamPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let number: Int?
    public let startEntryIndex: Int
    public let endEntryIndex: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        number: Int?,
        startEntryIndex: Int,
        endEntryIndex: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.number = number
        self.startEntryIndex = startEntryIndex
        self.endEntryIndex = endEntryIndex
    }
}

public enum VexTupletLocationPlan: Sendable {
    case top
    case bottom
}

public struct VexTupletPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let number: Int?
    public let startEntryIndex: Int
    public let endEntryIndex: Int
    public let numNotes: Int?
    public let notesOccupied: Int?
    public let bracketed: Bool?
    public let ratioed: Bool?
    public let location: VexTupletLocationPlan?

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        number: Int?,
        startEntryIndex: Int,
        endEntryIndex: Int,
        numNotes: Int?,
        notesOccupied: Int?,
        bracketed: Bool?,
        ratioed: Bool?,
        location: VexTupletLocationPlan?
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.number = number
        self.startEntryIndex = startEntryIndex
        self.endEntryIndex = endEntryIndex
        self.numNotes = numNotes
        self.notesOccupied = notesOccupied
        self.bracketed = bracketed
        self.ratioed = ratioed
        self.location = location
    }
}

public struct VexTiePlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let startEntryIndex: Int
    public let endEntryIndex: Int
    public let pitchToken: String?

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        startEntryIndex: Int,
        endEntryIndex: Int,
        pitchToken: String?
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.startEntryIndex = startEntryIndex
        self.endEntryIndex = endEntryIndex
        self.pitchToken = pitchToken
    }
}

public struct VexSlurPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let number: Int?
    public let startEntryIndex: Int
    public let endEntryIndex: Int
    public let placement: String?

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        number: Int?,
        startEntryIndex: Int,
        endEntryIndex: Int,
        placement: String?
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.number = number
        self.startEntryIndex = startEntryIndex
        self.endEntryIndex = endEntryIndex
        self.placement = placement
    }
}

public enum VexArticulationPositionPlan: Sendable {
    case above
    case below
}

public struct VexArticulationPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let articulationCode: String
    public let position: VexArticulationPositionPlan?
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        articulationCode: String,
        position: VexArticulationPositionPlan?,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.articulationCode = articulationCode
        self.position = position
        self.sourceOrder = sourceOrder
    }
}

public struct VexLyricPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let verse: Int
    public let text: String
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        verse: Int,
        text: String,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.verse = verse
        self.text = text
        self.sourceOrder = sourceOrder
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
    public let measureBoundaries: [VexMeasureBoundaryPlan]
    public let notes: [VexNotePlan]
    public let beams: [VexBeamPlan]
    public let tuplets: [VexTupletPlan]
    public let ties: [VexTiePlan]
    public let slurs: [VexSlurPlan]
    public let articulations: [VexArticulationPlan]
    public let lyrics: [VexLyricPlan]
    public let partGroupConnectors: [VexPartGroupConnectorPlan]
    public let barlineConnectors: [VexBarlineConnectorPlan]

    public init(
        canvasWidth: Double,
        canvasHeight: Double,
        pageCount: Int,
        staves: [VexStavePlan],
        measures: [VexMeasurePlan],
        measureBoundaries: [VexMeasureBoundaryPlan],
        notes: [VexNotePlan],
        beams: [VexBeamPlan],
        tuplets: [VexTupletPlan],
        ties: [VexTiePlan],
        slurs: [VexSlurPlan],
        articulations: [VexArticulationPlan],
        lyrics: [VexLyricPlan],
        partGroupConnectors: [VexPartGroupConnectorPlan],
        barlineConnectors: [VexBarlineConnectorPlan]
    ) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.pageCount = pageCount
        self.staves = staves
        self.measures = measures
        self.measureBoundaries = measureBoundaries
        self.notes = notes
        self.beams = beams
        self.tuplets = tuplets
        self.ties = ties
        self.slurs = slurs
        self.articulations = articulations
        self.lyrics = lyrics
        self.partGroupConnectors = partGroupConnectors
        self.barlineConnectors = barlineConnectors
    }
}

public struct VexFactoryExecution {
    public let factory: Factory
    public let staves: [Stave]
    public let voices: [Voice]
    public let notes: [StaveNote]
    public let beams: [Beam]
    public let tuplets: [Tuplet]
    public let ties: [StaveTie]
    public let slurs: [Curve]
    public let articulations: [VexFoundation.Articulation]
    public let lyrics: [VexFoundation.Annotation]
    public let measureBarlineConnectors: [StaveConnector]
    public let partGroupConnectors: [StaveConnector]
    public let barlineConnectors: [StaveConnector]

    public init(
        factory: Factory,
        staves: [Stave],
        voices: [Voice],
        notes: [StaveNote],
        beams: [Beam],
        tuplets: [Tuplet],
        ties: [StaveTie],
        slurs: [Curve],
        articulations: [VexFoundation.Articulation],
        lyrics: [VexFoundation.Annotation],
        measureBarlineConnectors: [StaveConnector],
        partGroupConnectors: [StaveConnector],
        barlineConnectors: [StaveConnector]
    ) {
        self.factory = factory
        self.staves = staves
        self.voices = voices
        self.notes = notes
        self.beams = beams
        self.tuplets = tuplets
        self.ties = ties
        self.slurs = slurs
        self.articulations = articulations
        self.lyrics = lyrics
        self.measureBarlineConnectors = measureBarlineConnectors
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
            let initialState = initialStaveState(for: system, score: score)
            return VexStavePlan(
                systemIndex: system.systemIndex,
                partIndex: system.partIndex,
                pageIndex: system.pageIndex,
                frame: system.frame,
                startMeasureNumber: initialState.measureNumber,
                initialClef: initialState.clefName,
                initialClefAnnotation: initialState.clefAnnotation,
                initialKeySignature: initialState.keySignature,
                initialTimeSignature: initialState.timeSignature,
                beginBarline: initialState.beginBarline,
                endBarline: initialState.endBarline
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

        let measureBoundaries = score.measures.map { measure in
            VexMeasureBoundaryPlan(
                measureIndex: measure.index,
                partIndex: measure.partIndex,
                measureIndexInPart: measure.measureIndexInPart,
                measureNumber: measure.measureNumber,
                systemIndex: measure.systemIndex,
                pageIndex: measure.pageIndex,
                x: measure.frame.x + measure.frame.width
            )
        }

        let firstMeasureIndexBySystem = Dictionary(
            uniqueKeysWithValues: score.systems.map { system in
                (system.systemIndex, system.measureIndices.min() ?? Int.max)
            }
        )

        struct VoiceOnsetKey: Hashable {
            let voice: Int
            let onsetDivisions: Int
        }

        struct MeasureRenderPlans {
            let notes: [VexNotePlan]
            let beams: [VexBeamPlan]
            let tuplets: [VexTupletPlan]
            let ties: [VexTiePlan]
            let slurs: [VexSlurPlan]
            let articulations: [VexArticulationPlan]
            let lyrics: [VexLyricPlan]
        }

        let measureRenderPlans = score.measures.map { laidOutMeasure -> MeasureRenderPlans in
            guard laidOutMeasure.partIndex >= 0,
                  laidOutMeasure.partIndex < score.score.parts.count else {
                return MeasureRenderPlans(
                    notes: [],
                    beams: [],
                    tuplets: [],
                    ties: [],
                    slurs: [],
                    articulations: [],
                    lyrics: []
                )
            }
            let part = score.score.parts[laidOutMeasure.partIndex]
            guard laidOutMeasure.measureIndexInPart >= 0,
                  laidOutMeasure.measureIndexInPart < part.measures.count else {
                return MeasureRenderPlans(
                    notes: [],
                    beams: [],
                    tuplets: [],
                    ties: [],
                    slurs: [],
                    articulations: [],
                    lyrics: []
                )
            }
            let sourceMeasure = part.measures[laidOutMeasure.measureIndexInPart]
            let effectiveDivisions = effectiveDivisions(
                in: part,
                upToMeasureIndex: laidOutMeasure.measureIndexInPart
            )

            let nonGraceEvents = sourceMeasure.noteEvents
                .enumerated()
                .filter { _, event in !event.isGrace }
            let groupedByVoiceAndOnset = Dictionary(grouping: nonGraceEvents) { _, event in
                VoiceOnsetKey(
                    voice: max(1, event.voice),
                    onsetDivisions: max(0, event.onsetDivisions)
                )
            }
            let sortedVoiceOnsets = groupedByVoiceAndOnset.keys.sorted { lhs, rhs in
                if lhs.voice != rhs.voice {
                    return lhs.voice < rhs.voice
                }
                return lhs.onsetDivisions < rhs.onsetDivisions
            }
            let firstMeasureIndexInSystem = firstMeasureIndexBySystem[laidOutMeasure.systemIndex] ?? Int.max
            let isFirstMeasureInSystem = laidOutMeasure.index == firstMeasureIndexInSystem

            var voiceEntryCounters: [Int: Int] = [:]
            var entryIndexByVoiceOnset: [VoiceOnsetKey: Int] = [:]
            let notePlans = sortedVoiceOnsets.enumerated().compactMap { sourceOrder, key -> VexNotePlan? in
                guard let onsetEvents = groupedByVoiceAndOnset[key], !onsetEvents.isEmpty else {
                    return nil
                }

                let entryIndex = voiceEntryCounters[key.voice, default: 0]
                voiceEntryCounters[key.voice] = entryIndex + 1
                entryIndexByVoiceOnset[key] = entryIndex

                let events = onsetEvents
                    .sorted { lhs, rhs in lhs.offset < rhs.offset }
                    .map(\.element)
                let maxDuration = events.compactMap(\.durationDivisions).max() ?? effectiveDivisions
                let pitchedTokens = events.compactMap(noteKeyToken(for:))
                let isRest = pitchedTokens.isEmpty || events.allSatisfy { $0.kind == .rest }
                let keyTokens: [String]
                if isRest {
                    keyTokens = ["r/4"]
                } else {
                    var uniqueTokens: [String] = []
                    for token in pitchedTokens where !uniqueTokens.contains(token) {
                        uniqueTokens.append(token)
                    }
                    keyTokens = uniqueTokens.isEmpty ? ["r/4"] : uniqueTokens
                }

                return VexNotePlan(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    measureNumber: laidOutMeasure.measureNumber,
                    pageIndex: laidOutMeasure.pageIndex,
                    measureFrame: laidOutMeasure.frame,
                    isFirstMeasureInSystem: isFirstMeasureInSystem,
                    voice: key.voice,
                    entryIndexInVoice: entryIndex,
                    onsetDivisions: key.onsetDivisions,
                    durationDivisions: max(1, maxDuration),
                    divisions: max(1, effectiveDivisions),
                    isRest: isRest,
                    keyTokens: keyTokens,
                    sourceOrder: sourceOrder
                )
            }

            let nonGraceIndices = sourceMeasure.noteEvents.indices.filter { index in
                !sourceMeasure.noteEvents[index].isGrace
            }
            let noteIndicesByVoice = Dictionary(grouping: nonGraceIndices) { index in
                max(1, sourceMeasure.noteEvents[index].voice)
            }

            var beamPlans: [VexBeamPlan] = []
            var tupletPlans: [VexTupletPlan] = []
            var tiePlans: [VexTiePlan] = []
            var slurPlans: [VexSlurPlan] = []
            var articulationPlans: [VexArticulationPlan] = []
            var lyricPlans: [VexLyricPlan] = []
            for voice in noteIndicesByVoice.keys.sorted() {
                guard let voiceNoteIndices = noteIndicesByVoice[voice] else {
                    continue
                }
                let sortedNoteIndices = voiceNoteIndices.sorted { lhs, rhs in
                    let lhsEvent = sourceMeasure.noteEvents[lhs]
                    let rhsEvent = sourceMeasure.noteEvents[rhs]
                    if lhsEvent.onsetDivisions != rhsEvent.onsetDivisions {
                        return lhsEvent.onsetDivisions < rhsEvent.onsetDivisions
                    }
                    return lhs < rhs
                }
                var noteToEntryIndex: [Int: Int] = [:]
                for noteIndex in sortedNoteIndices {
                    let note = sourceMeasure.noteEvents[noteIndex]
                    let key = VoiceOnsetKey(
                        voice: max(1, note.voice),
                        onsetDivisions: max(0, note.onsetDivisions)
                    )
                    if let entryIndex = entryIndexByVoiceOnset[key] {
                        noteToEntryIndex[noteIndex] = entryIndex
                    }
                }

                beamPlans.append(contentsOf: buildBeamPlans(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    voice: voice,
                    noteIndices: sortedNoteIndices,
                    noteEvents: sourceMeasure.noteEvents,
                    noteToEntryIndex: noteToEntryIndex
                ))
                tupletPlans.append(contentsOf: buildTupletPlans(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    voice: voice,
                    noteIndices: sortedNoteIndices,
                    noteEvents: sourceMeasure.noteEvents,
                    noteToEntryIndex: noteToEntryIndex
                ))
                tiePlans.append(contentsOf: buildTiePlans(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    voice: voice,
                    tieSpans: sourceMeasure.tieSpans,
                    noteToEntryIndex: noteToEntryIndex
                ))
                slurPlans.append(contentsOf: buildSlurPlans(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    voice: voice,
                    slurSpans: sourceMeasure.slurSpans,
                    noteToEntryIndex: noteToEntryIndex
                ))
                articulationPlans.append(contentsOf: buildArticulationPlans(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    voice: voice,
                    noteIndices: sortedNoteIndices,
                    noteEvents: sourceMeasure.noteEvents,
                    noteToEntryIndex: noteToEntryIndex
                ))
                lyricPlans.append(contentsOf: buildLyricPlans(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    voice: voice,
                    noteIndices: sortedNoteIndices,
                    noteEvents: sourceMeasure.noteEvents,
                    noteToEntryIndex: noteToEntryIndex
                ))
            }

            return MeasureRenderPlans(
                notes: notePlans,
                beams: beamPlans,
                tuplets: tupletPlans,
                ties: tiePlans,
                slurs: slurPlans,
                articulations: articulationPlans,
                lyrics: lyricPlans
            )
        }
        let notes = measureRenderPlans.flatMap(\.notes)
        let beams = measureRenderPlans.flatMap(\.beams)
        let tuplets = measureRenderPlans.flatMap(\.tuplets)
        let ties = measureRenderPlans.flatMap(\.ties)
        let slurs = measureRenderPlans.flatMap(\.slurs)
        let articulations = measureRenderPlans.flatMap(\.articulations)
        let lyrics = measureRenderPlans.flatMap(\.lyrics)

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
            measureBoundaries: measureBoundaries,
            notes: notes,
            beams: beams,
            tuplets: tuplets,
            ties: ties,
            slurs: slurs,
            articulations: articulations,
            lyrics: lyrics,
            partGroupConnectors: partGroupConnectors,
            barlineConnectors: barlineConnectors
        )
    }

    public func executeRenderPlan(_ plan: VexRenderPlan) -> VexFactoryExecution {
        FontLoader.loadDefaultFonts()

        let factory = Factory(
            options: FactoryOptions(width: plan.canvasWidth, height: plan.canvasHeight)
        )

        let sortedStavePlans = plan.staves
            .sorted { $0.systemIndex < $1.systemIndex }

        let createdStaves = sortedStavePlans
            .map { stavePlan in
                factory.Stave(
                    x: stavePlan.frame.x,
                    y: stavePlan.frame.y,
                    width: stavePlan.frame.width
                )
            }

        for (stavePlan, stave) in zip(sortedStavePlans, createdStaves) {
            if let beginBarline = stavePlan.beginBarline,
               let barlineType = beginBarlineType(for: beginBarline) {
                _ = stave.setBegBarType(barlineType)
            }
            if let endBarline = stavePlan.endBarline,
               let barlineType = endBarlineType(for: endBarline) {
                _ = stave.setEndBarType(barlineType)
            }

            if let measureNumber = stavePlan.startMeasureNumber {
                _ = stave.setMeasure(measureNumber)
            }

            if let clefRaw = stavePlan.initialClef,
               let clefName = ClefName(parsing: clefRaw) {
                let annotation = stavePlan.initialClefAnnotation.flatMap {
                    ClefAnnotation(rawValue: $0)
                }
                _ = stave.addClef(clefName, annotation: annotation)
            }

            if let keySignature = stavePlan.initialKeySignature,
               Tables.hasKeySignature(keySignature) {
                _ = stave.addKeySignature(keySignature)
            }

            if let timeSignature = stavePlan.initialTimeSignature,
               let timeSignatureSpec = TimeSignatureSpec(parsing: timeSignature, validate: false) {
                _ = stave.addTimeSignature(timeSignatureSpec)
            }
        }

        let stavesBySystemIndex = Dictionary(
            uniqueKeysWithValues: zip(
                sortedStavePlans.map(\.systemIndex),
                createdStaves
            )
        )

        struct NoteGroupKey: Hashable {
            let systemIndex: Int
            let partIndex: Int
            let measureIndexInPart: Int
        }
        struct NoteEntryKey: Hashable {
            let systemIndex: Int
            let partIndex: Int
            let measureIndexInPart: Int
            let voice: Int
            let entryIndexInVoice: Int
        }

        var createdVoices: [Voice] = []
        var createdNotes: [StaveNote] = []
        var createdBeams: [Beam] = []
        var createdTuplets: [Tuplet] = []
        var createdTies: [StaveTie] = []
        var createdSlurs: [Curve] = []
        var createdArticulations: [VexFoundation.Articulation] = []
        var createdLyrics: [VexFoundation.Annotation] = []
        let quarterTickThreshold = Tables.durationToTicks("4").map(Double.init)
        let stavePadding = (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("stave.padding") as? Double) ?? 0
        let groupedNotes = Dictionary(grouping: plan.notes) { notePlan in
            NoteGroupKey(
                systemIndex: notePlan.systemIndex,
                partIndex: notePlan.partIndex,
                measureIndexInPart: notePlan.measureIndexInPart
            )
        }
        let groupedBeams = Dictionary(grouping: plan.beams) { beamPlan in
            NoteGroupKey(
                systemIndex: beamPlan.systemIndex,
                partIndex: beamPlan.partIndex,
                measureIndexInPart: beamPlan.measureIndexInPart
            )
        }
        let groupedTuplets = Dictionary(grouping: plan.tuplets) { tupletPlan in
            NoteGroupKey(
                systemIndex: tupletPlan.systemIndex,
                partIndex: tupletPlan.partIndex,
                measureIndexInPart: tupletPlan.measureIndexInPart
            )
        }
        let groupedTies = Dictionary(grouping: plan.ties) { tiePlan in
            NoteGroupKey(
                systemIndex: tiePlan.systemIndex,
                partIndex: tiePlan.partIndex,
                measureIndexInPart: tiePlan.measureIndexInPart
            )
        }
        let groupedSlurs = Dictionary(grouping: plan.slurs) { slurPlan in
            NoteGroupKey(
                systemIndex: slurPlan.systemIndex,
                partIndex: slurPlan.partIndex,
                measureIndexInPart: slurPlan.measureIndexInPart
            )
        }
        let groupedArticulations = Dictionary(grouping: plan.articulations) { articulationPlan in
            NoteGroupKey(
                systemIndex: articulationPlan.systemIndex,
                partIndex: articulationPlan.partIndex,
                measureIndexInPart: articulationPlan.measureIndexInPart
            )
        }
        let groupedLyrics = Dictionary(grouping: plan.lyrics) { lyricPlan in
            NoteGroupKey(
                systemIndex: lyricPlan.systemIndex,
                partIndex: lyricPlan.partIndex,
                measureIndexInPart: lyricPlan.measureIndexInPart
            )
        }
        let sortedNoteGroups = groupedNotes.keys.sorted { lhs, rhs in
            if lhs.systemIndex != rhs.systemIndex {
                return lhs.systemIndex < rhs.systemIndex
            }
            if lhs.partIndex != rhs.partIndex {
                return lhs.partIndex < rhs.partIndex
            }
            return lhs.measureIndexInPart < rhs.measureIndexInPart
        }

        for groupKey in sortedNoteGroups {
            guard let stave = stavesBySystemIndex[groupKey.systemIndex],
                  let groupPlans = groupedNotes[groupKey],
                  !groupPlans.isEmpty else {
                continue
            }
            let sortedPlans = groupPlans.sorted { lhs, rhs in
                if lhs.voice != rhs.voice {
                    return lhs.voice < rhs.voice
                }
                if lhs.onsetDivisions != rhs.onsetDivisions {
                    return lhs.onsetDivisions < rhs.onsetDivisions
                }
                return lhs.sourceOrder < rhs.sourceOrder
            }

            let groupedByVoice = Dictionary(grouping: sortedPlans, by: \.voice)
            let sortedVoices = groupedByVoice.keys.sorted()
            var measureVoices: [Voice] = []
            var measureNotes: [StaveNote] = []
            var notesByEntryKey: [NoteEntryKey: StaveNote] = [:]

            for voiceNumber in sortedVoices {
                guard let voicePlans = groupedByVoice[voiceNumber], !voicePlans.isEmpty else {
                    continue
                }

                let sortedVoicePlans = voicePlans.sorted { lhs, rhs in
                    if lhs.onsetDivisions != rhs.onsetDivisions {
                        return lhs.onsetDivisions < rhs.onsetDivisions
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                let stemDirection: StemDirection? = sortedVoices.count > 1
                    ? (voiceNumber == sortedVoices.first ? .up : .down)
                    : nil

                var voiceNotes: [StaveNote] = []
                for notePlan in sortedVoicePlans {
                    guard let note = makeStaveNote(
                        from: notePlan,
                        factory: factory,
                        stave: stave,
                        stemDirection: stemDirection
                    ) else {
                        continue
                    }
                    voiceNotes.append(note)
                    notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: notePlan.systemIndex,
                            partIndex: notePlan.partIndex,
                            measureIndexInPart: notePlan.measureIndexInPart,
                            voice: notePlan.voice,
                            entryIndexInVoice: notePlan.entryIndexInVoice
                        )
                    ] = note
                }
                guard !voiceNotes.isEmpty else {
                    continue
                }

                let voice = factory.Voice(timeSignature: .meter(4, 4))
                _ = voice.setMode(.soft)
                _ = voice.setStave(stave)
                _ = voice.addTickables(voiceNotes.map { $0 as Tickable })

                measureVoices.append(voice)
                measureNotes.append(contentsOf: voiceNotes)
            }
            guard !measureVoices.isEmpty else {
                continue
            }

            if let articulationPlans = groupedArticulations[groupKey] {
                let sortedArticulationPlans = articulationPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                        return lhs.entryIndexInVoice < rhs.entryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for articulationPlan in sortedArticulationPlans {
                    guard let note = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: articulationPlan.systemIndex,
                            partIndex: articulationPlan.partIndex,
                            measureIndexInPart: articulationPlan.measureIndexInPart,
                            voice: articulationPlan.voice,
                            entryIndexInVoice: articulationPlan.entryIndexInVoice
                        )
                    ], !note.isRest() else {
                        continue
                    }

                    let articulation = factory.Articulation(type: articulationPlan.articulationCode)
                    if let position = articulationModifierPosition(for: articulationPlan.position) {
                        _ = articulation.setPosition(position)
                    }
                    _ = note.addModifier(articulation, index: 0)
                    createdArticulations.append(articulation)
                }
            }

            if let lyricPlans = groupedLyrics[groupKey] {
                let sortedLyricPlans = lyricPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                        return lhs.entryIndexInVoice < rhs.entryIndexInVoice
                    }
                    if lhs.verse != rhs.verse {
                        return lhs.verse < rhs.verse
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for lyricPlan in sortedLyricPlans {
                    guard let note = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: lyricPlan.systemIndex,
                            partIndex: lyricPlan.partIndex,
                            measureIndexInPart: lyricPlan.measureIndexInPart,
                            voice: lyricPlan.voice,
                            entryIndexInVoice: lyricPlan.entryIndexInVoice
                        )
                    ], !note.isRest() else {
                        continue
                    }

                    let annotation = factory.Annotation(
                        text: lyricPlan.text,
                        hJustify: .center,
                        vJustify: .bottom
                    )
                    _ = annotation.setPosition(.below)
                    _ = annotation.setTextLine(Double(max(0, lyricPlan.verse - 1)))
                    _ = note.addModifier(annotation, index: 0)
                    createdLyrics.append(annotation)
                }
            }

            let formatter = factory.Formatter()
            _ = formatter.joinVoices(measureVoices).format(
                measureVoices,
                justifyWidth: max(12, sortedPlans[0].measureFrame.width - 10),
                options: FormatParams(alignRests: true, stave: stave)
            )

            let contexts = formatter.getTickContexts().array
            if let minX = contexts.map({ $0.getX() }).min() {
                let anchorPlan = sortedPlans.min { lhs, rhs in
                    if lhs.onsetDivisions != rhs.onsetDivisions {
                        return lhs.onsetDivisions < rhs.onsetDivisions
                    }
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                } ?? sortedPlans[0]
                let desiredAbsoluteStartX: Double
                if anchorPlan.isFirstMeasureInSystem {
                    desiredAbsoluteStartX = max(
                        anchorPlan.measureFrame.x + 6,
                        stave.getNoteStartX() + 2
                    )
                } else {
                    desiredAbsoluteStartX = anchorPlan.measureFrame.x + 6
                }
                let desiredRelativeStartX = desiredAbsoluteStartX - stave.getNoteStartX() - stavePadding
                let delta = desiredRelativeStartX - minX
                for context in contexts {
                    _ = context.setX(context.getX() + delta)
                }
            }

            if let beamPlans = groupedBeams[groupKey] {
                let sortedBeamPlans = beamPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.startEntryIndex != rhs.startEntryIndex {
                        return lhs.startEntryIndex < rhs.startEntryIndex
                    }
                    return lhs.endEntryIndex < rhs.endEntryIndex
                }
                for beamPlan in sortedBeamPlans {
                    let stemmableNotes: [StemmableNote] = (beamPlan.startEntryIndex...beamPlan.endEntryIndex)
                        .compactMap { entryIndex in
                            notesByEntryKey[
                                NoteEntryKey(
                                    systemIndex: beamPlan.systemIndex,
                                    partIndex: beamPlan.partIndex,
                                    measureIndexInPart: beamPlan.measureIndexInPart,
                                    voice: beamPlan.voice,
                                    entryIndexInVoice: entryIndex
                                )
                            ]
                        }
                        .filter { !$0.isRest() }
                        .map { $0 as StemmableNote }
                    guard stemmableNotes.count >= 2 else {
                        continue
                    }
                    if let quarterTickThreshold,
                       !stemmableNotes.allSatisfy({ $0.getIntrinsicTicks() < quarterTickThreshold }) {
                        continue
                    }
                    let beam = factory.Beam(notes: stemmableNotes)
                    createdBeams.append(beam)
                }
            }

            if let tupletPlans = groupedTuplets[groupKey] {
                let sortedTupletPlans = tupletPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.startEntryIndex != rhs.startEntryIndex {
                        return lhs.startEntryIndex < rhs.startEntryIndex
                    }
                    return lhs.endEntryIndex < rhs.endEntryIndex
                }
                for tupletPlan in sortedTupletPlans {
                    let tupletNotes: [Note] = (tupletPlan.startEntryIndex...tupletPlan.endEntryIndex)
                        .compactMap { entryIndex in
                            notesByEntryKey[
                                NoteEntryKey(
                                    systemIndex: tupletPlan.systemIndex,
                                    partIndex: tupletPlan.partIndex,
                                    measureIndexInPart: tupletPlan.measureIndexInPart,
                                    voice: tupletPlan.voice,
                                    entryIndexInVoice: entryIndex
                                )
                            ]
                        }
                        .map { $0 as Note }
                    guard !tupletNotes.isEmpty else {
                        continue
                    }

                    var options = TupletOptions()
                    options.numNotes = tupletPlan.numNotes
                    options.notesOccupied = tupletPlan.notesOccupied
                    options.bracketed = tupletPlan.bracketed
                    options.ratioed = tupletPlan.ratioed
                    options.location = tupletLocation(for: tupletPlan.location)
                    let tuplet = factory.Tuplet(notes: tupletNotes, options: options)
                    createdTuplets.append(tuplet)
                }
            }

            if let tiePlans = groupedTies[groupKey] {
                let sortedTiePlans = tiePlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.startEntryIndex != rhs.startEntryIndex {
                        return lhs.startEntryIndex < rhs.startEntryIndex
                    }
                    return lhs.endEntryIndex < rhs.endEntryIndex
                }
                for tiePlan in sortedTiePlans {
                    let startNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: tiePlan.systemIndex,
                            partIndex: tiePlan.partIndex,
                            measureIndexInPart: tiePlan.measureIndexInPart,
                            voice: tiePlan.voice,
                            entryIndexInVoice: tiePlan.startEntryIndex
                        )
                    ]
                    let endNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: tiePlan.systemIndex,
                            partIndex: tiePlan.partIndex,
                            measureIndexInPart: tiePlan.measureIndexInPart,
                            voice: tiePlan.voice,
                            entryIndexInVoice: tiePlan.endEntryIndex
                        )
                    ]
                    guard startNote != nil || endNote != nil else {
                        continue
                    }
                    let firstIndex = tieKeyIndex(pitchToken: tiePlan.pitchToken, note: startNote)
                    let lastIndex = tieKeyIndex(pitchToken: tiePlan.pitchToken, note: endNote)
                    let tie = factory.StaveTie(
                        notes: TieNotes(
                            firstNote: startNote,
                            lastNote: endNote,
                            firstIndices: [firstIndex],
                            lastIndices: [lastIndex]
                        )
                    )
                    createdTies.append(tie)
                }
            }

            if let slurPlans = groupedSlurs[groupKey] {
                let sortedSlurPlans = slurPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.startEntryIndex != rhs.startEntryIndex {
                        return lhs.startEntryIndex < rhs.startEntryIndex
                    }
                    return lhs.endEntryIndex < rhs.endEntryIndex
                }
                for slurPlan in sortedSlurPlans {
                    let startNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: slurPlan.systemIndex,
                            partIndex: slurPlan.partIndex,
                            measureIndexInPart: slurPlan.measureIndexInPart,
                            voice: slurPlan.voice,
                            entryIndexInVoice: slurPlan.startEntryIndex
                        )
                    ]
                    let endNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: slurPlan.systemIndex,
                            partIndex: slurPlan.partIndex,
                            measureIndexInPart: slurPlan.measureIndexInPart,
                            voice: slurPlan.voice,
                            entryIndexInVoice: slurPlan.endEntryIndex
                        )
                    ]
                    guard let startNote, let endNote else {
                        continue
                    }
                    var options = CurveOptions()
                    if let invert = slurCurveInvert(
                        placement: slurPlan.placement,
                        startNote: startNote,
                        endNote: endNote
                    ) {
                        options.invert = invert
                    }
                    let slur = factory.Curve(from: startNote, to: endNote, options: options)
                    createdSlurs.append(slur)
                }
            }

            createdVoices.append(contentsOf: measureVoices)
            createdNotes.append(contentsOf: measureNotes)
        }

        let measureBarlineConnectors: [StaveConnector] = plan.measureBoundaries.compactMap { boundaryPlan in
            guard let stave = stavesBySystemIndex[boundaryPlan.systemIndex] else {
                return nil
            }

            // Avoid doubling the stave's own terminal barline.
            let staveRightBoundaryX = stave.getX() + stave.getWidth()
            if abs(boundaryPlan.x - staveRightBoundaryX) < 0.5 {
                return nil
            }

            let connector = factory.StaveConnector(
                topStave: stave,
                bottomStave: stave,
                type: .singleLeft
            )
            connector.connectorWidth = 1
            connector.thickness = 1
            _ = connector.setXShift(
                connectorXShift(
                    targetX: boundaryPlan.x,
                    topStave: stave,
                    kind: .singleLeft
                )
            )
            return connector
        }

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
            voices: createdVoices,
            notes: createdNotes,
            beams: createdBeams,
            tuplets: createdTuplets,
            ties: createdTies,
            slurs: createdSlurs,
            articulations: createdArticulations,
            lyrics: createdLyrics,
            measureBarlineConnectors: measureBarlineConnectors,
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

    private struct InitialStaveState {
        let measureNumber: Int?
        let clefName: String?
        let clefAnnotation: String?
        let keySignature: String?
        let timeSignature: String?
        let beginBarline: VexStaveBarlineKind?
        let endBarline: VexStaveBarlineKind?
    }

    private struct EffectiveStaveAttributes {
        let key: MusicDisplayKitModel.KeySignature?
        let time: MusicDisplayKitModel.TimeSignature?
        let clef: MusicDisplayKitModel.ClefSetting?
    }

    private func initialStaveState(
        for system: LaidOutSystem,
        score: LaidOutScore
    ) -> InitialStaveState {
        guard let firstMeasureIndex = system.measureIndices.first,
              firstMeasureIndex >= 0,
              firstMeasureIndex < score.measures.count else {
            return InitialStaveState(
                measureNumber: nil,
                clefName: nil,
                clefAnnotation: nil,
                keySignature: nil,
                timeSignature: nil,
                beginBarline: nil,
                endBarline: nil
            )
        }

        let laidOutMeasure = score.measures[firstMeasureIndex]
        let lastMeasureIndex = system.measureIndices.last ?? firstMeasureIndex
        let lastLaidOutMeasure = score.measures[lastMeasureIndex]
        guard system.partIndex >= 0,
              system.partIndex < score.score.parts.count else {
            return InitialStaveState(
                measureNumber: laidOutMeasure.measureNumber,
                clefName: nil,
                clefAnnotation: nil,
                keySignature: nil,
                timeSignature: nil,
                beginBarline: nil,
                endBarline: nil
            )
        }

        let part = score.score.parts[system.partIndex]
        let effectiveAttributes = effectiveStaveAttributes(
            in: part,
            upToMeasureIndex: laidOutMeasure.measureIndexInPart
        )
        let clefName = effectiveAttributes.clef.flatMap(vexClefName(for:))
        let clefAnnotation = effectiveAttributes.clef.flatMap(vexClefAnnotation(for:))?.rawValue
        let keySignature = effectiveAttributes.key.flatMap(vexKeySignature(for:))
        let timeSignature = effectiveAttributes.time.flatMap(vexTimeSignature(for:))
        let beginBarline = (laidOutMeasure.measureIndexInPart >= 0
            && laidOutMeasure.measureIndexInPart < part.measures.count)
            ? beginBarlineKind(for: part.measures[laidOutMeasure.measureIndexInPart].repetitionInstructions)
            : nil
        let endBarline = (lastLaidOutMeasure.measureIndexInPart >= 0
            && lastLaidOutMeasure.measureIndexInPart < part.measures.count)
            ? endBarlineKind(for: part.measures[lastLaidOutMeasure.measureIndexInPart].repetitionInstructions)
            : nil
        return InitialStaveState(
            measureNumber: laidOutMeasure.measureNumber,
            clefName: clefName?.rawValue,
            clefAnnotation: clefAnnotation,
            keySignature: keySignature,
            timeSignature: timeSignature,
            beginBarline: beginBarline,
            endBarline: endBarline
        )
    }

    private func effectiveStaveAttributes(
        in part: MusicDisplayKitModel.Part,
        upToMeasureIndex: Int
    ) -> EffectiveStaveAttributes {
        guard !part.measures.isEmpty else {
            return EffectiveStaveAttributes(key: nil, time: nil, clef: nil)
        }

        var key: MusicDisplayKitModel.KeySignature?
        var time: MusicDisplayKitModel.TimeSignature?
        var clef: MusicDisplayKitModel.ClefSetting?
        let lastIndex = min(upToMeasureIndex, part.measures.count - 1)
        guard lastIndex >= 0 else {
            return EffectiveStaveAttributes(key: nil, time: nil, clef: nil)
        }

        for measureIndex in 0...lastIndex {
            guard let attributes = part.measures[measureIndex].attributes else {
                continue
            }
            if let nextKey = attributes.key {
                key = nextKey
            }
            if let nextTime = attributes.time {
                time = nextTime
            }
            if let nextClef = selectedClef(from: attributes.clefs) {
                clef = nextClef
            }
        }

        return EffectiveStaveAttributes(key: key, time: time, clef: clef)
    }

    private func effectiveDivisions(
        in part: MusicDisplayKitModel.Part,
        upToMeasureIndex: Int
    ) -> Int {
        guard !part.measures.isEmpty else {
            return 4
        }
        let lastIndex = min(upToMeasureIndex, part.measures.count - 1)
        guard lastIndex >= 0 else {
            return 4
        }
        var divisions = 4
        for measureIndex in 0...lastIndex {
            if let nextDivisions = part.measures[measureIndex].divisions, nextDivisions > 0 {
                divisions = nextDivisions
            }
        }
        return max(1, divisions)
    }

    private func buildBeamPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        noteIndices: [Int],
        noteEvents: [MusicDisplayKitModel.NoteEvent],
        noteToEntryIndex: [Int: Int]
    ) -> [VexBeamPlan] {
        struct NumberKey: Hashable {
            let number: Int?
        }
        struct SpanKey: Hashable {
            let number: Int?
            let start: Int
            let end: Int
        }
        struct MarkerOccurrenceKey: Hashable {
            let entryIndex: Int
            let number: Int?
            let beamValue: MusicDisplayKitModel.BeamValue
        }

        var spans: [VexBeamPlan] = []
        var seen: Set<SpanKey> = []
        var processed: Set<MarkerOccurrenceKey> = []
        var openByNumber: [NumberKey: Int] = [:]

        for noteIndex in noteIndices {
            guard let entryIndex = noteToEntryIndex[noteIndex] else {
                continue
            }

            for beam in noteEvents[noteIndex].beams {
                let occurrence = MarkerOccurrenceKey(
                    entryIndex: entryIndex,
                    number: beam.number,
                    beamValue: beam.value
                )
                if processed.contains(occurrence) {
                    continue
                }
                processed.insert(occurrence)

                let numberKey = NumberKey(number: beam.number)
                switch beam.value {
                case .begin:
                    openByNumber[numberKey] = entryIndex
                case .continue:
                    if openByNumber[numberKey] == nil {
                        openByNumber[numberKey] = entryIndex
                    }
                case .end:
                    if let start = openByNumber.removeValue(forKey: numberKey),
                       start != entryIndex {
                        let key = SpanKey(
                            number: beam.number,
                            start: min(start, entryIndex),
                            end: max(start, entryIndex)
                        )
                        if !seen.contains(key) {
                            seen.insert(key)
                            spans.append(
                                VexBeamPlan(
                                    systemIndex: systemIndex,
                                    partIndex: partIndex,
                                    measureIndexInPart: measureIndexInPart,
                                    voice: voice,
                                    number: beam.number,
                                    startEntryIndex: key.start,
                                    endEntryIndex: key.end
                                )
                            )
                        }
                    }
                case .forwardHook, .backwardHook, .unknown:
                    break
                }
            }
        }

        return spans.sorted { lhs, rhs in
            if lhs.startEntryIndex != rhs.startEntryIndex {
                return lhs.startEntryIndex < rhs.startEntryIndex
            }
            if lhs.endEntryIndex != rhs.endEntryIndex {
                return lhs.endEntryIndex < rhs.endEntryIndex
            }
            return optionalNumberSortValue(lhs.number) < optionalNumberSortValue(rhs.number)
        }
    }

    private func buildTupletPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        noteIndices: [Int],
        noteEvents: [MusicDisplayKitModel.NoteEvent],
        noteToEntryIndex: [Int: Int]
    ) -> [VexTupletPlan] {
        struct NumberKey: Hashable {
            let number: Int?
        }
        struct SpanKey: Hashable {
            let number: Int?
            let start: Int
            let end: Int
        }
        struct MarkerOccurrenceKey: Hashable {
            let entryIndex: Int
            let number: Int?
            let spanType: MusicDisplayKitModel.NotationSpanType
        }
        struct OpenTuplet {
            let startEntryIndex: Int
            let startNoteIndex: Int
            let startMarker: MusicDisplayKitModel.TupletMarker
        }

        var spans: [VexTupletPlan] = []
        var seen: Set<SpanKey> = []
        var processed: Set<MarkerOccurrenceKey> = []
        var openByNumber: [NumberKey: OpenTuplet] = [:]

        for noteIndex in noteIndices {
            guard let entryIndex = noteToEntryIndex[noteIndex] else {
                continue
            }

            for tuplet in noteEvents[noteIndex].tuplets {
                let occurrence = MarkerOccurrenceKey(
                    entryIndex: entryIndex,
                    number: tuplet.number,
                    spanType: tuplet.type
                )
                if processed.contains(occurrence) {
                    continue
                }
                processed.insert(occurrence)

                let numberKey = NumberKey(number: tuplet.number)
                switch tuplet.type {
                case .start:
                    openByNumber[numberKey] = OpenTuplet(
                        startEntryIndex: entryIndex,
                        startNoteIndex: noteIndex,
                        startMarker: tuplet
                    )
                case .continue:
                    if openByNumber[numberKey] == nil {
                        openByNumber[numberKey] = OpenTuplet(
                            startEntryIndex: entryIndex,
                            startNoteIndex: noteIndex,
                            startMarker: tuplet
                        )
                    }
                case .stop:
                    guard let open = openByNumber.removeValue(forKey: numberKey),
                          open.startEntryIndex != entryIndex else {
                        continue
                    }
                    let key = SpanKey(
                        number: tuplet.number,
                        start: min(open.startEntryIndex, entryIndex),
                        end: max(open.startEntryIndex, entryIndex)
                    )
                    if seen.contains(key) {
                        continue
                    }
                    seen.insert(key)

                    let startMarker = open.startMarker
                    let timeModification =
                        noteEvents[open.startNoteIndex].timeModification
                        ?? noteEvents[noteIndex].timeModification
                    let numNotes = timeModification?.actualNotes.flatMap { $0 > 0 ? $0 : nil }
                    let notesOccupied = timeModification?.normalNotes.flatMap { $0 > 0 ? $0 : nil }
                    let placement = startMarker.placement ?? tuplet.placement
                    let location = tupletLocationPlan(from: placement)
                    let ratioed = tupletRatioed(
                        showNumber: startMarker.showNumber ?? tuplet.showNumber,
                        showType: startMarker.showType ?? tuplet.showType
                    )

                    spans.append(
                        VexTupletPlan(
                            systemIndex: systemIndex,
                            partIndex: partIndex,
                            measureIndexInPart: measureIndexInPart,
                            voice: voice,
                            number: tuplet.number,
                            startEntryIndex: key.start,
                            endEntryIndex: key.end,
                            numNotes: numNotes,
                            notesOccupied: notesOccupied,
                            bracketed: startMarker.bracket ?? tuplet.bracket,
                            ratioed: ratioed,
                            location: location
                        )
                    )
                case .unknown:
                    break
                }
            }
        }

        return spans.sorted { lhs, rhs in
            if lhs.startEntryIndex != rhs.startEntryIndex {
                return lhs.startEntryIndex < rhs.startEntryIndex
            }
            if lhs.endEntryIndex != rhs.endEntryIndex {
                return lhs.endEntryIndex < rhs.endEntryIndex
            }
            return optionalNumberSortValue(lhs.number) < optionalNumberSortValue(rhs.number)
        }
    }

    private func buildTiePlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        tieSpans: [MusicDisplayKitModel.TieSpan],
        noteToEntryIndex: [Int: Int]
    ) -> [VexTiePlan] {
        tieSpans
            .compactMap { span -> VexTiePlan? in
                guard span.voice == voice,
                      let startEntryIndex = noteToEntryIndex[span.startNoteIndex],
                      let endEntryIndex = noteToEntryIndex[span.endNoteIndex],
                      startEntryIndex != endEntryIndex else {
                    return nil
                }
                return VexTiePlan(
                    systemIndex: systemIndex,
                    partIndex: partIndex,
                    measureIndexInPart: measureIndexInPart,
                    voice: voice,
                    startEntryIndex: min(startEntryIndex, endEntryIndex),
                    endEntryIndex: max(startEntryIndex, endEntryIndex),
                    pitchToken: span.pitch.flatMap(noteKeyToken(for:))
                )
            }
            .sorted { lhs, rhs in
                if lhs.startEntryIndex != rhs.startEntryIndex {
                    return lhs.startEntryIndex < rhs.startEntryIndex
                }
                return lhs.endEntryIndex < rhs.endEntryIndex
            }
    }

    private func buildSlurPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        slurSpans: [MusicDisplayKitModel.SlurSpan],
        noteToEntryIndex: [Int: Int]
    ) -> [VexSlurPlan] {
        slurSpans
            .compactMap { span -> VexSlurPlan? in
                guard span.voice == voice,
                      let startEntryIndex = noteToEntryIndex[span.startNoteIndex],
                      let endEntryIndex = noteToEntryIndex[span.endNoteIndex],
                      startEntryIndex != endEntryIndex else {
                    return nil
                }
                return VexSlurPlan(
                    systemIndex: systemIndex,
                    partIndex: partIndex,
                    measureIndexInPart: measureIndexInPart,
                    voice: voice,
                    number: span.number,
                    startEntryIndex: min(startEntryIndex, endEntryIndex),
                    endEntryIndex: max(startEntryIndex, endEntryIndex),
                    placement: span.placement
                )
            }
            .sorted { lhs, rhs in
                if lhs.startEntryIndex != rhs.startEntryIndex {
                    return lhs.startEntryIndex < rhs.startEntryIndex
                }
                if lhs.endEntryIndex != rhs.endEntryIndex {
                    return lhs.endEntryIndex < rhs.endEntryIndex
                }
                return optionalNumberSortValue(lhs.number) < optionalNumberSortValue(rhs.number)
            }
    }

    private func buildArticulationPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        noteIndices: [Int],
        noteEvents: [MusicDisplayKitModel.NoteEvent],
        noteToEntryIndex: [Int: Int]
    ) -> [VexArticulationPlan] {
        struct PlanKey: Hashable {
            let entryIndexInVoice: Int
            let articulationCode: String
            let position: VexArticulationPositionPlan?
        }

        var plans: [VexArticulationPlan] = []
        var seen: Set<PlanKey> = []
        var sourceOrder = 0
        for noteIndex in noteIndices {
            guard let entryIndex = noteToEntryIndex[noteIndex] else {
                continue
            }
            let note = noteEvents[noteIndex]
            for marker in note.articulations {
                guard let articulationCode = articulationCode(for: marker) else {
                    continue
                }
                let position = articulationPositionPlan(
                    placement: marker.placement,
                    type: marker.type
                )
                let key = PlanKey(
                    entryIndexInVoice: entryIndex,
                    articulationCode: articulationCode,
                    position: position
                )
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)
                plans.append(
                    VexArticulationPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: voice,
                        entryIndexInVoice: entryIndex,
                        articulationCode: articulationCode,
                        position: position,
                        sourceOrder: sourceOrder
                    )
                )
                sourceOrder += 1
            }
        }

        return plans.sorted { lhs, rhs in
            if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                return lhs.entryIndexInVoice < rhs.entryIndexInVoice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }
    }

    private func buildLyricPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        noteIndices: [Int],
        noteEvents: [MusicDisplayKitModel.NoteEvent],
        noteToEntryIndex: [Int: Int]
    ) -> [VexLyricPlan] {
        struct PlanKey: Hashable {
            let entryIndexInVoice: Int
            let verse: Int
            let text: String
        }

        var plans: [VexLyricPlan] = []
        var seen: Set<PlanKey> = []
        var sourceOrder = 0
        for noteIndex in noteIndices {
            guard let entryIndex = noteToEntryIndex[noteIndex] else {
                continue
            }
            let note = noteEvents[noteIndex]
            for lyric in note.lyrics {
                guard let text = lyricText(for: lyric) else {
                    continue
                }
                let verse = max(1, lyric.number)
                let key = PlanKey(
                    entryIndexInVoice: entryIndex,
                    verse: verse,
                    text: text
                )
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)
                plans.append(
                    VexLyricPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: voice,
                        entryIndexInVoice: entryIndex,
                        verse: verse,
                        text: text,
                        sourceOrder: sourceOrder
                    )
                )
                sourceOrder += 1
            }
        }

        return plans.sorted { lhs, rhs in
            if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                return lhs.entryIndexInVoice < rhs.entryIndexInVoice
            }
            if lhs.verse != rhs.verse {
                return lhs.verse < rhs.verse
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }
    }

    private func optionalNumberSortValue(_ number: Int?) -> Int {
        number ?? Int.min
    }

    private func tupletLocationPlan(from placement: String?) -> VexTupletLocationPlan? {
        guard let placement else {
            return nil
        }
        switch placement.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "below", "bottom", "under":
            return .bottom
        case "above", "top", "over":
            return .top
        default:
            return nil
        }
    }

    private func tupletRatioed(showNumber: String?, showType: String?) -> Bool? {
        let normalizedShowNumber = showNumber?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedShowType = showType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalizedShowNumber == "both" || normalizedShowType == "both" {
            return true
        }
        return nil
    }

    private func articulationCode(
        for marker: MusicDisplayKitModel.ArticulationMarker
    ) -> String? {
        if let type = marker.type?.trimmingCharacters(in: .whitespacesAndNewlines),
           !type.isEmpty,
           Tables.articulationCode(type) != nil {
            return type
        }

        switch marker.kind {
        case .accent, .stress:
            return "a>"
        case .strongAccent:
            return "a^"
        case .staccato:
            return "a."
        case .tenuto, .detachedLegato, .unstress:
            return "a-"
        case .staccatissimo, .spiccato:
            return "av"
        case .breathMark:
            return "a,"
        case .caesura:
            return "a,"
        case .scoop, .plop, .doit, .falloff:
            return nil
        case .unknown(let raw):
            let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return Tables.articulationCode(normalized) == nil ? nil : normalized
        }
    }

    private func articulationPositionPlan(
        placement: String?,
        type: String?
    ) -> VexArticulationPositionPlan? {
        if let placement {
            switch placement.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "above", "top", "over":
                return .above
            case "below", "bottom", "under":
                return .below
            default:
                break
            }
        }
        if let type {
            switch type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "up":
                return .above
            case "down":
                return .below
            default:
                break
            }
        }
        return nil
    }

    private func lyricText(for lyric: MusicDisplayKitModel.LyricEvent) -> String? {
        let text = lyric.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else {
            return nil
        }
        return text
    }

    private func noteKeyToken(for note: MusicDisplayKitModel.NoteEvent) -> String? {
        guard note.kind == .pitched,
              let pitch = note.pitch else {
            return nil
        }
        return noteKeyToken(for: pitch)
    }

    private func noteKeyToken(for pitch: MusicDisplayKitModel.PitchValue) -> String? {
        guard pitch.octave >= 0 else {
            return nil
        }

        let step = pitch.step.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !step.isEmpty else {
            return nil
        }
        let accidentalToken: String
        switch pitch.alter {
        case let alter where alter > 0:
            accidentalToken = String(repeating: "#", count: min(2, alter))
        case let alter where alter < 0:
            accidentalToken = String(repeating: "b", count: min(2, abs(alter)))
        default:
            accidentalToken = ""
        }
        return "\(step)\(accidentalToken)/\(pitch.octave)"
    }

    private func tieKeyIndex(pitchToken: String?, note: StaveNote?) -> Int {
        guard let note else {
            return 0
        }
        guard let pitchToken = pitchToken?.lowercased() else {
            return 0
        }
        return note.getKeys().firstIndex(where: { $0.lowercased() == pitchToken }) ?? 0
    }

    private func slurCurveInvert(
        placement: String?,
        startNote: StaveNote?,
        endNote: StaveNote?
    ) -> Bool? {
        guard let placement = placement?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return nil
        }
        let desiredAbove: Bool
        switch placement {
        case "above", "top", "over":
            desiredAbove = true
        case "below", "bottom", "under":
            desiredAbove = false
        default:
            return nil
        }

        guard let anchor = startNote ?? endNote else {
            return nil
        }
        let naturallyAbove = anchor.getStemDirection() == .down
        return desiredAbove != naturallyAbove
    }

    private func articulationModifierPosition(
        for planPosition: VexArticulationPositionPlan?
    ) -> ModifierPosition? {
        switch planPosition {
        case .above:
            return .above
        case .below:
            return .below
        case .none:
            return nil
        }
    }

    private func makeStaveNote(
        from notePlan: VexNotePlan,
        factory: Factory,
        stave: Stave,
        stemDirection: StemDirection? = nil
    ) -> StaveNote? {
        let duration = noteDurationSpec(
            durationDivisions: notePlan.durationDivisions,
            divisions: notePlan.divisions,
            isRest: notePlan.isRest
        )
        let keys: [StaffKeySpec] = notePlan.keyTokens.compactMap { token in
            try? StaffKeySpec(parsing: token)
        }
        guard let nonEmptyKeys = NonEmptyArray(validating: keys) else {
            return nil
        }

        let note = factory.StaveNote(
            StaveNoteStruct(
                keys: nonEmptyKeys,
                duration: duration
            )
        )
        if let stemDirection {
            _ = note.setStemDirection(stemDirection)
        }
        _ = note.setStave(stave)
        return note
    }

    private func noteDurationSpec(
        durationDivisions: Int,
        divisions: Int,
        isRest: Bool
    ) -> NoteDurationSpec {
        guard durationDivisions > 0, divisions > 0 else {
            return NoteDurationSpec(
                uncheckedValue: .quarter,
                type: isRest ? .rest : .note
            )
        }
        let targetWhole = Double(durationDivisions) / Double(divisions * 4)
        let candidates: [(value: NoteValue, dots: Int)] = [
            .doubleWhole, .whole, .half, .quarter, .eighth, .sixteenth, .thirtySecond, .sixtyFourth,
        ].flatMap { value in
            (0...2).map { dots in (value: value, dots: dots) }
        }

        let best = candidates.min { lhs, rhs in
            let lhsDelta = abs(durationWholeValue(for: lhs.value, dots: lhs.dots) - targetWhole)
            let rhsDelta = abs(durationWholeValue(for: rhs.value, dots: rhs.dots) - targetWhole)
            if lhsDelta == rhsDelta {
                return lhs.dots < rhs.dots
            }
            return lhsDelta < rhsDelta
        } ?? (value: .quarter, dots: 0)

        return NoteDurationSpec(
            uncheckedValue: best.value,
            dots: best.dots,
            type: isRest ? .rest : .note
        )
    }

    private func durationWholeValue(for value: NoteValue, dots: Int) -> Double {
        let base: Double
        switch value {
        case .doubleWhole:
            base = 2
        case .whole:
            base = 1
        case .half:
            base = 0.5
        case .quarter:
            base = 0.25
        case .eighth:
            base = 0.125
        case .sixteenth:
            base = 1.0 / 16.0
        case .thirtySecond:
            base = 1.0 / 32.0
        case .sixtyFourth:
            base = 1.0 / 64.0
        case .oneTwentyEighth:
            base = 1.0 / 128.0
        case .twoFiftySixth:
            base = 1.0 / 256.0
        }

        guard dots > 0 else {
            return base
        }
        var total = base
        var current = base
        for _ in 0..<dots {
            current /= 2
            total += current
        }
        return total
    }

    private func selectedClef(
        from clefs: [MusicDisplayKitModel.ClefSetting]
    ) -> MusicDisplayKitModel.ClefSetting? {
        if let primary = clefs.first(where: { $0.number == 1 }) {
            return primary
        }
        if let unnumbered = clefs.first(where: { $0.number == nil }) {
            return unnumbered
        }
        return clefs.first
    }

    private func vexClefName(for clef: MusicDisplayKitModel.ClefSetting) -> ClefName? {
        let sign = clef.sign.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch sign {
        case "G":
            if clef.line == 1 {
                return .french
            }
            return .treble
        case "F":
            switch clef.line {
            case 3:
                return .baritoneF
            case 5:
                return .subbass
            default:
                return .bass
            }
        case "C":
            switch clef.line {
            case 1:
                return .soprano
            case 2:
                return .mezzoSoprano
            case 3:
                return .alto
            case 4:
                return .tenor
            case 5:
                return .baritoneC
            default:
                return .alto
            }
        case "PERCUSSION":
            return .percussion
        case "TAB":
            return .tab
        default:
            return nil
        }
    }

    private func vexClefAnnotation(
        for clef: MusicDisplayKitModel.ClefSetting
    ) -> ClefAnnotation? {
        switch clef.octaveChange {
        case 1:
            return .octaveUp
        case -1:
            return .octaveDown
        default:
            return nil
        }
    }

    private func vexKeySignature(for key: MusicDisplayKitModel.KeySignature) -> String? {
        let majorMap: [Int: String] = [
            -7: "Cb", -6: "Gb", -5: "Db", -4: "Ab", -3: "Eb", -2: "Bb", -1: "F",
            0: "C",
            1: "G", 2: "D", 3: "A", 4: "E", 5: "B", 6: "F#", 7: "C#",
        ]
        let minorMap: [Int: String] = [
            -7: "Abm", -6: "Ebm", -5: "Bbm", -4: "Fm", -3: "Cm", -2: "Gm", -1: "Dm",
            0: "Am",
            1: "Em", 2: "Bm", 3: "F#m", 4: "C#m", 5: "G#m", 6: "D#m", 7: "A#m",
        ]

        let mode = key.mode?.trimmingCharacters(
            in: Foundation.CharacterSet.whitespacesAndNewlines
        ).lowercased()
        let isMinorMode = mode == "minor"
            || mode == "aeolian"
            || mode == "melodic minor"
            || mode == "harmonic minor"
        let candidate = isMinorMode ? minorMap[key.fifths] : majorMap[key.fifths]
        guard let candidate, Tables.hasKeySignature(candidate) else {
            return nil
        }
        return candidate
    }

    private func vexTimeSignature(for time: MusicDisplayKitModel.TimeSignature) -> String? {
        let symbol = time.symbol?.trimmingCharacters(
            in: Foundation.CharacterSet.whitespacesAndNewlines
        ).lowercased()
        switch symbol {
        case "common":
            return TimeSignatureSymbol.common.rawValue
        case "cut":
            return TimeSignatureSymbol.cutCommon.rawValue
        default:
            break
        }

        guard time.beats > 0, time.beatType > 0 else {
            return nil
        }
        return "\(time.beats)/\(time.beatType)"
    }

    private func beginBarlineKind(
        for instructions: [MusicDisplayKitModel.RepetitionInstruction]
    ) -> VexStaveBarlineKind? {
        let leftRepeats = instructions.filter { instruction in
            instruction.location == "left"
                && (instruction.kind == .repeatForward || instruction.kind == .repeatBackward)
        }
        let hasForward = leftRepeats.contains { $0.kind == .repeatForward }
        let hasBackward = leftRepeats.contains { $0.kind == .repeatBackward }

        if hasForward && hasBackward {
            return .repeatBegin
        }
        if hasForward {
            return .repeatBegin
        }
        return nil
    }

    private func endBarlineKind(
        for instructions: [MusicDisplayKitModel.RepetitionInstruction]
    ) -> VexStaveBarlineKind? {
        let rightRepeats = instructions.filter { instruction in
            instruction.location == "right"
                && (instruction.kind == .repeatForward || instruction.kind == .repeatBackward)
        }
        let hasForward = rightRepeats.contains { $0.kind == .repeatForward }
        let hasBackward = rightRepeats.contains { $0.kind == .repeatBackward }

        if hasForward && hasBackward {
            return .repeatBoth
        }
        if hasBackward {
            return .repeatEnd
        }
        if hasForward {
            return .repeatBegin
        }
        return nil
    }

    private func beginBarlineType(for kind: VexStaveBarlineKind) -> BarlineType? {
        switch kind {
        case .single:
            return .single
        case .repeatBegin:
            return .repeatBegin
        case .repeatEnd, .repeatBoth:
            return nil
        }
    }

    private func endBarlineType(for kind: VexStaveBarlineKind) -> BarlineType? {
        switch kind {
        case .single:
            return .single
        case .repeatBegin:
            return nil
        case .repeatEnd:
            return .repeatEnd
        case .repeatBoth:
            return .repeatBoth
        }
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

    private func tupletLocation(for planLocation: VexTupletLocationPlan?) -> TupletLocation? {
        switch planLocation {
        case .top:
            return .top
        case .bottom:
            return .bottom
        case .none:
            return nil
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
        let attributes = MeasureAttributes(
            key: KeySignature(fifths: 0, mode: "major"),
            time: TimeSignature(beats: 4, beatType: 4),
            clefs: [ClefSetting(sign: "G", line: 2)]
        )
        let lowerAttributes = MeasureAttributes(
            key: KeySignature(fifths: 0, mode: "major"),
            time: TimeSignature(beats: 4, beatType: 4),
            clefs: [ClefSetting(sign: "F", line: 4)]
        )

        return Score(
            title: "Renderer Preview",
            parts: [
                Part(
                    id: "P1",
                    name: "Piano RH",
                    measures: [
                        Measure(
                            number: 1,
                            divisions: 4,
                            attributes: attributes,
                            noteEvents: [
                                NoteEvent(
                                    kind: .pitched,
                                    pitch: PitchValue(step: "C", octave: 4),
                                    onsetDivisions: 0,
                                    durationDivisions: 4,
                                    voice: 1
                                ),
                                NoteEvent(
                                    kind: .pitched,
                                    pitch: PitchValue(step: "E", octave: 4),
                                    onsetDivisions: 4,
                                    durationDivisions: 4,
                                    voice: 1
                                ),
                                NoteEvent(
                                    kind: .rest,
                                    onsetDivisions: 8,
                                    durationDivisions: 4,
                                    voice: 1
                                ),
                                NoteEvent(
                                    kind: .pitched,
                                    pitch: PitchValue(step: "G", octave: 4),
                                    onsetDivisions: 12,
                                    durationDivisions: 4,
                                    voice: 1
                                ),
                            ]
                        ),
                    ]
                ),
                Part(
                    id: "P2",
                    name: "Piano LH",
                    measures: [
                        Measure(
                            number: 1,
                            divisions: 4,
                            attributes: lowerAttributes,
                            noteEvents: [
                                NoteEvent(
                                    kind: .pitched,
                                    pitch: PitchValue(step: "C", octave: 3),
                                    onsetDivisions: 0,
                                    durationDivisions: 8,
                                    voice: 1
                                ),
                                NoteEvent(
                                    kind: .pitched,
                                    pitch: PitchValue(step: "G", octave: 2),
                                    onsetDivisions: 8,
                                    durationDivisions: 8,
                                    voice: 1
                                ),
                            ]
                        ),
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
