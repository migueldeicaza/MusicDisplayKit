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

public struct VexChordSymbolPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let displayText: String
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        displayText: String,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.displayText = displayText
        self.sourceOrder = sourceOrder
    }
}

public enum VexDirectionTextPlacementPlan: Sendable {
    case above
    case below
}

public struct VexDirectionTextPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let text: String
    public let placement: VexDirectionTextPlacementPlan?
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        text: String,
        placement: VexDirectionTextPlacementPlan?,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.text = text
        self.placement = placement
        self.sourceOrder = sourceOrder
    }
}

public struct VexTempoMarkPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let bpm: Int
    public let duration: NoteValue
    public let dots: Int
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        bpm: Int,
        duration: NoteValue,
        dots: Int,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.bpm = bpm
        self.duration = duration
        self.dots = dots
        self.sourceOrder = sourceOrder
    }
}

public enum VexRoadmapRepetitionKind: Hashable, Sendable {
    case codaLeft
    case codaRight
    case segnoLeft
    case segnoRight
    case dc
    case dcAlCoda
    case dcAlFine
    case ds
    case dsAlCoda
    case dsAlFine
    case fine
    case toCoda
}

public enum VexRoadmapRepetitionAnchor: Hashable, Sendable {
    case leftEdge
    case rightEdge
    case entry(voice: Int, entryIndexInVoice: Int)
}

public struct VexRoadmapRepetitionPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let kind: VexRoadmapRepetitionKind
    public let anchor: VexRoadmapRepetitionAnchor
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        kind: VexRoadmapRepetitionKind,
        anchor: VexRoadmapRepetitionAnchor,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.kind = kind
        self.anchor = anchor
        self.sourceOrder = sourceOrder
    }
}

public enum VexDirectionWedgeKind: Sendable {
    case crescendo
    case decrescendo
}

public struct VexDirectionWedgePlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let startEntryIndexInVoice: Int
    public let endEntryIndexInVoice: Int
    public let kind: VexDirectionWedgeKind
    public let placement: VexDirectionTextPlacementPlan?
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        startEntryIndexInVoice: Int,
        endEntryIndexInVoice: Int,
        kind: VexDirectionWedgeKind,
        placement: VexDirectionTextPlacementPlan?,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.startEntryIndexInVoice = startEntryIndexInVoice
        self.endEntryIndexInVoice = endEntryIndexInVoice
        self.kind = kind
        self.placement = placement
        self.sourceOrder = sourceOrder
    }
}

public enum VexOctaveShiftPositionPlan: Sendable {
    case top
    case bottom
}

public struct VexOctaveShiftPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let startEntryIndexInVoice: Int
    public let endEntryIndexInVoice: Int
    public let text: String
    public let superscript: String
    public let position: VexOctaveShiftPositionPlan
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        startEntryIndexInVoice: Int,
        endEntryIndexInVoice: Int,
        text: String,
        superscript: String,
        position: VexOctaveShiftPositionPlan,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.startEntryIndexInVoice = startEntryIndexInVoice
        self.endEntryIndexInVoice = endEntryIndexInVoice
        self.text = text
        self.superscript = superscript
        self.position = position
        self.sourceOrder = sourceOrder
    }
}

public enum VexPedalKindPlan: Sendable {
    case text
    case bracket
    case mixed
}

public struct VexPedalPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let startEntryIndexInVoice: Int
    public let endEntryIndexInVoice: Int
    public let kind: VexPedalKindPlan
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        startEntryIndexInVoice: Int,
        endEntryIndexInVoice: Int,
        kind: VexPedalKindPlan,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.startEntryIndexInVoice = startEntryIndexInVoice
        self.endEntryIndexInVoice = endEntryIndexInVoice
        self.kind = kind
        self.sourceOrder = sourceOrder
    }
}

public enum VexLyricConnectorKind: Sendable {
    case hyphen
    case extender
}

public struct VexLyricConnectorPlan: Sendable {
    public let startSystemIndex: Int
    public let startPartIndex: Int
    public let startMeasureIndexInPart: Int
    public let startVoice: Int
    public let startEntryIndexInVoice: Int
    public let endSystemIndex: Int
    public let endPartIndex: Int
    public let endMeasureIndexInPart: Int
    public let endVoice: Int
    public let endEntryIndexInVoice: Int
    public let verse: Int
    public let kind: VexLyricConnectorKind
    public let sourceOrder: Int

    public init(
        startSystemIndex: Int,
        startPartIndex: Int,
        startMeasureIndexInPart: Int,
        startVoice: Int,
        startEntryIndexInVoice: Int,
        endSystemIndex: Int,
        endPartIndex: Int,
        endMeasureIndexInPart: Int,
        endVoice: Int,
        endEntryIndexInVoice: Int,
        verse: Int,
        kind: VexLyricConnectorKind,
        sourceOrder: Int
    ) {
        self.startSystemIndex = startSystemIndex
        self.startPartIndex = startPartIndex
        self.startMeasureIndexInPart = startMeasureIndexInPart
        self.startVoice = startVoice
        self.startEntryIndexInVoice = startEntryIndexInVoice
        self.endSystemIndex = endSystemIndex
        self.endPartIndex = endPartIndex
        self.endMeasureIndexInPart = endMeasureIndexInPart
        self.endVoice = endVoice
        self.endEntryIndexInVoice = endEntryIndexInVoice
        self.verse = verse
        self.kind = kind
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
    public let chordSymbols: [VexChordSymbolPlan]
    public let directionTexts: [VexDirectionTextPlan]
    public let tempoMarks: [VexTempoMarkPlan]
    public let roadmapRepetitions: [VexRoadmapRepetitionPlan]
    public let directionWedges: [VexDirectionWedgePlan]
    public let octaveShiftSpanners: [VexOctaveShiftPlan]
    public let pedalMarkings: [VexPedalPlan]
    public let lyricConnectors: [VexLyricConnectorPlan]
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
        chordSymbols: [VexChordSymbolPlan],
        directionTexts: [VexDirectionTextPlan],
        tempoMarks: [VexTempoMarkPlan],
        roadmapRepetitions: [VexRoadmapRepetitionPlan],
        directionWedges: [VexDirectionWedgePlan],
        octaveShiftSpanners: [VexOctaveShiftPlan],
        pedalMarkings: [VexPedalPlan],
        lyricConnectors: [VexLyricConnectorPlan],
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
        self.chordSymbols = chordSymbols
        self.directionTexts = directionTexts
        self.tempoMarks = tempoMarks
        self.roadmapRepetitions = roadmapRepetitions
        self.directionWedges = directionWedges
        self.octaveShiftSpanners = octaveShiftSpanners
        self.pedalMarkings = pedalMarkings
        self.lyricConnectors = lyricConnectors
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
    public let chordSymbols: [VexFoundation.ChordSymbol]
    public let directionTexts: [VexFoundation.Annotation]
    public let tempoMarks: [StaveTempo]
    public let roadmapRepetitions: [StaveRepetition]
    public let directionWedges: [StaveHairpin]
    public let octaveShiftSpanners: [TextBracket]
    public let pedalMarkings: [PedalMarking]
    public let lyricConnectors: [VexFoundation.Annotation]
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
        chordSymbols: [VexFoundation.ChordSymbol],
        directionTexts: [VexFoundation.Annotation],
        tempoMarks: [StaveTempo],
        roadmapRepetitions: [StaveRepetition],
        directionWedges: [StaveHairpin],
        octaveShiftSpanners: [TextBracket],
        pedalMarkings: [PedalMarking],
        lyricConnectors: [VexFoundation.Annotation],
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
        self.chordSymbols = chordSymbols
        self.directionTexts = directionTexts
        self.tempoMarks = tempoMarks
        self.roadmapRepetitions = roadmapRepetitions
        self.directionWedges = directionWedges
        self.octaveShiftSpanners = octaveShiftSpanners
        self.pedalMarkings = pedalMarkings
        self.lyricConnectors = lyricConnectors
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
            let chordSymbols: [VexChordSymbolPlan]
            let directionTexts: [VexDirectionTextPlan]
            let tempoMarks: [VexTempoMarkPlan]
            let roadmapRepetitions: [VexRoadmapRepetitionPlan]
            let directionWedges: [VexDirectionWedgePlan]
            let octaveShiftSpanners: [VexOctaveShiftPlan]
            let pedalMarkings: [VexPedalPlan]
        }

        var noteEntryReferenceBySourceKey: [SourceNoteKey: NoteEntryReference] = [:]

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
                    lyrics: [],
                    chordSymbols: [],
                    directionTexts: [],
                    tempoMarks: [],
                    roadmapRepetitions: [],
                    directionWedges: [],
                    octaveShiftSpanners: [],
                    pedalMarkings: []
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
                    lyrics: [],
                    chordSymbols: [],
                    directionTexts: [],
                    tempoMarks: [],
                    roadmapRepetitions: [],
                    directionWedges: [],
                    octaveShiftSpanners: [],
                    pedalMarkings: []
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
                        noteEntryReferenceBySourceKey[
                            SourceNoteKey(
                                partIndex: laidOutMeasure.partIndex,
                                measureIndexInPart: laidOutMeasure.measureIndexInPart,
                                noteIndexInMeasure: noteIndex
                            )
                        ] = NoteEntryReference(
                            systemIndex: laidOutMeasure.systemIndex,
                            partIndex: laidOutMeasure.partIndex,
                            measureIndexInPart: laidOutMeasure.measureIndexInPart,
                            voice: voice,
                            entryIndexInVoice: entryIndex
                        )
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

            let chordSymbolPlans = buildChordSymbolPlans(
                systemIndex: laidOutMeasure.systemIndex,
                partIndex: laidOutMeasure.partIndex,
                measureIndexInPart: laidOutMeasure.measureIndexInPart,
                harmonyEvents: sourceMeasure.harmonyEvents,
                notePlans: notePlans
            )
            let directionTextPlans = buildDirectionTextPlans(
                systemIndex: laidOutMeasure.systemIndex,
                partIndex: laidOutMeasure.partIndex,
                measureIndexInPart: laidOutMeasure.measureIndexInPart,
                directionEvents: sourceMeasure.directionEvents,
                notePlans: notePlans
            )
            let directionExpressionPlans = buildDirectionExpressionPlans(
                systemIndex: laidOutMeasure.systemIndex,
                partIndex: laidOutMeasure.partIndex,
                measureIndexInPart: laidOutMeasure.measureIndexInPart,
                directionEvents: sourceMeasure.directionEvents,
                notePlans: notePlans
            )
            let tempoMarkPlans = buildDirectionTempoPlans(
                systemIndex: laidOutMeasure.systemIndex,
                partIndex: laidOutMeasure.partIndex,
                measureIndexInPart: laidOutMeasure.measureIndexInPart,
                directionEvents: sourceMeasure.directionEvents,
                notePlans: notePlans
            )
            let roadmapRepetitionPlans = buildRoadmapRepetitionPlans(
                systemIndex: laidOutMeasure.systemIndex,
                partIndex: laidOutMeasure.partIndex,
                measureIndexInPart: laidOutMeasure.measureIndexInPart,
                repetitionInstructions: sourceMeasure.repetitionInstructions,
                notePlans: notePlans
            )

            return MeasureRenderPlans(
                notes: notePlans,
                beams: beamPlans,
                tuplets: tupletPlans,
                ties: tiePlans,
                slurs: slurPlans,
                articulations: articulationPlans,
                lyrics: lyricPlans,
                chordSymbols: chordSymbolPlans,
                directionTexts: directionTextPlans,
                tempoMarks: tempoMarkPlans,
                roadmapRepetitions: roadmapRepetitionPlans,
                directionWedges: directionExpressionPlans.wedges,
                octaveShiftSpanners: directionExpressionPlans.octaveShifts,
                pedalMarkings: directionExpressionPlans.pedals
            )
        }
        let notes = measureRenderPlans.flatMap(\.notes)
        let beams = measureRenderPlans.flatMap(\.beams)
        let tuplets = measureRenderPlans.flatMap(\.tuplets)
        let ties = measureRenderPlans.flatMap(\.ties)
        let slurs = measureRenderPlans.flatMap(\.slurs)
        let articulations = measureRenderPlans.flatMap(\.articulations)
        let lyrics = measureRenderPlans.flatMap(\.lyrics)
        let chordSymbols = measureRenderPlans.flatMap(\.chordSymbols)
        let directionTexts = measureRenderPlans.flatMap(\.directionTexts)
        let tempoMarks = measureRenderPlans.flatMap(\.tempoMarks)
        let roadmapRepetitions = measureRenderPlans.flatMap(\.roadmapRepetitions)
        let directionWedges = measureRenderPlans.flatMap(\.directionWedges)
        let octaveShiftSpanners = measureRenderPlans.flatMap(\.octaveShiftSpanners)
        let pedalMarkings = measureRenderPlans.flatMap(\.pedalMarkings)
        let lyricConnectors = buildLyricConnectorPlans(
            score: score.score,
            noteEntryReferenceBySourceKey: noteEntryReferenceBySourceKey
        )

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
            chordSymbols: chordSymbols,
            directionTexts: directionTexts,
            tempoMarks: tempoMarks,
            roadmapRepetitions: roadmapRepetitions,
            directionWedges: directionWedges,
            octaveShiftSpanners: octaveShiftSpanners,
            pedalMarkings: pedalMarkings,
            lyricConnectors: lyricConnectors,
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
        struct GroupVoiceKey: Hashable {
            let systemIndex: Int
            let partIndex: Int
            let measureIndexInPart: Int
            let voice: Int
        }

        var createdVoices: [Voice] = []
        var createdNotes: [StaveNote] = []
        var createdBeams: [Beam] = []
        var createdTuplets: [Tuplet] = []
        var createdTies: [StaveTie] = []
        var createdSlurs: [Curve] = []
        var createdArticulations: [VexFoundation.Articulation] = []
        var createdLyrics: [VexFoundation.Annotation] = []
        var createdChordSymbols: [VexFoundation.ChordSymbol] = []
        var createdDirectionTexts: [VexFoundation.Annotation] = []
        var createdTempoMarks: [StaveTempo] = []
        var createdRoadmapRepetitions: [StaveRepetition] = []
        var createdDirectionWedges: [StaveHairpin] = []
        var createdOctaveShiftSpanners: [TextBracket] = []
        var createdPedalMarkings: [PedalMarking] = []
        var createdLyricConnectors: [VexFoundation.Annotation] = []
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
        let groupedChordSymbols = Dictionary(grouping: plan.chordSymbols) { chordPlan in
            NoteGroupKey(
                systemIndex: chordPlan.systemIndex,
                partIndex: chordPlan.partIndex,
                measureIndexInPart: chordPlan.measureIndexInPart
            )
        }
        let groupedDirectionTexts = Dictionary(grouping: plan.directionTexts) { directionPlan in
            NoteGroupKey(
                systemIndex: directionPlan.systemIndex,
                partIndex: directionPlan.partIndex,
                measureIndexInPart: directionPlan.measureIndexInPart
            )
        }
        let groupedTempoMarks = Dictionary(grouping: plan.tempoMarks) { tempoPlan in
            NoteGroupKey(
                systemIndex: tempoPlan.systemIndex,
                partIndex: tempoPlan.partIndex,
                measureIndexInPart: tempoPlan.measureIndexInPart
            )
        }
        let groupedRoadmapRepetitions = Dictionary(grouping: plan.roadmapRepetitions) { repetitionPlan in
            NoteGroupKey(
                systemIndex: repetitionPlan.systemIndex,
                partIndex: repetitionPlan.partIndex,
                measureIndexInPart: repetitionPlan.measureIndexInPart
            )
        }
        let groupedDirectionWedges = Dictionary(grouping: plan.directionWedges) { wedgePlan in
            NoteGroupKey(
                systemIndex: wedgePlan.systemIndex,
                partIndex: wedgePlan.partIndex,
                measureIndexInPart: wedgePlan.measureIndexInPart
            )
        }
        let groupedOctaveShiftSpanners = Dictionary(grouping: plan.octaveShiftSpanners) { shiftPlan in
            NoteGroupKey(
                systemIndex: shiftPlan.systemIndex,
                partIndex: shiftPlan.partIndex,
                measureIndexInPart: shiftPlan.measureIndexInPart
            )
        }
        let groupedPedalMarkings = Dictionary(grouping: plan.pedalMarkings) { pedalPlan in
            NoteGroupKey(
                systemIndex: pedalPlan.systemIndex,
                partIndex: pedalPlan.partIndex,
                measureIndexInPart: pedalPlan.measureIndexInPart
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

        var allNotesByEntryKey: [NoteEntryKey: StaveNote] = [:]
        var lyricVoiceOffsetByGroupVoice: [GroupVoiceKey: Int] = [:]
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
            let voiceLineOffsetByVoice: [Int: Int] = Dictionary(
                uniqueKeysWithValues: sortedVoices.enumerated().map { index, voice in
                    (voice, sortedVoices.count > 1 ? index : 0)
                }
            )
            for voice in sortedVoices {
                lyricVoiceOffsetByGroupVoice[
                    GroupVoiceKey(
                        systemIndex: groupKey.systemIndex,
                        partIndex: groupKey.partIndex,
                        measureIndexInPart: groupKey.measureIndexInPart,
                        voice: voice
                    )
                ] = voiceLineOffsetByVoice[voice, default: 0]
            }
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
                    allNotesByEntryKey[
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
                    if let position = articulationModifierPosition(for: articulationPlan.position)
                        ?? defaultArticulationModifierPosition(for: note) {
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
                    let voiceOffset = lyricVoiceOffsetByGroupVoice[
                        GroupVoiceKey(
                            systemIndex: lyricPlan.systemIndex,
                            partIndex: lyricPlan.partIndex,
                            measureIndexInPart: lyricPlan.measureIndexInPart,
                            voice: lyricPlan.voice
                        )
                    ] ?? 0
                    _ = annotation.setPosition(.below)
                    _ = annotation.setTextLine(
                        lyricTextLine(verse: lyricPlan.verse, voiceOffset: voiceOffset)
                    )
                    _ = note.addModifier(annotation, index: 0)
                    createdLyrics.append(annotation)
                }
            }

            if let chordSymbolPlans = groupedChordSymbols[groupKey] {
                let sortedChordSymbolPlans = chordSymbolPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                        return lhs.entryIndexInVoice < rhs.entryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for chordSymbolPlan in sortedChordSymbolPlans {
                    guard let note = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: chordSymbolPlan.systemIndex,
                            partIndex: chordSymbolPlan.partIndex,
                            measureIndexInPart: chordSymbolPlan.measureIndexInPart,
                            voice: chordSymbolPlan.voice,
                            entryIndexInVoice: chordSymbolPlan.entryIndexInVoice
                        )
                    ] else {
                        continue
                    }
                    let chordSymbol = factory.ChordSymbol(vJustify: .top, hJustify: .center)
                    _ = chordSymbol.addGlyphOrText(chordSymbolPlan.displayText)
                    _ = chordSymbol.setPosition(.above)
                    _ = note.addModifier(chordSymbol, index: 0)
                    createdChordSymbols.append(chordSymbol)
                }
            }

            if let directionTextPlans = groupedDirectionTexts[groupKey] {
                let sortedDirectionTextPlans = directionTextPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                        return lhs.entryIndexInVoice < rhs.entryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for directionTextPlan in sortedDirectionTextPlans {
                    guard let note = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: directionTextPlan.systemIndex,
                            partIndex: directionTextPlan.partIndex,
                            measureIndexInPart: directionTextPlan.measureIndexInPart,
                            voice: directionTextPlan.voice,
                            entryIndexInVoice: directionTextPlan.entryIndexInVoice
                        )
                    ] else {
                        continue
                    }

                    let verticalJustify = directionAnnotationVerticalJustify(for: directionTextPlan.placement)
                    let annotation = factory.Annotation(
                        text: directionTextPlan.text,
                        hJustify: .center,
                        vJustify: verticalJustify
                    )
                    if let position = directionAnnotationPosition(for: directionTextPlan.placement) {
                        _ = annotation.setPosition(position)
                    }
                    _ = note.addModifier(annotation, index: 0)
                    createdDirectionTexts.append(annotation)
                }
            }

            if let directionWedgePlans = groupedDirectionWedges[groupKey] {
                let sortedDirectionWedgePlans = directionWedgePlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.startEntryIndexInVoice != rhs.startEntryIndexInVoice {
                        return lhs.startEntryIndexInVoice < rhs.startEntryIndexInVoice
                    }
                    if lhs.endEntryIndexInVoice != rhs.endEntryIndexInVoice {
                        return lhs.endEntryIndexInVoice < rhs.endEntryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for wedgePlan in sortedDirectionWedgePlans {
                    guard let startNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: wedgePlan.systemIndex,
                            partIndex: wedgePlan.partIndex,
                            measureIndexInPart: wedgePlan.measureIndexInPart,
                            voice: wedgePlan.voice,
                            entryIndexInVoice: wedgePlan.startEntryIndexInVoice
                        )
                    ],
                    let endNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: wedgePlan.systemIndex,
                            partIndex: wedgePlan.partIndex,
                            measureIndexInPart: wedgePlan.measureIndexInPart,
                            voice: wedgePlan.voice,
                            entryIndexInVoice: wedgePlan.endEntryIndexInVoice
                        )
                    ] else {
                        continue
                    }

                    let wedge = StaveHairpin(
                        firstNote: startNote,
                        lastNote: endNote,
                        type: wedgeHairpinType(for: wedgePlan.kind)
                    )
                    if let position = directionWedgePosition(for: wedgePlan.placement) {
                        _ = wedge.setPosition(position)
                    }
                    createdDirectionWedges.append(wedge)
                }
            }

            if let octaveShiftPlans = groupedOctaveShiftSpanners[groupKey] {
                let sortedOctaveShiftPlans = octaveShiftPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.startEntryIndexInVoice != rhs.startEntryIndexInVoice {
                        return lhs.startEntryIndexInVoice < rhs.startEntryIndexInVoice
                    }
                    if lhs.endEntryIndexInVoice != rhs.endEntryIndexInVoice {
                        return lhs.endEntryIndexInVoice < rhs.endEntryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for octaveShiftPlan in sortedOctaveShiftPlans {
                    guard let startNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: octaveShiftPlan.systemIndex,
                            partIndex: octaveShiftPlan.partIndex,
                            measureIndexInPart: octaveShiftPlan.measureIndexInPart,
                            voice: octaveShiftPlan.voice,
                            entryIndexInVoice: octaveShiftPlan.startEntryIndexInVoice
                        )
                    ],
                    let endNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: octaveShiftPlan.systemIndex,
                            partIndex: octaveShiftPlan.partIndex,
                            measureIndexInPart: octaveShiftPlan.measureIndexInPart,
                            voice: octaveShiftPlan.voice,
                            entryIndexInVoice: octaveShiftPlan.endEntryIndexInVoice
                        )
                    ] else {
                        continue
                    }

                    let textBracket = factory.TextBracket(
                        from: startNote,
                        to: endNote,
                        text: octaveShiftPlan.text,
                        superscript: octaveShiftPlan.superscript,
                        position: textBracketPosition(for: octaveShiftPlan.position)
                    )
                    createdOctaveShiftSpanners.append(textBracket)
                }
            }

            if let pedalPlans = groupedPedalMarkings[groupKey] {
                let sortedPedalPlans = pedalPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.startEntryIndexInVoice != rhs.startEntryIndexInVoice {
                        return lhs.startEntryIndexInVoice < rhs.startEntryIndexInVoice
                    }
                    if lhs.endEntryIndexInVoice != rhs.endEntryIndexInVoice {
                        return lhs.endEntryIndexInVoice < rhs.endEntryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for pedalPlan in sortedPedalPlans {
                    guard let startNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: pedalPlan.systemIndex,
                            partIndex: pedalPlan.partIndex,
                            measureIndexInPart: pedalPlan.measureIndexInPart,
                            voice: pedalPlan.voice,
                            entryIndexInVoice: pedalPlan.startEntryIndexInVoice
                        )
                    ],
                    let endNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: pedalPlan.systemIndex,
                            partIndex: pedalPlan.partIndex,
                            measureIndexInPart: pedalPlan.measureIndexInPart,
                            voice: pedalPlan.voice,
                            entryIndexInVoice: pedalPlan.endEntryIndexInVoice
                        )
                    ] else {
                        continue
                    }
                    let pedal = factory.PedalMarking(
                        notes: [startNote, endNote],
                        type: pedalMarkingType(for: pedalPlan.kind)
                    )
                    createdPedalMarkings.append(pedal)
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

            if let tempoPlans = groupedTempoMarks[groupKey] {
                let sortedTempoPlans = tempoPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                        return lhs.entryIndexInVoice < rhs.entryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for tempoPlan in sortedTempoPlans {
                    guard let anchorNote = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: tempoPlan.systemIndex,
                            partIndex: tempoPlan.partIndex,
                            measureIndexInPart: tempoPlan.measureIndexInPart,
                            voice: tempoPlan.voice,
                            entryIndexInVoice: tempoPlan.entryIndexInVoice
                        )
                    ] else {
                        continue
                    }

                    let shiftBase = stave.getNoteStartX() - stave.getX()
                    let x = anchorNote.getAbsoluteX() - shiftBase
                    let tempoOptions = StaveTempoOptions(
                        bpm: tempoPlan.bpm,
                        duration: tempoPlan.duration,
                        dots: tempoPlan.dots
                    )
                    let tempoMark = StaveTempo(
                        tempo: tempoOptions,
                        x: x,
                        shiftY: -15
                    )
                    _ = tempoMark.setShiftX(0)
                    _ = stave.addModifier(tempoMark)
                    createdTempoMarks.append(tempoMark)
                }
            }

            if let roadmapPlans = groupedRoadmapRepetitions[groupKey] {
                let sortedRoadmapPlans = roadmapPlans.sorted { lhs, rhs in
                    if lhs.sourceOrder != rhs.sourceOrder {
                        return lhs.sourceOrder < rhs.sourceOrder
                    }
                    return roadmapRepetitionSortValue(for: lhs.kind)
                        < roadmapRepetitionSortValue(for: rhs.kind)
                }
                for roadmapPlan in sortedRoadmapPlans {
                    let shiftBase = stave.getNoteStartX() - stave.getX()
                    let x: Double
                    switch roadmapPlan.anchor {
                    case .leftEdge:
                        x = stave.getX() - shiftBase
                    case .rightEdge:
                        x = stave.getX()
                    case .entry(let voice, let entryIndexInVoice):
                        guard let anchorNote = notesByEntryKey[
                            NoteEntryKey(
                                systemIndex: groupKey.systemIndex,
                                partIndex: groupKey.partIndex,
                                measureIndexInPart: groupKey.measureIndexInPart,
                                voice: voice,
                                entryIndexInVoice: entryIndexInVoice
                            )
                        ] else {
                            continue
                        }
                        x = anchorNote.getAbsoluteX() - shiftBase
                    }
                    let repetition = StaveRepetition(
                        type: roadmapRepetitionType(for: roadmapPlan.kind),
                        x: x,
                        yShift: 0
                    )
                    _ = stave.addModifier(repetition)
                    createdRoadmapRepetitions.append(repetition)
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
                    guard let beam = factory.Beam(notes: stemmableNotes) else {
                        continue
                    }
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
                    guard let tuplet = factory.Tuplet(notes: tupletNotes, options: options) else {
                        continue
                    }
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

        let sortedLyricConnectors = plan.lyricConnectors.sorted { lhs, rhs in
            if lhs.startSystemIndex != rhs.startSystemIndex {
                return lhs.startSystemIndex < rhs.startSystemIndex
            }
            if lhs.startPartIndex != rhs.startPartIndex {
                return lhs.startPartIndex < rhs.startPartIndex
            }
            if lhs.startMeasureIndexInPart != rhs.startMeasureIndexInPart {
                return lhs.startMeasureIndexInPart < rhs.startMeasureIndexInPart
            }
            if lhs.startVoice != rhs.startVoice {
                return lhs.startVoice < rhs.startVoice
            }
            if lhs.startEntryIndexInVoice != rhs.startEntryIndexInVoice {
                return lhs.startEntryIndexInVoice < rhs.startEntryIndexInVoice
            }
            if lhs.verse != rhs.verse {
                return lhs.verse < rhs.verse
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }
        for connectorPlan in sortedLyricConnectors {
            let startKey = NoteEntryKey(
                systemIndex: connectorPlan.startSystemIndex,
                partIndex: connectorPlan.startPartIndex,
                measureIndexInPart: connectorPlan.startMeasureIndexInPart,
                voice: connectorPlan.startVoice,
                entryIndexInVoice: connectorPlan.startEntryIndexInVoice
            )
            let endKey = NoteEntryKey(
                systemIndex: connectorPlan.endSystemIndex,
                partIndex: connectorPlan.endPartIndex,
                measureIndexInPart: connectorPlan.endMeasureIndexInPart,
                voice: connectorPlan.endVoice,
                entryIndexInVoice: connectorPlan.endEntryIndexInVoice
            )
            guard let startNote = allNotesByEntryKey[startKey],
                  let endNote = allNotesByEntryKey[endKey],
                  !startNote.isRest(),
                  !endNote.isRest() else {
                continue
            }

            let startX = startNote.getNoteHeadEndX()
            let endX = endNote.getNoteHeadBeginX()
            let spanWidth = max(0, endX - startX)
            guard spanWidth >= 8 else {
                continue
            }

            let annotationText: String
            let hJustify: AnnotationHorizontalJustify
            let xShift: Double
            switch connectorPlan.kind {
            case .hyphen:
                annotationText = "-"
                hJustify = .center
                xShift = spanWidth / 2
            case .extender:
                annotationText = lyricExtenderText(forSpanWidth: spanWidth)
                hJustify = .left
                xShift = 4
            }
            guard !annotationText.isEmpty else {
                continue
            }

            let annotation = factory.Annotation(
                text: annotationText,
                hJustify: hJustify,
                vJustify: .bottom
            )
            let voiceOffset = lyricVoiceOffsetByGroupVoice[
                GroupVoiceKey(
                    systemIndex: connectorPlan.startSystemIndex,
                    partIndex: connectorPlan.startPartIndex,
                    measureIndexInPart: connectorPlan.startMeasureIndexInPart,
                    voice: connectorPlan.startVoice
                )
            ] ?? 0
            _ = annotation.setPosition(.below)
            _ = annotation.setTextLine(
                lyricTextLine(verse: connectorPlan.verse, voiceOffset: voiceOffset)
            )
            _ = annotation.setXShift(xShift)
            _ = startNote.addModifier(annotation, index: 0)
            createdLyricConnectors.append(annotation)
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
            chordSymbols: createdChordSymbols,
            directionTexts: createdDirectionTexts,
            tempoMarks: createdTempoMarks,
            roadmapRepetitions: createdRoadmapRepetitions,
            directionWedges: createdDirectionWedges,
            octaveShiftSpanners: createdOctaveShiftSpanners,
            pedalMarkings: createdPedalMarkings,
            lyricConnectors: createdLyricConnectors,
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
        try drawExecution(execution, on: context)
    }

    private func drawExecution(_ execution: VexFactoryExecution, on context: RenderContext) throws {
        _ = execution.factory.setContext(context)
        try execution.factory.draw()
        for wedge in execution.directionWedges {
            _ = wedge.setContext(context)
            try wedge.draw()
        }
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

    private struct SourceNoteKey: Hashable {
        let partIndex: Int
        let measureIndexInPart: Int
        let noteIndexInMeasure: Int
    }

    private struct NoteEntryReference: Hashable {
        let systemIndex: Int
        let partIndex: Int
        let measureIndexInPart: Int
        let voice: Int
        let entryIndexInVoice: Int
    }

    private struct DirectionExpressionPlanBundle {
        let wedges: [VexDirectionWedgePlan]
        let octaveShifts: [VexOctaveShiftPlan]
        let pedals: [VexPedalPlan]

        static let empty = DirectionExpressionPlanBundle(
            wedges: [],
            octaveShifts: [],
            pedals: []
        )
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

    private func buildChordSymbolPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        harmonyEvents: [MusicDisplayKitModel.HarmonyEvent],
        notePlans: [VexNotePlan]
    ) -> [VexChordSymbolPlan] {
        let anchorCandidates = notePlans
            .filter { !$0.isRest }
            .sorted { lhs, rhs in
                if lhs.onsetDivisions != rhs.onsetDivisions {
                    return lhs.onsetDivisions < rhs.onsetDivisions
                }
                if lhs.voice != rhs.voice {
                    return lhs.voice < rhs.voice
                }
                return lhs.sourceOrder < rhs.sourceOrder
            }

        guard !anchorCandidates.isEmpty else {
            return []
        }

        var plans: [VexChordSymbolPlan] = []
        for (sourceOrder, harmony) in harmonyEvents.enumerated() {
            guard let displayText = harmonyDisplayText(for: harmony) else {
                continue
            }
            let onset = max(0, harmony.onsetDivisions)
            let anchor = anchorCandidates.first(where: { $0.onsetDivisions >= onset })
                ?? anchorCandidates.last
            guard let anchor else {
                continue
            }
            plans.append(
                VexChordSymbolPlan(
                    systemIndex: systemIndex,
                    partIndex: partIndex,
                    measureIndexInPart: measureIndexInPart,
                    voice: anchor.voice,
                    entryIndexInVoice: anchor.entryIndexInVoice,
                    displayText: displayText,
                    sourceOrder: sourceOrder
                )
            )
        }

        return plans.sorted { lhs, rhs in
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                return lhs.entryIndexInVoice < rhs.entryIndexInVoice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }
    }

    private func buildDirectionTextPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        directionEvents: [MusicDisplayKitModel.DirectionEvent],
        notePlans: [VexNotePlan]
    ) -> [VexDirectionTextPlan] {
        guard !notePlans.isEmpty else {
            return []
        }
        let sortedNotePlans = notePlans.sorted { lhs, rhs in
            if lhs.onsetDivisions != rhs.onsetDivisions {
                return lhs.onsetDivisions < rhs.onsetDivisions
            }
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }

        var plans: [VexDirectionTextPlan] = []
        var sourceOrder = 0
        for directionEvent in directionEvents {
            let dynamicTexts = directionEvent.dynamics.compactMap(directionTextValue(for:))
            let wordTexts = directionEvent.words.compactMap(directionTextValue(for:))
            let rehearsalText = directionTextValue(for: directionEvent.rehearsal)
            guard !dynamicTexts.isEmpty || !wordTexts.isEmpty || rehearsalText != nil else {
                continue
            }

            let requestedVoice = directionEvent.voice.flatMap { $0 > 0 ? $0 : nil }
            let anchorOnset = max(0, directionEvent.onsetDivisions + directionEvent.offsetDivisions)
            guard let anchor = directionAnchorNotePlan(
                from: sortedNotePlans,
                onsetDivisions: anchorOnset,
                    requestedVoice: requestedVoice
            ) else {
                continue
            }

            let explicitPlacement = directionTextPlacementPlan(from: directionEvent.placement)
            let dynamicPlacement = explicitPlacement ?? .below
            let wordsPlacement = explicitPlacement ?? .above

            for text in dynamicTexts {
                plans.append(
                    VexDirectionTextPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: anchor.voice,
                        entryIndexInVoice: anchor.entryIndexInVoice,
                        text: text,
                        placement: dynamicPlacement,
                        sourceOrder: sourceOrder
                    )
                )
                sourceOrder += 1
            }

            for text in wordTexts {
                plans.append(
                    VexDirectionTextPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: anchor.voice,
                        entryIndexInVoice: anchor.entryIndexInVoice,
                        text: text,
                        placement: wordsPlacement,
                        sourceOrder: sourceOrder
                    )
                )
                sourceOrder += 1
            }

            if let rehearsalText {
                plans.append(
                    VexDirectionTextPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: anchor.voice,
                        entryIndexInVoice: anchor.entryIndexInVoice,
                        text: rehearsalText,
                        placement: wordsPlacement,
                        sourceOrder: sourceOrder
                    )
                )
                sourceOrder += 1
            }
        }

        return plans.sorted { lhs, rhs in
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                return lhs.entryIndexInVoice < rhs.entryIndexInVoice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }
    }

    private func buildDirectionTempoPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        directionEvents: [MusicDisplayKitModel.DirectionEvent],
        notePlans: [VexNotePlan]
    ) -> [VexTempoMarkPlan] {
        guard !notePlans.isEmpty else {
            return []
        }
        let sortedNotePlans = notePlans.sorted { lhs, rhs in
            if lhs.onsetDivisions != rhs.onsetDivisions {
                return lhs.onsetDivisions < rhs.onsetDivisions
            }
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }

        var plans: [VexTempoMarkPlan] = []
        var sourceOrder = 0
        for directionEvent in directionEvents {
            let requestedVoice = directionEvent.voice.flatMap { $0 > 0 ? $0 : nil }
            let anchorOnset = max(0, directionEvent.onsetDivisions + directionEvent.offsetDivisions)
            guard let anchor = directionAnchorNotePlan(
                from: sortedNotePlans,
                onsetDivisions: anchorOnset,
                requestedVoice: requestedVoice
            ) else {
                continue
            }

            if let metronomePlan = metronomeTempoPlan(
                from: directionEvent.metronome,
                fallbackSoundTempo: directionEvent.soundTempo
            ) {
                plans.append(
                    VexTempoMarkPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: anchor.voice,
                        entryIndexInVoice: anchor.entryIndexInVoice,
                        bpm: metronomePlan.bpm,
                        duration: metronomePlan.duration,
                        dots: metronomePlan.dots,
                        sourceOrder: sourceOrder
                    )
                )
                sourceOrder += 1
                continue
            }

            if let soundPlan = soundTempoPlan(from: directionEvent.soundTempo) {
                plans.append(
                    VexTempoMarkPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: anchor.voice,
                        entryIndexInVoice: anchor.entryIndexInVoice,
                        bpm: soundPlan.bpm,
                        duration: soundPlan.duration,
                        dots: soundPlan.dots,
                        sourceOrder: sourceOrder
                    )
                )
                sourceOrder += 1
            }
        }

        return plans.sorted { lhs, rhs in
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                return lhs.entryIndexInVoice < rhs.entryIndexInVoice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }
    }

    private func buildRoadmapRepetitionPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        repetitionInstructions: [MusicDisplayKitModel.RepetitionInstruction],
        notePlans: [VexNotePlan]
    ) -> [VexRoadmapRepetitionPlan] {
        struct PlanKey: Hashable {
            let kind: VexRoadmapRepetitionKind
            let anchor: VexRoadmapRepetitionAnchor
        }
        enum Edge {
            case left
            case right
        }

        let roadmapInstructions = repetitionInstructions.filter { instruction in
            switch instruction.kind {
            case .segno, .coda, .daCapo, .dalSegno, .toCoda, .fine, .alFine, .alCoda:
                return true
            default:
                return false
            }
        }
        guard !roadmapInstructions.isEmpty else {
            return []
        }

        let sortedNotePlans = notePlans.sorted { lhs, rhs in
            if lhs.onsetDivisions != rhs.onsetDivisions {
                return lhs.onsetDivisions < rhs.onsetDivisions
            }
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                return lhs.entryIndexInVoice < rhs.entryIndexInVoice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }

        func edge(from location: String?) -> Edge? {
            guard let location = location?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() else {
                return nil
            }
            switch location {
            case "left", "begin", "start":
                return .left
            case "right", "end", "stop":
                return .right
            default:
                return nil
            }
        }

        func anchorForOnset(_ onset: Int, fallback: VexRoadmapRepetitionAnchor) -> VexRoadmapRepetitionAnchor {
            if let anchor = directionAnchorNotePlan(
                from: sortedNotePlans,
                onsetDivisions: onset,
                requestedVoice: nil
            ) {
                return .entry(voice: anchor.voice, entryIndexInVoice: anchor.entryIndexInVoice)
            }
            return fallback
        }

        func instructionSortValue(_ instruction: MusicDisplayKitModel.RepetitionInstruction) -> Int {
            switch instruction.kind {
            case .dalSegno:
                return 0
            case .daCapo:
                return 1
            case .segno:
                return 2
            case .coda:
                return 3
            case .toCoda:
                return 4
            case .fine:
                return 5
            case .alCoda:
                return 6
            case .alFine:
                return 7
            default:
                return 8
            }
        }

        var plans: [VexRoadmapRepetitionPlan] = []
        var seen: Set<PlanKey> = []
        var sourceOrder = 0
        let instructionsByOnset = Dictionary(grouping: roadmapInstructions) { instruction in
            max(0, instruction.onsetDivisions)
        }
        for onset in instructionsByOnset.keys.sorted() {
            guard var onsetInstructions = instructionsByOnset[onset], !onsetInstructions.isEmpty else {
                continue
            }
            onsetInstructions.sort { lhs, rhs in
                let lhsSort = instructionSortValue(lhs)
                let rhsSort = instructionSortValue(rhs)
                if lhsSort != rhsSort {
                    return lhsSort < rhsSort
                }
                return (lhs.text ?? "") < (rhs.text ?? "")
            }

            let hasAlCoda = onsetInstructions.contains { $0.kind == .alCoda }
            let hasAlFine = onsetInstructions.contains { $0.kind == .alFine }
            let hasDalSegno = onsetInstructions.contains { $0.kind == .dalSegno }
            let hasDaCapo = onsetInstructions.contains { $0.kind == .daCapo }

            if hasDalSegno || hasDaCapo {
                let commandKind: VexRoadmapRepetitionKind
                if hasDalSegno {
                    if hasAlCoda {
                        commandKind = .dsAlCoda
                    } else if hasAlFine {
                        commandKind = .dsAlFine
                    } else {
                        commandKind = .ds
                    }
                } else if hasAlCoda {
                    commandKind = .dcAlCoda
                } else if hasAlFine {
                    commandKind = .dcAlFine
                } else {
                    commandKind = .dc
                }

                let commandAnchor = anchorForOnset(onset, fallback: .leftEdge)
                let key = PlanKey(kind: commandKind, anchor: commandAnchor)
                if !seen.contains(key) {
                    seen.insert(key)
                    plans.append(
                        VexRoadmapRepetitionPlan(
                            systemIndex: systemIndex,
                            partIndex: partIndex,
                            measureIndexInPart: measureIndexInPart,
                            kind: commandKind,
                            anchor: commandAnchor,
                            sourceOrder: sourceOrder
                        )
                    )
                    sourceOrder += 1
                }
            }

            for instruction in onsetInstructions {
                let kind: VexRoadmapRepetitionKind?
                let anchor: VexRoadmapRepetitionAnchor

                switch instruction.kind {
                case .segno:
                    switch edge(from: instruction.location) {
                    case .right:
                        kind = .segnoRight
                        anchor = .rightEdge
                    case .left:
                        kind = .segnoLeft
                        anchor = .leftEdge
                    case .none:
                        kind = .segnoLeft
                        anchor = anchorForOnset(onset, fallback: .leftEdge)
                    }
                case .coda:
                    switch edge(from: instruction.location) {
                    case .right:
                        kind = .codaRight
                        anchor = .rightEdge
                    case .left:
                        kind = .codaLeft
                        anchor = .leftEdge
                    case .none:
                        kind = .codaLeft
                        anchor = anchorForOnset(onset, fallback: .leftEdge)
                    }
                case .toCoda:
                    kind = .toCoda
                    anchor = anchorForOnset(onset, fallback: .leftEdge)
                case .fine:
                    kind = .fine
                    anchor = anchorForOnset(onset, fallback: .leftEdge)
                case .daCapo, .dalSegno, .alCoda, .alFine:
                    kind = nil
                    anchor = .leftEdge
                default:
                    kind = nil
                    anchor = .leftEdge
                }

                guard let kind else {
                    continue
                }
                let key = PlanKey(kind: kind, anchor: anchor)
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)
                plans.append(
                    VexRoadmapRepetitionPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        kind: kind,
                        anchor: anchor,
                        sourceOrder: sourceOrder
                    )
                )
                sourceOrder += 1
            }
        }

        return plans.sorted { lhs, rhs in
            if lhs.sourceOrder != rhs.sourceOrder {
                return lhs.sourceOrder < rhs.sourceOrder
            }
            return roadmapRepetitionSortValue(for: lhs.kind)
                < roadmapRepetitionSortValue(for: rhs.kind)
        }
    }

    private func directionAnchorNotePlan(
        from sortedNotePlans: [VexNotePlan],
        onsetDivisions: Int,
        requestedVoice: Int?
    ) -> VexNotePlan? {
        let voiceFiltered = requestedVoice.map { voice in
            sortedNotePlans.filter { $0.voice == voice }
        } ?? sortedNotePlans

        let source = voiceFiltered.isEmpty ? sortedNotePlans : voiceFiltered
        let preferred = source.filter { !$0.isRest }
        let candidates = preferred.isEmpty ? source : preferred

        return candidates.first(where: { $0.onsetDivisions >= onsetDivisions })
            ?? candidates.last
    }

    private func directionTerminalNotePlan(
        from sortedNotePlans: [VexNotePlan],
        requestedVoice: Int?
    ) -> VexNotePlan? {
        let voiceFiltered = requestedVoice.map { voice in
            sortedNotePlans.filter { $0.voice == voice }
        } ?? sortedNotePlans

        let source = voiceFiltered.isEmpty ? sortedNotePlans : voiceFiltered
        let preferred = source.filter { !$0.isRest }
        let candidates = preferred.isEmpty ? source : preferred

        return candidates.last
    }

    private func buildDirectionExpressionPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        directionEvents: [MusicDisplayKitModel.DirectionEvent],
        notePlans: [VexNotePlan]
    ) -> DirectionExpressionPlanBundle {
        struct AnchoredDirectionEvent {
            let sourceOrder: Int
            let directionEvent: MusicDisplayKitModel.DirectionEvent
            let anchorOnset: Int
            let anchor: VexNotePlan
            let placement: VexDirectionTextPlacementPlan?
        }
        struct WedgeSpanKey: Hashable {
            let number: Int
            let voice: Int
            let staff: Int?
        }
        struct OpenWedgeState {
            let anchor: VexNotePlan
            let kind: VexDirectionWedgeKind
            let placement: VexDirectionTextPlacementPlan?
            let sourceOrder: Int
        }
        struct OctaveSpanKey: Hashable {
            let number: Int
            let voice: Int
            let staff: Int?
        }
        struct OpenOctaveShiftState {
            let anchor: VexNotePlan
            let text: String
            let superscript: String
            let position: VexOctaveShiftPositionPlan
            let sourceOrder: Int
        }
        struct PedalSpanKey: Hashable {
            let voice: Int
            let staff: Int?
        }
        struct OpenPedalState {
            let anchor: VexNotePlan
            let kind: VexPedalKindPlan
            let sourceOrder: Int
        }

        guard !notePlans.isEmpty else {
            return .empty
        }

        let sortedNotePlans = notePlans.sorted { lhs, rhs in
            if lhs.onsetDivisions != rhs.onsetDivisions {
                return lhs.onsetDivisions < rhs.onsetDivisions
            }
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                return lhs.entryIndexInVoice < rhs.entryIndexInVoice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }

        let anchoredEvents: [AnchoredDirectionEvent] = directionEvents.enumerated().compactMap { sourceOrder, directionEvent in
            let requestedVoice = directionEvent.voice.flatMap { $0 > 0 ? $0 : nil }
            let anchorOnset = max(0, directionEvent.onsetDivisions + directionEvent.offsetDivisions)
            guard let anchor = directionAnchorNotePlan(
                from: sortedNotePlans,
                onsetDivisions: anchorOnset,
                requestedVoice: requestedVoice
            ) else {
                return nil
            }
            return AnchoredDirectionEvent(
                sourceOrder: sourceOrder,
                directionEvent: directionEvent,
                anchorOnset: anchorOnset,
                anchor: anchor,
                placement: directionTextPlacementPlan(from: directionEvent.placement)
            )
        }.sorted { lhs, rhs in
            if lhs.anchorOnset != rhs.anchorOnset {
                return lhs.anchorOnset < rhs.anchorOnset
            }
            if lhs.anchor.voice != rhs.anchor.voice {
                return lhs.anchor.voice < rhs.anchor.voice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }

        guard !anchoredEvents.isEmpty else {
            return .empty
        }

        func spanAnchors(start: VexNotePlan, end: VexNotePlan) -> (VexNotePlan, VexNotePlan) {
            if directionSpanSortsBefore(start, end) {
                return (start, end)
            }
            return (end, start)
        }

        var openWedges: [WedgeSpanKey: OpenWedgeState] = [:]
        var openOctaveShifts: [OctaveSpanKey: OpenOctaveShiftState] = [:]
        var openPedals: [PedalSpanKey: OpenPedalState] = [:]
        var wedgePlans: [VexDirectionWedgePlan] = []
        var octaveShiftPlans: [VexOctaveShiftPlan] = []
        var pedalPlans: [VexPedalPlan] = []
        var wedgeSourceOrder = 0
        var octaveSourceOrder = 0
        var pedalSourceOrder = 0

        for anchoredEvent in anchoredEvents {
            let directionEvent = anchoredEvent.directionEvent
            let anchor = anchoredEvent.anchor

            for wedge in directionEvent.wedges {
                let key = WedgeSpanKey(
                    number: max(1, wedge.number ?? 1),
                    voice: anchor.voice,
                    staff: directionEvent.staff
                )
                switch wedge.type {
                case .crescendo, .diminuendo:
                    if let open = openWedges.removeValue(forKey: key) {
                        let (startAnchor, endAnchor) = spanAnchors(start: open.anchor, end: anchor)
                        wedgePlans.append(
                            VexDirectionWedgePlan(
                                systemIndex: systemIndex,
                                partIndex: partIndex,
                                measureIndexInPart: measureIndexInPart,
                                voice: startAnchor.voice,
                                startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                                endEntryIndexInVoice: endAnchor.entryIndexInVoice,
                                kind: open.kind,
                                placement: open.placement,
                                sourceOrder: open.sourceOrder
                            )
                        )
                    }
                    let kind: VexDirectionWedgeKind = wedge.type == .crescendo ? .crescendo : .decrescendo
                    openWedges[key] = OpenWedgeState(
                        anchor: anchor,
                        kind: kind,
                        placement: anchoredEvent.placement,
                        sourceOrder: wedgeSourceOrder
                    )
                    wedgeSourceOrder += 1
                case .stop:
                    if let open = openWedges.removeValue(forKey: key) {
                        let (startAnchor, endAnchor) = spanAnchors(start: open.anchor, end: anchor)
                        wedgePlans.append(
                            VexDirectionWedgePlan(
                                systemIndex: systemIndex,
                                partIndex: partIndex,
                                measureIndexInPart: measureIndexInPart,
                                voice: startAnchor.voice,
                                startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                                endEntryIndexInVoice: endAnchor.entryIndexInVoice,
                                kind: open.kind,
                                placement: open.placement,
                                sourceOrder: open.sourceOrder
                            )
                        )
                    }
                case .continue, .unknown:
                    continue
                }
            }

            for octaveShift in directionEvent.octaveShifts {
                let key = OctaveSpanKey(
                    number: max(1, octaveShift.number ?? 1),
                    voice: anchor.voice,
                    staff: directionEvent.staff
                )
                switch octaveShift.type {
                case .up, .down:
                    if let open = openOctaveShifts.removeValue(forKey: key) {
                        let (startAnchor, endAnchor) = spanAnchors(start: open.anchor, end: anchor)
                        octaveShiftPlans.append(
                            VexOctaveShiftPlan(
                                systemIndex: systemIndex,
                                partIndex: partIndex,
                                measureIndexInPart: measureIndexInPart,
                                voice: startAnchor.voice,
                                startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                                endEntryIndexInVoice: endAnchor.entryIndexInVoice,
                                text: open.text,
                                superscript: open.superscript,
                                position: open.position,
                                sourceOrder: open.sourceOrder
                            )
                        )
                    }
                    guard let text = octaveShiftText(for: octaveShift.type, size: octaveShift.size) else {
                        continue
                    }
                    openOctaveShifts[key] = OpenOctaveShiftState(
                        anchor: anchor,
                        text: text.text,
                        superscript: text.superscript,
                        position: octaveShiftPositionPlan(type: octaveShift.type, placement: anchoredEvent.placement),
                        sourceOrder: octaveSourceOrder
                    )
                    octaveSourceOrder += 1
                case .stop:
                    if let open = openOctaveShifts.removeValue(forKey: key) {
                        let (startAnchor, endAnchor) = spanAnchors(start: open.anchor, end: anchor)
                        octaveShiftPlans.append(
                            VexOctaveShiftPlan(
                                systemIndex: systemIndex,
                                partIndex: partIndex,
                                measureIndexInPart: measureIndexInPart,
                                voice: startAnchor.voice,
                                startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                                endEntryIndexInVoice: endAnchor.entryIndexInVoice,
                                text: open.text,
                                superscript: open.superscript,
                                position: open.position,
                                sourceOrder: open.sourceOrder
                            )
                        )
                    }
                case .continue, .unknown:
                    continue
                }
            }

            for pedal in directionEvent.pedals {
                let key = PedalSpanKey(
                    voice: anchor.voice,
                    staff: directionEvent.staff
                )
                let kind = pedalKindPlan(from: pedal)
                switch pedal.type {
                case .start, .resume:
                    if let open = openPedals.removeValue(forKey: key) {
                        let (startAnchor, endAnchor) = spanAnchors(start: open.anchor, end: anchor)
                        pedalPlans.append(
                            VexPedalPlan(
                                systemIndex: systemIndex,
                                partIndex: partIndex,
                                measureIndexInPart: measureIndexInPart,
                                voice: startAnchor.voice,
                                startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                                endEntryIndexInVoice: endAnchor.entryIndexInVoice,
                                kind: open.kind,
                                sourceOrder: open.sourceOrder
                            )
                        )
                    }
                    openPedals[key] = OpenPedalState(
                        anchor: anchor,
                        kind: kind,
                        sourceOrder: pedalSourceOrder
                    )
                    pedalSourceOrder += 1
                case .change:
                    if let open = openPedals.removeValue(forKey: key) {
                        let (startAnchor, endAnchor) = spanAnchors(start: open.anchor, end: anchor)
                        pedalPlans.append(
                            VexPedalPlan(
                                systemIndex: systemIndex,
                                partIndex: partIndex,
                                measureIndexInPart: measureIndexInPart,
                                voice: startAnchor.voice,
                                startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                                endEntryIndexInVoice: endAnchor.entryIndexInVoice,
                                kind: open.kind,
                                sourceOrder: open.sourceOrder
                            )
                        )
                    }
                    openPedals[key] = OpenPedalState(
                        anchor: anchor,
                        kind: kind,
                        sourceOrder: pedalSourceOrder
                    )
                    pedalSourceOrder += 1
                case .stop, .discontinue:
                    if let open = openPedals.removeValue(forKey: key) {
                        let (startAnchor, endAnchor) = spanAnchors(start: open.anchor, end: anchor)
                        pedalPlans.append(
                            VexPedalPlan(
                                systemIndex: systemIndex,
                                partIndex: partIndex,
                                measureIndexInPart: measureIndexInPart,
                                voice: startAnchor.voice,
                                startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                                endEntryIndexInVoice: endAnchor.entryIndexInVoice,
                                kind: open.kind,
                                sourceOrder: open.sourceOrder
                            )
                        )
                    }
                case .continue, .unknown:
                    continue
                }
            }
        }

        for (key, open) in openWedges.sorted(by: { lhs, rhs in
            if lhs.key.voice != rhs.key.voice {
                return lhs.key.voice < rhs.key.voice
            }
            if lhs.key.number != rhs.key.number {
                return lhs.key.number < rhs.key.number
            }
            return optionalNumberSortValue(lhs.key.staff) < optionalNumberSortValue(rhs.key.staff)
        }) {
            guard let endAnchor = directionTerminalNotePlan(from: sortedNotePlans, requestedVoice: key.voice) else {
                continue
            }
            let (startAnchor, normalizedEndAnchor) = spanAnchors(start: open.anchor, end: endAnchor)
            wedgePlans.append(
                VexDirectionWedgePlan(
                    systemIndex: systemIndex,
                    partIndex: partIndex,
                    measureIndexInPart: measureIndexInPart,
                    voice: startAnchor.voice,
                    startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                    endEntryIndexInVoice: normalizedEndAnchor.entryIndexInVoice,
                    kind: open.kind,
                    placement: open.placement,
                    sourceOrder: open.sourceOrder
                )
            )
        }

        for (key, open) in openOctaveShifts.sorted(by: { lhs, rhs in
            if lhs.key.voice != rhs.key.voice {
                return lhs.key.voice < rhs.key.voice
            }
            if lhs.key.number != rhs.key.number {
                return lhs.key.number < rhs.key.number
            }
            return optionalNumberSortValue(lhs.key.staff) < optionalNumberSortValue(rhs.key.staff)
        }) {
            guard let endAnchor = directionTerminalNotePlan(from: sortedNotePlans, requestedVoice: key.voice) else {
                continue
            }
            let (startAnchor, normalizedEndAnchor) = spanAnchors(start: open.anchor, end: endAnchor)
            octaveShiftPlans.append(
                VexOctaveShiftPlan(
                    systemIndex: systemIndex,
                    partIndex: partIndex,
                    measureIndexInPart: measureIndexInPart,
                    voice: startAnchor.voice,
                    startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                    endEntryIndexInVoice: normalizedEndAnchor.entryIndexInVoice,
                    text: open.text,
                    superscript: open.superscript,
                    position: open.position,
                    sourceOrder: open.sourceOrder
                )
            )
        }

        for (key, open) in openPedals.sorted(by: { lhs, rhs in
            if lhs.key.voice != rhs.key.voice {
                return lhs.key.voice < rhs.key.voice
            }
            return optionalNumberSortValue(lhs.key.staff) < optionalNumberSortValue(rhs.key.staff)
        }) {
            guard let endAnchor = directionTerminalNotePlan(from: sortedNotePlans, requestedVoice: key.voice) else {
                continue
            }
            let (startAnchor, normalizedEndAnchor) = spanAnchors(start: open.anchor, end: endAnchor)
            pedalPlans.append(
                VexPedalPlan(
                    systemIndex: systemIndex,
                    partIndex: partIndex,
                    measureIndexInPart: measureIndexInPart,
                    voice: startAnchor.voice,
                    startEntryIndexInVoice: startAnchor.entryIndexInVoice,
                    endEntryIndexInVoice: normalizedEndAnchor.entryIndexInVoice,
                    kind: open.kind,
                    sourceOrder: open.sourceOrder
                )
            )
        }

        return DirectionExpressionPlanBundle(
            wedges: wedgePlans.sorted { lhs, rhs in
                if lhs.voice != rhs.voice {
                    return lhs.voice < rhs.voice
                }
                if lhs.startEntryIndexInVoice != rhs.startEntryIndexInVoice {
                    return lhs.startEntryIndexInVoice < rhs.startEntryIndexInVoice
                }
                if lhs.endEntryIndexInVoice != rhs.endEntryIndexInVoice {
                    return lhs.endEntryIndexInVoice < rhs.endEntryIndexInVoice
                }
                return lhs.sourceOrder < rhs.sourceOrder
            },
            octaveShifts: octaveShiftPlans.sorted { lhs, rhs in
                if lhs.voice != rhs.voice {
                    return lhs.voice < rhs.voice
                }
                if lhs.startEntryIndexInVoice != rhs.startEntryIndexInVoice {
                    return lhs.startEntryIndexInVoice < rhs.startEntryIndexInVoice
                }
                if lhs.endEntryIndexInVoice != rhs.endEntryIndexInVoice {
                    return lhs.endEntryIndexInVoice < rhs.endEntryIndexInVoice
                }
                return lhs.sourceOrder < rhs.sourceOrder
            },
            pedals: pedalPlans.sorted { lhs, rhs in
                if lhs.voice != rhs.voice {
                    return lhs.voice < rhs.voice
                }
                if lhs.startEntryIndexInVoice != rhs.startEntryIndexInVoice {
                    return lhs.startEntryIndexInVoice < rhs.startEntryIndexInVoice
                }
                if lhs.endEntryIndexInVoice != rhs.endEntryIndexInVoice {
                    return lhs.endEntryIndexInVoice < rhs.endEntryIndexInVoice
                }
                return lhs.sourceOrder < rhs.sourceOrder
            }
        )
    }

    private func buildLyricConnectorPlans(
        score: MusicDisplayKitModel.Score,
        noteEntryReferenceBySourceKey: [SourceNoteKey: NoteEntryReference]
    ) -> [VexLyricConnectorPlan] {
        struct TimelineNote {
            let measureIndexInPart: Int
            let noteIndexInMeasure: Int
            let voice: Int
            let onsetDivisions: Int
            let sourceOrder: Int
            let note: MusicDisplayKitModel.NoteEvent
        }
        struct ConnectorKey: Hashable {
            let start: NoteEntryReference
            let end: NoteEntryReference
            let verse: Int
            let kind: VexLyricConnectorKind
        }

        var plans: [VexLyricConnectorPlan] = []
        var seen: Set<ConnectorKey> = []
        var sourceOrder = 0

        for (partIndex, part) in score.parts.enumerated() {
            var timelineByVoice: [Int: [TimelineNote]] = [:]
            for (measureIndexInPart, measure) in part.measures.enumerated() {
                for (noteIndex, note) in measure.noteEvents.enumerated() where !note.isGrace {
                    let voice = max(1, note.voice)
                    timelineByVoice[voice, default: []].append(
                        TimelineNote(
                            measureIndexInPart: measureIndexInPart,
                            noteIndexInMeasure: noteIndex,
                            voice: voice,
                            onsetDivisions: max(0, note.onsetDivisions),
                            sourceOrder: noteIndex,
                            note: note
                        )
                    )
                }
            }

            for voice in timelineByVoice.keys.sorted() {
                guard var timeline = timelineByVoice[voice], !timeline.isEmpty else {
                    continue
                }
                timeline.sort { lhs, rhs in
                    if lhs.measureIndexInPart != rhs.measureIndexInPart {
                        return lhs.measureIndexInPart < rhs.measureIndexInPart
                    }
                    if lhs.onsetDivisions != rhs.onsetDivisions {
                        return lhs.onsetDivisions < rhs.onsetDivisions
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }

                for (timelineIndex, item) in timeline.enumerated() {
                    let startKey = SourceNoteKey(
                        partIndex: partIndex,
                        measureIndexInPart: item.measureIndexInPart,
                        noteIndexInMeasure: item.noteIndexInMeasure
                    )
                    guard let startRef = noteEntryReferenceBySourceKey[startKey] else {
                        continue
                    }

                    for lyric in item.note.lyrics {
                        let verse = max(1, lyric.number)
                        let normalizedSyllabic = lyric.syllabic?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .lowercased()

                        if lyricText(for: lyric) != nil,
                           normalizedSyllabic == "begin" || normalizedSyllabic == "middle" {
                            let nextLyric = timeline[(timelineIndex + 1)...].first { candidate in
                                candidate.note.lyrics.contains(where: { candidateLyric in
                                    max(1, candidateLyric.number) == verse
                                        && lyricText(for: candidateLyric) != nil
                                })
                            }
                            if let nextLyric {
                            let endKey = SourceNoteKey(
                                partIndex: partIndex,
                                measureIndexInPart: nextLyric.measureIndexInPart,
                                noteIndexInMeasure: nextLyric.noteIndexInMeasure
                            )
                            if let endRef = noteEntryReferenceBySourceKey[endKey],
                               startRef != endRef {
                                let connectorKey = ConnectorKey(
                                    start: startRef,
                                    end: endRef,
                                    verse: verse,
                                    kind: .hyphen
                                )
                                if !seen.contains(connectorKey) {
                                    seen.insert(connectorKey)
                                    plans.append(
                                        VexLyricConnectorPlan(
                                            startSystemIndex: startRef.systemIndex,
                                            startPartIndex: startRef.partIndex,
                                            startMeasureIndexInPart: startRef.measureIndexInPart,
                                            startVoice: startRef.voice,
                                            startEntryIndexInVoice: startRef.entryIndexInVoice,
                                            endSystemIndex: endRef.systemIndex,
                                            endPartIndex: endRef.partIndex,
                                            endMeasureIndexInPart: endRef.measureIndexInPart,
                                            endVoice: endRef.voice,
                                            endEntryIndexInVoice: endRef.entryIndexInVoice,
                                            verse: verse,
                                            kind: .hyphen,
                                            sourceOrder: sourceOrder
                                        )
                                    )
                                    sourceOrder += 1
                                }
                            }
                        }
                        }

                        guard lyric.extend else {
                            continue
                        }
                        var nextLyricIndex: Int?
                        if timelineIndex + 1 < timeline.count {
                            for searchIndex in (timelineIndex + 1)..<timeline.count {
                                let candidate = timeline[searchIndex]
                                if candidate.note.lyrics.contains(where: { candidateLyric in
                                    max(1, candidateLyric.number) == verse
                                        && lyricText(for: candidateLyric) != nil
                                }) {
                                    nextLyricIndex = searchIndex
                                    break
                                }
                            }
                        }
                        let endTimelineIndex: Int?
                        if let nextLyricIndex {
                            if nextLyricIndex - 1 >= timelineIndex + 1 {
                                endTimelineIndex = nextLyricIndex - 1
                            } else {
                                endTimelineIndex = nextLyricIndex
                            }
                        } else if timelineIndex + 1 < timeline.count {
                            endTimelineIndex = timeline.count - 1
                        } else {
                            endTimelineIndex = nil
                        }
                        guard let endTimelineIndex,
                              endTimelineIndex != timelineIndex else {
                            continue
                        }
                        let endItem = timeline[endTimelineIndex]
                        let endKey = SourceNoteKey(
                            partIndex: partIndex,
                            measureIndexInPart: endItem.measureIndexInPart,
                            noteIndexInMeasure: endItem.noteIndexInMeasure
                        )
                        guard let endRef = noteEntryReferenceBySourceKey[endKey],
                              startRef != endRef else {
                            continue
                        }
                        let connectorKey = ConnectorKey(
                            start: startRef,
                            end: endRef,
                            verse: verse,
                            kind: .extender
                        )
                        if seen.contains(connectorKey) {
                            continue
                        }
                        seen.insert(connectorKey)
                        plans.append(
                            VexLyricConnectorPlan(
                                startSystemIndex: startRef.systemIndex,
                                startPartIndex: startRef.partIndex,
                                startMeasureIndexInPart: startRef.measureIndexInPart,
                                startVoice: startRef.voice,
                                startEntryIndexInVoice: startRef.entryIndexInVoice,
                                endSystemIndex: endRef.systemIndex,
                                endPartIndex: endRef.partIndex,
                                endMeasureIndexInPart: endRef.measureIndexInPart,
                                endVoice: endRef.voice,
                                endEntryIndexInVoice: endRef.entryIndexInVoice,
                                verse: verse,
                                kind: .extender,
                                sourceOrder: sourceOrder
                            )
                        )
                        sourceOrder += 1
                    }
                }
            }
        }

        return plans.sorted { lhs, rhs in
            if lhs.startSystemIndex != rhs.startSystemIndex {
                return lhs.startSystemIndex < rhs.startSystemIndex
            }
            if lhs.startPartIndex != rhs.startPartIndex {
                return lhs.startPartIndex < rhs.startPartIndex
            }
            if lhs.startMeasureIndexInPart != rhs.startMeasureIndexInPart {
                return lhs.startMeasureIndexInPart < rhs.startMeasureIndexInPart
            }
            if lhs.startVoice != rhs.startVoice {
                return lhs.startVoice < rhs.startVoice
            }
            if lhs.startEntryIndexInVoice != rhs.startEntryIndexInVoice {
                return lhs.startEntryIndexInVoice < rhs.startEntryIndexInVoice
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

    private func directionTextValue(for rawText: String?) -> String? {
        let text = rawText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else {
            return nil
        }
        return text
    }

    private func directionTextPlacementPlan(
        from placement: String?
    ) -> VexDirectionTextPlacementPlan? {
        guard let placement = placement?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return nil
        }
        switch placement {
        case "above", "top", "over":
            return .above
        case "below", "bottom", "under":
            return .below
        default:
            return nil
        }
    }

    private func directionAnnotationVerticalJustify(
        for placement: VexDirectionTextPlacementPlan?
    ) -> AnnotationVerticalJustify {
        switch placement {
        case .below:
            return .bottom
        case .above, .none:
            return .top
        }
    }

    private func directionAnnotationPosition(
        for placement: VexDirectionTextPlacementPlan?
    ) -> ModifierPosition? {
        switch placement {
        case .above:
            return .above
        case .below:
            return .below
        case .none:
            return nil
        }
    }

    private func roadmapRepetitionSortValue(
        for kind: VexRoadmapRepetitionKind
    ) -> Int {
        switch kind {
        case .segnoLeft:
            return 0
        case .segnoRight:
            return 1
        case .codaLeft:
            return 2
        case .codaRight:
            return 3
        case .dc:
            return 4
        case .dcAlCoda:
            return 5
        case .dcAlFine:
            return 6
        case .ds:
            return 7
        case .dsAlCoda:
            return 8
        case .dsAlFine:
            return 9
        case .toCoda:
            return 10
        case .fine:
            return 11
        }
    }

    private func roadmapRepetitionType(
        for kind: VexRoadmapRepetitionKind
    ) -> RepetitionType {
        switch kind {
        case .codaLeft:
            return .codaLeft
        case .codaRight:
            return .codaRight
        case .segnoLeft:
            return .segnoLeft
        case .segnoRight:
            return .segnoRight
        case .dc:
            return .dc
        case .dcAlCoda:
            return .dcAlCoda
        case .dcAlFine:
            return .dcAlFine
        case .ds:
            return .ds
        case .dsAlCoda:
            return .dsAlCoda
        case .dsAlFine:
            return .dsAlFine
        case .fine:
            return .fine
        case .toCoda:
            return .toCoda
        }
    }

    private func metronomeTempoPlan(
        from metronome: MusicDisplayKitModel.MetronomeMark?,
        fallbackSoundTempo: Double?
    ) -> (bpm: Int, duration: NoteValue, dots: Int)? {
        guard let metronome else {
            return nil
        }
        let bpm = parseTempoBPM(raw: metronome.perMinute) ?? soundTempoPlan(from: fallbackSoundTempo)?.bpm
        guard let bpm, bpm > 0 else {
            return nil
        }
        return (
            bpm: bpm,
            duration: tempoDuration(fromBeatUnit: metronome.beatUnit) ?? .quarter,
            dots: max(0, metronome.beatUnitDotCount)
        )
    }

    private func soundTempoPlan(
        from soundTempo: Double?
    ) -> (bpm: Int, duration: NoteValue, dots: Int)? {
        guard let soundTempo, soundTempo > 0 else {
            return nil
        }
        let bpm = Int(soundTempo.rounded())
        guard bpm > 0 else {
            return nil
        }
        return (bpm: bpm, duration: .quarter, dots: 0)
    }

    private func parseTempoBPM(raw: String?) -> Int? {
        guard let raw = raw?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if let numeric = Double(raw), numeric > 0 {
            return Int(numeric.rounded())
        }

        let pattern = #"[0-9]+(?:\.[0-9]+)?"#
        guard let range = raw.range(of: pattern, options: .regularExpression),
              let numeric = Double(raw[range]),
              numeric > 0 else {
            return nil
        }
        return Int(numeric.rounded())
    }

    private func tempoDuration(fromBeatUnit beatUnit: String?) -> NoteValue? {
        guard let beatUnit = beatUnit?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !beatUnit.isEmpty else {
            return nil
        }
        switch beatUnit {
        case "breve":
            return .doubleWhole
        case "whole":
            return .whole
        case "half":
            return .half
        case "quarter":
            return .quarter
        case "eighth":
            return .eighth
        case "16th", "sixteenth":
            return .sixteenth
        case "32nd", "thirty-second":
            return .thirtySecond
        case "64th", "sixty-fourth":
            return .sixtyFourth
        case "128th":
            return .oneTwentyEighth
        case "256th":
            return .twoFiftySixth
        default:
            return nil
        }
    }

    private func directionSpanSortsBefore(_ lhs: VexNotePlan, _ rhs: VexNotePlan) -> Bool {
        if lhs.onsetDivisions != rhs.onsetDivisions {
            return lhs.onsetDivisions < rhs.onsetDivisions
        }
        if lhs.voice != rhs.voice {
            return lhs.voice < rhs.voice
        }
        if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
            return lhs.entryIndexInVoice < rhs.entryIndexInVoice
        }
        return lhs.sourceOrder <= rhs.sourceOrder
    }

    private func octaveShiftText(
        for type: MusicDisplayKitModel.OctaveShiftType,
        size: Int?
    ) -> (text: String, superscript: String)? {
        let normalizedSize = max(8, size ?? 8)
        switch type {
        case .up:
            switch normalizedSize {
            case 8:
                return ("8", "va")
            case 15:
                return ("15", "ma")
            default:
                return ("\(normalizedSize)", "va")
            }
        case .down:
            switch normalizedSize {
            case 8:
                return ("8", "vb")
            case 15:
                return ("15", "mb")
            default:
                return ("\(normalizedSize)", "vb")
            }
        case .stop, .continue, .unknown:
            return nil
        }
    }

    private func octaveShiftPositionPlan(
        type: MusicDisplayKitModel.OctaveShiftType,
        placement: VexDirectionTextPlacementPlan?
    ) -> VexOctaveShiftPositionPlan {
        switch type {
        case .up:
            return .top
        case .down:
            return .bottom
        case .stop, .continue, .unknown:
            return placement == .below ? .bottom : .top
        }
    }

    private func pedalKindPlan(
        from marker: MusicDisplayKitModel.PedalMarker
    ) -> VexPedalKindPlan {
        let line = marker.line ?? false
        let sign = marker.sign ?? false
        if line && !sign {
            return .bracket
        }
        if sign && !line {
            return .text
        }
        return .mixed
    }

    private func wedgeHairpinType(for kind: VexDirectionWedgeKind) -> HairpinType {
        switch kind {
        case .crescendo:
            return .crescendo
        case .decrescendo:
            return .decrescendo
        }
    }

    private func directionWedgePosition(
        for placement: VexDirectionTextPlacementPlan?
    ) -> ModifierPosition? {
        switch placement {
        case .above:
            return .above
        case .below:
            return .below
        case .none:
            return nil
        }
    }

    private func textBracketPosition(
        for position: VexOctaveShiftPositionPlan
    ) -> TextBracketPosition {
        switch position {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    private func pedalMarkingType(
        for kind: VexPedalKindPlan
    ) -> PedalMarkingType {
        switch kind {
        case .text:
            return .text
        case .bracket:
            return .bracket
        case .mixed:
            return .mixed
        }
    }

    private func lyricText(for lyric: MusicDisplayKitModel.LyricEvent) -> String? {
        let text = lyric.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else {
            return nil
        }
        return text
    }

    private func lyricExtenderText(forSpanWidth spanWidth: Double) -> String {
        // Approximate underline width in headless mode to avoid overextending.
        let count = max(2, min(24, Int(spanWidth / 5)))
        return String(repeating: "_", count: count)
    }

    private func lyricTextLine(verse: Int, voiceOffset: Int) -> Double {
        let line = max(0, verse - 1 + voiceOffset)
        return Double(line)
    }

    private func harmonyDisplayText(
        for harmony: MusicDisplayKitModel.HarmonyEvent
    ) -> String? {
        guard let root = harmonyFormatPitch(step: harmony.rootStep, alter: harmony.rootAlter) else {
            return nil
        }

        let kindSuffix = harmonyKindSuffix(kind: harmony.kind, explicitText: harmony.kindText)
        let degreesSuffix = harmonyDegreesSuffix(harmony.degrees)

        var text = root + kindSuffix + degreesSuffix

        if let bass = harmonyFormatPitch(step: harmony.bassStep, alter: harmony.bassAlter) {
            text += "/\(bass)"
        }

        return text
    }

    private func harmonyFormatPitch(step: String?, alter: Int) -> String? {
        guard let step = step?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
              !step.isEmpty else {
            return nil
        }
        return step + harmonyAccidentalString(alter: alter)
    }

    private func harmonyAccidentalString(alter: Int) -> String {
        guard alter != 0 else {
            return ""
        }
        if alter > 0 {
            return String(repeating: "#", count: alter)
        }
        return String(repeating: "b", count: abs(alter))
    }

    private func harmonyKindSuffix(kind: String?, explicitText: String?) -> String {
        if let explicitText = explicitText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitText.isEmpty {
            return explicitText
        }

        let normalizedKind = kind?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch normalizedKind {
        case "", "major":
            return ""
        case "minor":
            return "m"
        case "major-seventh":
            return "maj7"
        case "minor-seventh":
            return "m7"
        case "dominant":
            return "7"
        case "augmented":
            return "+"
        case "diminished":
            return "dim"
        case "half-diminished":
            return "m7b5"
        default:
            return normalizedKind.isEmpty ? "" : "(\(normalizedKind))"
        }
    }

    private func harmonyDegreesSuffix(
        _ degrees: [MusicDisplayKitModel.HarmonyDegree]
    ) -> String {
        let tokens = degrees.compactMap { degree -> String? in
            guard let value = degree.value else {
                return nil
            }
            let accidental = harmonyAccidentalString(alter: degree.alter ?? 0)
            switch degree.type {
            case .add:
                return "add\(accidental)\(value)"
            case .subtract:
                return "no\(value)"
            case .alter:
                return "\(accidental)\(value)"
            case .unknown(let raw):
                let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? "\(accidental)\(value)" : "\(cleaned)\(accidental)\(value)"
            case .none:
                return "\(accidental)\(value)"
            }
        }

        guard !tokens.isEmpty else {
            return ""
        }

        return "(\(tokens.joined(separator: ",")))"
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

    private func defaultArticulationModifierPosition(
        for note: StaveNote
    ) -> ModifierPosition? {
        let topLine = note.getLineNumber(isTopNote: true)
        let bottomLine = note.getLineNumber(isTopNote: false)
        let centerLine = (topLine + bottomLine) / 2
        // Staff-center heuristic for unspecified articulations:
        // lower notes default below, higher notes default above.
        return centerLine >= 3 ? .above : .below
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

@available(iOS 17.0, macOS 14.0, *)
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
                    contextProvider: VexSwiftUICanvasContextProvider(context: ctx)
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
