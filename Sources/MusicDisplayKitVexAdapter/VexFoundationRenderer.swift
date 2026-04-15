import MusicDisplayKitCore
import MusicDisplayKitLayout
import MusicDisplayKitModel
import VexFoundation
import Foundation
#if canImport(OSLog)
import OSLog
#endif

/// Position data extracted from VexFoundation objects post-format.
public struct VexNotePosition: Sendable {
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let sourceOrder: Int
    public let x: Double
    public let ys: [Double]
    public let boundingBox: MDKBoundingBox?
}

public enum RenderTarget: Equatable, Sendable {
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
    public let multipleRestCount: Int?
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
        multipleRestCount: Int? = nil,
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
        self.multipleRestCount = multipleRestCount
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

public struct VexGraceNotePlan: Sendable {
    public let keyTokens: [String]
    public let noteType: NoteTypeValue?
    public let slash: Bool
    public let accidental: AccidentalValue?

    public init(
        keyTokens: [String],
        noteType: NoteTypeValue? = nil,
        slash: Bool = false,
        accidental: AccidentalValue? = nil
    ) {
        self.keyTokens = keyTokens
        self.noteType = noteType
        self.slash = slash
        self.accidental = accidental
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
    public let staff: Int?
    public let clef: String?
    public let entryIndexInVoice: Int
    public let onsetDivisions: Int
    public let durationDivisions: Int
    public let divisions: Int
    public let timeSignatureBeats: Int
    public let timeSignatureBeatType: Int
    public let isRest: Bool
    public let keyTokens: [String]
    public let sourceOrder: Int
    public let noteType: NoteTypeValue?
    public let dotCount: Int
    public let accidental: AccidentalValue?
    public let stemDirection: NoteStemDirection?
    public let ornaments: [OrnamentMarker]
    public let fermatas: [FermataMarker]
    public let arpeggiate: ArpeggiateMarker?
    public let tremolo: TremoloMarker?
    public let dynamics: [String]
    public let glissandos: [GlissandoMarker]
    public let isCue: Bool
    public let noteheadType: NoteheadType?
    public let color: String?
    public let graceNotes: [VexGraceNotePlan]
    public let crossStaffTarget: Int?

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        measureNumber: Int,
        pageIndex: Int,
        measureFrame: LayoutRect,
        isFirstMeasureInSystem: Bool,
        voice: Int,
        staff: Int?,
        clef: String? = nil,
        entryIndexInVoice: Int,
        onsetDivisions: Int,
        durationDivisions: Int,
        divisions: Int,
        timeSignatureBeats: Int = 4,
        timeSignatureBeatType: Int = 4,
        isRest: Bool,
        keyTokens: [String],
        sourceOrder: Int,
        noteType: NoteTypeValue? = nil,
        dotCount: Int = 0,
        accidental: AccidentalValue? = nil,
        stemDirection: NoteStemDirection? = nil,
        ornaments: [OrnamentMarker] = [],
        fermatas: [FermataMarker] = [],
        arpeggiate: ArpeggiateMarker? = nil,
        tremolo: TremoloMarker? = nil,
        dynamics: [String] = [],
        glissandos: [GlissandoMarker] = [],
        isCue: Bool = false,
        noteheadType: NoteheadType? = nil,
        color: String? = nil,
        graceNotes: [VexGraceNotePlan] = [],
        crossStaffTarget: Int? = nil
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.measureNumber = measureNumber
        self.pageIndex = pageIndex
        self.measureFrame = measureFrame
        self.isFirstMeasureInSystem = isFirstMeasureInSystem
        self.voice = voice
        self.staff = staff
        self.clef = clef
        self.entryIndexInVoice = entryIndexInVoice
        self.onsetDivisions = onsetDivisions
        self.durationDivisions = durationDivisions
        self.divisions = divisions
        self.timeSignatureBeats = max(1, timeSignatureBeats)
        self.timeSignatureBeatType = max(1, timeSignatureBeatType)
        self.isRest = isRest
        self.keyTokens = keyTokens
        self.sourceOrder = sourceOrder
        self.noteType = noteType
        self.dotCount = dotCount
        self.accidental = accidental
        self.stemDirection = stemDirection
        self.ornaments = ornaments
        self.fermatas = fermatas
        self.arpeggiate = arpeggiate
        self.tremolo = tremolo
        self.dynamics = dynamics
        self.glissandos = glissandos
        self.isCue = isCue
        self.noteheadType = noteheadType
        self.color = color
        self.graceNotes = graceNotes
        self.crossStaffTarget = crossStaffTarget
    }
}

public struct VexInlineClefChangePlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let clef: String
    public let annotation: String?

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        clef: String,
        annotation: String? = nil
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.clef = clef
        self.annotation = annotation
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
    public let endSystemIndex: Int
    public let endPartIndex: Int
    public let endMeasureIndexInPart: Int
    public let voice: Int
    public let number: Int?
    public let startEntryIndex: Int
    public let endEntryIndex: Int
    public let placement: String?

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        endSystemIndex: Int? = nil,
        endPartIndex: Int? = nil,
        endMeasureIndexInPart: Int? = nil,
        voice: Int,
        number: Int?,
        startEntryIndex: Int,
        endEntryIndex: Int,
        placement: String?
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.endSystemIndex = endSystemIndex ?? systemIndex
        self.endPartIndex = endPartIndex ?? partIndex
        self.endMeasureIndexInPart = endMeasureIndexInPart ?? measureIndexInPart
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

public enum VexFingeringPositionPlan: Sendable {
    case left
    case right
    case above
    case below
}

public struct VexFingeringPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let number: String
    public let position: VexFingeringPositionPlan?
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        number: String,
        position: VexFingeringPositionPlan?,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.number = number
        self.position = position
        self.sourceOrder = sourceOrder
    }
}

public enum VexStringNumberPositionPlan: Sendable {
    case left
    case right
    case above
    case below
}

public struct VexStringNumberPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let number: String
    public let position: VexStringNumberPositionPlan?
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        number: String,
        position: VexStringNumberPositionPlan?,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.number = number
        self.position = position
        self.sourceOrder = sourceOrder
    }
}

public struct VexTabPositionPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let stringNumber: String
    public let fretNumber: String
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        stringNumber: String,
        fretNumber: String,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.stringNumber = stringNumber
        self.fretNumber = fretNumber
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

public enum VexChordSymbolPlacementPlan: Sendable {
    case above
    case below
}

public struct VexChordSymbolPlan: Sendable {
    public let systemIndex: Int
    public let partIndex: Int
    public let measureIndexInPart: Int
    public let voice: Int
    public let entryIndexInVoice: Int
    public let displayText: String
    public let placement: VexChordSymbolPlacementPlan
    public let sourceOrder: Int

    public init(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        entryIndexInVoice: Int,
        displayText: String,
        placement: VexChordSymbolPlacementPlan,
        sourceOrder: Int
    ) {
        self.systemIndex = systemIndex
        self.partIndex = partIndex
        self.measureIndexInPart = measureIndexInPart
        self.voice = voice
        self.entryIndexInVoice = entryIndexInVoice
        self.displayText = displayText
        self.placement = placement
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
    public let autoBeam: Bool
    public let title: String?
    public let composer: String?
    public let lyricist: String?
    public let partNames: [Int: String]
    public let partAbbreviations: [Int: String]
    public let staves: [VexStavePlan]
    public let measures: [VexMeasurePlan]
    public let measureBoundaries: [VexMeasureBoundaryPlan]
    public let notes: [VexNotePlan]
    public let inlineClefChanges: [VexInlineClefChangePlan]
    public let beams: [VexBeamPlan]
    public let tuplets: [VexTupletPlan]
    public let ties: [VexTiePlan]
    public let slurs: [VexSlurPlan]
    public let articulations: [VexArticulationPlan]
    public let fingerings: [VexFingeringPlan]
    public let stringNumbers: [VexStringNumberPlan]
    public let tabPositions: [VexTabPositionPlan]
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
        autoBeam: Bool = false,
        title: String? = nil,
        composer: String? = nil,
        lyricist: String? = nil,
        partNames: [Int: String] = [:],
        partAbbreviations: [Int: String] = [:],
        staves: [VexStavePlan],
        measures: [VexMeasurePlan],
        measureBoundaries: [VexMeasureBoundaryPlan],
        notes: [VexNotePlan],
        inlineClefChanges: [VexInlineClefChangePlan] = [],
        beams: [VexBeamPlan],
        tuplets: [VexTupletPlan],
        ties: [VexTiePlan],
        slurs: [VexSlurPlan],
        articulations: [VexArticulationPlan],
        fingerings: [VexFingeringPlan],
        stringNumbers: [VexStringNumberPlan],
        tabPositions: [VexTabPositionPlan],
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
        self.autoBeam = autoBeam
        self.title = title
        self.composer = composer
        self.lyricist = lyricist
        self.partNames = partNames
        self.partAbbreviations = partAbbreviations
        self.staves = staves
        self.measures = measures
        self.measureBoundaries = measureBoundaries
        self.notes = notes
        self.inlineClefChanges = inlineClefChanges
        self.beams = beams
        self.tuplets = tuplets
        self.ties = ties
        self.slurs = slurs
        self.articulations = articulations
        self.fingerings = fingerings
        self.stringNumbers = stringNumbers
        self.tabPositions = tabPositions
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
    public let tabNotes: [VexFoundation.TabNote]
    public let beams: [Beam]
    public let tuplets: [Tuplet]
    public let ties: [StaveTie]
    public let slurs: [Curve]
    public let glissandos: [StaveLine]
    public let articulations: [VexFoundation.Articulation]
    public let fingerings: [VexFoundation.FretHandFinger]
    public let stringNumbers: [VexFoundation.StringNumber]
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
    public let notePositions: [VexNotePosition]

    public init(
        factory: Factory,
        staves: [Stave],
        voices: [Voice],
        notes: [StaveNote],
        tabNotes: [VexFoundation.TabNote],
        beams: [Beam],
        tuplets: [Tuplet],
        ties: [StaveTie],
        slurs: [Curve],
        glissandos: [StaveLine],
        articulations: [VexFoundation.Articulation],
        fingerings: [VexFoundation.FretHandFinger],
        stringNumbers: [VexFoundation.StringNumber],
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
        barlineConnectors: [StaveConnector],
        notePositions: [VexNotePosition] = []
    ) {
        self.factory = factory
        self.staves = staves
        self.voices = voices
        self.notes = notes
        self.tabNotes = tabNotes
        self.beams = beams
        self.tuplets = tuplets
        self.ties = ties
        self.slurs = slurs
        self.glissandos = glissandos
        self.articulations = articulations
        self.fingerings = fingerings
        self.stringNumbers = stringNumbers
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
        self.notePositions = notePositions
    }
}

public struct VexRenderMetricsSnapshot: Sendable {
    public let makeRenderPlanCount: Int
    public let executeRenderPlanCount: Int
    public let totalMakeRenderPlanDurationMS: Double
    public let totalExecuteRenderPlanDurationMS: Double
    public let maxMakeRenderPlanDurationMS: Double
    public let maxExecuteRenderPlanDurationMS: Double
    public let totalExecutedElementCount: Int

    public var averageMakeRenderPlanDurationMS: Double {
        guard makeRenderPlanCount > 0 else { return 0 }
        return totalMakeRenderPlanDurationMS / Double(makeRenderPlanCount)
    }

    public var averageExecuteRenderPlanDurationMS: Double {
        guard executeRenderPlanCount > 0 else { return 0 }
        return totalExecuteRenderPlanDurationMS / Double(executeRenderPlanCount)
    }
}

public enum VexRenderMetrics {
    private static let lock = NSLock()

    private struct State {
        var makeRenderPlanCount = 0
        var executeRenderPlanCount = 0
        var totalMakeRenderPlanDurationMS = 0.0
        var totalExecuteRenderPlanDurationMS = 0.0
        var maxMakeRenderPlanDurationMS = 0.0
        var maxExecuteRenderPlanDurationMS = 0.0
        var totalExecutedElementCount = 0
    }
    nonisolated(unsafe) private static var state = State()

    static func recordMakeRenderPlan(durationMS: Double) {
        lock.lock()
        defer { lock.unlock() }
        state.makeRenderPlanCount += 1
        state.totalMakeRenderPlanDurationMS += durationMS
        state.maxMakeRenderPlanDurationMS = max(state.maxMakeRenderPlanDurationMS, durationMS)
    }

    static func recordExecuteRenderPlan(durationMS: Double, elementCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        state.executeRenderPlanCount += 1
        state.totalExecuteRenderPlanDurationMS += durationMS
        state.maxExecuteRenderPlanDurationMS = max(state.maxExecuteRenderPlanDurationMS, durationMS)
        state.totalExecutedElementCount += elementCount
    }

    public static func snapshot() -> VexRenderMetricsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return VexRenderMetricsSnapshot(
            makeRenderPlanCount: state.makeRenderPlanCount,
            executeRenderPlanCount: state.executeRenderPlanCount,
            totalMakeRenderPlanDurationMS: state.totalMakeRenderPlanDurationMS,
            totalExecuteRenderPlanDurationMS: state.totalExecuteRenderPlanDurationMS,
            maxMakeRenderPlanDurationMS: state.maxMakeRenderPlanDurationMS,
            maxExecuteRenderPlanDurationMS: state.maxExecuteRenderPlanDurationMS,
            totalExecutedElementCount: state.totalExecutedElementCount
        )
    }

    public static func reset() {
        lock.lock()
        defer { lock.unlock() }
        state = State()
    }
}

private extension VexRenderPlan {
    var renderedElementEstimate: Int {
        let notesAndRhythm = staves.count +
            measures.count +
            notes.count +
            inlineClefChanges.count +
            beams.count +
            tuplets.count +
            ties.count +
            slurs.count

        let modifiers = articulations.count +
            fingerings.count +
            stringNumbers.count +
            tabPositions.count +
            lyrics.count +
            chordSymbols.count +
            directionTexts.count

        let directionsAndConnectors = tempoMarks.count +
            roadmapRepetitions.count +
            directionWedges.count +
            octaveShiftSpanners.count +
            pedalMarkings.count +
            lyricConnectors.count +
            partGroupConnectors.count +
            barlineConnectors.count

        return notesAndRhythm + modifiers + directionsAndConnectors
    }
}

private enum VexRendererSignpost {
    #if canImport(OSLog)
    private static let signposter = OSSignposter(
        subsystem: "MusicDisplayKit",
        category: "VexFoundationRenderer"
    )
    typealias IntervalState = OSSignpostIntervalState
    #else
    struct IntervalState {}
    #endif

    static func begin(_ name: StaticString) -> IntervalState {
        #if canImport(OSLog)
        signposter.beginInterval(name)
        #else
        IntervalState()
        #endif
    }

    static func end(_ name: StaticString, _ state: IntervalState) {
        #if canImport(OSLog)
        signposter.endInterval(name, state)
        #else
        _ = name
        _ = state
        #endif
    }
}

/// Cache for incremental re-rendering (8.2).
/// Tracks the previously executed render plan and factory execution per system.
/// When a score is re-rendered with only a subset of systems changed (dirty),
/// only those systems need to be re-executed; the rest reuse cached VexFoundation
/// objects.
public final class VexRenderCache {
    /// Previously cached execution, keyed by system index.
    public private(set) var cachedExecutions: [Int: VexFactoryExecution] = [:]
    /// System indices that have been marked dirty and need re-execution.
    public private(set) var dirtySystems: Set<Int> = []

    public init() {}

    /// Marks the given system indices as dirty (needing re-render).
    public func markDirty(_ systemIndices: some Sequence<Int>) {
        dirtySystems.formUnion(systemIndices)
    }

    /// Marks all systems as dirty.
    public func markAllDirty() {
        dirtySystems = Set(cachedExecutions.keys)
    }

    /// Stores an execution for the given system index and clears its dirty flag.
    public func store(_ execution: VexFactoryExecution, forSystem systemIndex: Int) {
        cachedExecutions[systemIndex] = execution
        dirtySystems.remove(systemIndex)
    }

    /// Returns `true` if the given system index needs re-execution.
    public func isDirty(_ systemIndex: Int) -> Bool {
        dirtySystems.contains(systemIndex) || cachedExecutions[systemIndex] == nil
    }

    /// Clears the entire cache.
    public func invalidate() {
        cachedExecutions.removeAll()
        dirtySystems.removeAll()
    }
}

public struct VexFoundationRenderer: ScoreRenderer {
    public let contextProvider: any VexRenderContextProvider

    public init(contextProvider: any VexRenderContextProvider = HeadlessRenderContextProvider()) {
        self.contextProvider = contextProvider
    }

    public func makeRenderPlan(from score: LaidOutScore, target: RenderTarget) -> VexRenderPlan {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let signpost = VexRendererSignpost.begin("makeRenderPlan")
        defer {
            let elapsedMS = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
            VexRenderMetrics.recordMakeRenderPlan(durationMS: elapsedMS)
            VexRendererSignpost.end("makeRenderPlan", signpost)
        }

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
                multipleRestCount: initialState.multipleRestCount,
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

        var firstMeasureIndexBySystem: [Int: Int] = [:]
        for system in score.systems {
            let firstMeasureIndex = system.measureIndices.min() ?? Int.max
            let existing = firstMeasureIndexBySystem[system.systemIndex] ?? Int.max
            firstMeasureIndexBySystem[system.systemIndex] = min(existing, firstMeasureIndex)
        }

        struct VoiceOnsetKey: Hashable {
            let voice: Int
            let onsetDivisions: Int
        }

        struct MeasureRenderPlans {
            let notes: [VexNotePlan]
            let inlineClefChanges: [VexInlineClefChangePlan]
            let beams: [VexBeamPlan]
            let tuplets: [VexTupletPlan]
            let ties: [VexTiePlan]
            let slurs: [VexSlurPlan]
            let articulations: [VexArticulationPlan]
            let fingerings: [VexFingeringPlan]
            let stringNumbers: [VexStringNumberPlan]
            let tabPositions: [VexTabPositionPlan]
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
                    inlineClefChanges: [],
                    beams: [],
                    tuplets: [],
                    ties: [],
                    slurs: [],
                    articulations: [],
                    fingerings: [],
                    stringNumbers: [],
                    tabPositions: [],
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
                    inlineClefChanges: [],
                    beams: [],
                    tuplets: [],
                    ties: [],
                    slurs: [],
                    articulations: [],
                    fingerings: [],
                    stringNumbers: [],
                    tabPositions: [],
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
            let effectiveAttributes = effectiveStaveAttributes(
                in: part,
                upToMeasureIndex: laidOutMeasure.measureIndexInPart
            )
            let effectiveClefName = effectiveAttributes.clef.flatMap(vexClefName(for:))
            struct ClefChangeAtOnset {
                let onsetDivisions: Int
                let clefName: ClefName
            }
            let inMeasureClefChanges: [ClefChangeAtOnset] = {
                let groupedByOnset = Dictionary(grouping: sourceMeasure.clefEvents) { clefEvent in
                    max(0, clefEvent.onsetDivisions)
                }
                return groupedByOnset
                    .keys
                    .filter { $0 > 0 }
                    .sorted()
                    .compactMap { onset in
                        guard let events = groupedByOnset[onset] else {
                            return nil
                        }
                        let clefsAtOnset = events.map(\.clef)
                        guard let selected = selectedClef(from: clefsAtOnset),
                              let clefName = vexClefName(for: selected),
                              clefName != .tab else {
                            return nil
                        }
                        return ClefChangeAtOnset(
                            onsetDivisions: onset,
                            clefName: clefName
                        )
                    }
            }()
            let clefNameForOnset: (Int) -> ClefName? = { onsetDivisions in
                var resolved = effectiveClefName
                for clefChange in inMeasureClefChanges where clefChange.onsetDivisions <= onsetDivisions {
                    resolved = clefChange.clefName
                }
                return resolved
            }

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

            // Build grace note plans grouped by voice and onset (attached to following regular note).
            let graceEvents = sourceMeasure.noteEvents
                .enumerated()
                .filter { _, event in event.isGrace }
            var graceNotesByVoiceOnset: [VoiceOnsetKey: [VexGraceNotePlan]] = [:]
            for (_, graceEvent) in graceEvents {
                let voice = max(1, graceEvent.voice)
                let onset = max(0, graceEvent.onsetDivisions)
                let key = VoiceOnsetKey(voice: voice, onsetDivisions: onset)
                let keyToken = noteKeyToken(for: graceEvent).map { [$0] } ?? ["b/4"]
                let plan = VexGraceNotePlan(
                    keyTokens: keyToken,
                    noteType: graceEvent.noteType,
                    slash: graceEvent.isGraceSlash,
                    accidental: graceEvent.accidental
                )
                graceNotesByVoiceOnset[key, default: []].append(plan)
            }
            let firstMeasureIndexInSystem = firstMeasureIndexBySystem[laidOutMeasure.systemIndex] ?? Int.max
            let isFirstMeasureInSystem = laidOutMeasure.index == firstMeasureIndexInSystem
            let measureTimeSignature = effectiveAttributes.time ?? sourceMeasure.attributes?.time
            let timeSignatureBeats = max(1, measureTimeSignature?.beats ?? 4)
            let timeSignatureBeatType = max(1, measureTimeSignature?.beatType ?? 4)

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
                let resolvedStaff = events.compactMap(\.staff).first
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

                let firstEvent = events.first
                let allOrnaments = events.flatMap(\.ornaments)
                let allFermatas = events.flatMap(\.fermatas)

                return VexNotePlan(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    measureNumber: laidOutMeasure.measureNumber,
                    pageIndex: laidOutMeasure.pageIndex,
                    measureFrame: laidOutMeasure.frame,
                    isFirstMeasureInSystem: isFirstMeasureInSystem,
                    voice: key.voice,
                    staff: resolvedStaff,
                    clef: clefNameForOnset(key.onsetDivisions)?.rawValue,
                    entryIndexInVoice: entryIndex,
                    onsetDivisions: key.onsetDivisions,
                    durationDivisions: max(1, maxDuration),
                    divisions: max(1, effectiveDivisions),
                    timeSignatureBeats: timeSignatureBeats,
                    timeSignatureBeatType: timeSignatureBeatType,
                    isRest: isRest,
                    keyTokens: keyTokens,
                    sourceOrder: sourceOrder,
                    noteType: firstEvent?.noteType,
                    dotCount: firstEvent?.dotCount ?? 0,
                    accidental: firstEvent?.accidental,
                    stemDirection: firstEvent?.stemDirection,
                    ornaments: allOrnaments,
                    fermatas: allFermatas,
                    arpeggiate: firstEvent?.arpeggiate,
                    tremolo: firstEvent?.tremolo,
                    dynamics: firstEvent?.dynamics ?? [],
                    glissandos: firstEvent?.glissandos ?? [],
                    isCue: firstEvent?.isCue ?? false,
                    noteheadType: firstEvent?.noteheadType,
                    color: firstEvent?.color ?? (firstEvent?.printObject == false ? "#CCCCCC" : nil),
                    graceNotes: graceNotesByVoiceOnset[key] ?? [],
                    crossStaffTarget: firstEvent?.crossStaffTarget
                )
            }

            let inlineClefChanges = buildInlineClefChangePlans(
                laidOutMeasure: laidOutMeasure,
                sourceMeasure: sourceMeasure,
                part: part,
                isFirstMeasureInSystem: isFirstMeasureInSystem,
                notePlans: notePlans,
                effectiveMeasureClef: effectiveClefName
            )

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
            var fingeringPlans: [VexFingeringPlan] = []
            var stringNumberPlans: [VexStringNumberPlan] = []
            var tabPositionPlans: [VexTabPositionPlan] = []
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
                fingeringPlans.append(contentsOf: buildFingeringPlans(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    voice: voice,
                    noteIndices: sortedNoteIndices,
                    noteEvents: sourceMeasure.noteEvents,
                    noteToEntryIndex: noteToEntryIndex
                ))
                stringNumberPlans.append(contentsOf: buildStringNumberPlans(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    voice: voice,
                    noteIndices: sortedNoteIndices,
                    noteEvents: sourceMeasure.noteEvents,
                    noteToEntryIndex: noteToEntryIndex
                ))
                tabPositionPlans.append(contentsOf: buildTabPositionPlans(
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
                inlineClefChanges: inlineClefChanges,
                beams: beamPlans,
                tuplets: tupletPlans,
                ties: tiePlans,
                slurs: slurPlans,
                articulations: articulationPlans,
                fingerings: fingeringPlans,
                stringNumbers: stringNumberPlans,
                tabPositions: tabPositionPlans,
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
        let inlineClefChanges = measureRenderPlans.flatMap(\.inlineClefChanges)
        let beams = measureRenderPlans.flatMap(\.beams)
        let tuplets = measureRenderPlans.flatMap(\.tuplets)
        let ties = measureRenderPlans.flatMap(\.ties)
        let inMeasureSlurs = measureRenderPlans.flatMap(\.slurs)
        let crossMeasureSlurs = buildCrossMeasureSlurPlans(
            score: score.score,
            noteEntryReferenceBySourceKey: noteEntryReferenceBySourceKey
        )
        let slurs = (inMeasureSlurs + crossMeasureSlurs).sorted { lhs, rhs in
            if lhs.systemIndex != rhs.systemIndex {
                return lhs.systemIndex < rhs.systemIndex
            }
            if lhs.partIndex != rhs.partIndex {
                return lhs.partIndex < rhs.partIndex
            }
            if lhs.measureIndexInPart != rhs.measureIndexInPart {
                return lhs.measureIndexInPart < rhs.measureIndexInPart
            }
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            if lhs.startEntryIndex != rhs.startEntryIndex {
                return lhs.startEntryIndex < rhs.startEntryIndex
            }
            if lhs.endMeasureIndexInPart != rhs.endMeasureIndexInPart {
                return lhs.endMeasureIndexInPart < rhs.endMeasureIndexInPart
            }
            if lhs.endEntryIndex != rhs.endEntryIndex {
                return lhs.endEntryIndex < rhs.endEntryIndex
            }
            return optionalNumberSortValue(lhs.number) < optionalNumberSortValue(rhs.number)
        }
        let articulations = measureRenderPlans.flatMap(\.articulations)
        let fingerings = measureRenderPlans.flatMap(\.fingerings)
        let stringNumbers = measureRenderPlans.flatMap(\.stringNumbers)
        let tabPositions = measureRenderPlans.flatMap(\.tabPositions)
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
                canvasHeight = computedContentHeight(for: score, notes: notes, staves: staves)
            }
        }

        return VexRenderPlan(
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            pageCount: pageCount,
            autoBeam: score.autoBeam,
            title: score.score.title,
            composer: score.score.composer,
            lyricist: score.score.lyricist,
            partNames: Dictionary(
                uniqueKeysWithValues: score.score.parts.enumerated().compactMap { index, part in
                    part.name.map { (index, $0) }
                }
            ),
            partAbbreviations: Dictionary(
                uniqueKeysWithValues: score.score.parts.enumerated().compactMap { index, part in
                    part.abbreviation.map { (index, $0) }
                }
            ),
            staves: staves,
            measures: measures,
            measureBoundaries: measureBoundaries,
            notes: notes,
            inlineClefChanges: inlineClefChanges,
            beams: beams,
            tuplets: tuplets,
            ties: ties,
            slurs: slurs,
            articulations: articulations,
            fingerings: fingerings,
            stringNumbers: stringNumbers,
            tabPositions: tabPositions,
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

    public func executeRenderPlan(
        _ plan: VexRenderPlan,
        activeBeatRange: ClosedRange<Double>? = nil
    ) -> VexFactoryExecution {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let signpost = VexRendererSignpost.begin("executeRenderPlan")
        defer {
            let elapsedMS = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
            VexRenderMetrics.recordExecuteRenderPlan(
                durationMS: elapsedMS,
                elementCount: plan.renderedElementEstimate
            )
            VexRendererSignpost.end("executeRenderPlan", signpost)
        }

        FontLoader.loadDefaultFonts()

        let factory = Factory(
            options: FactoryOptions(width: plan.canvasWidth, height: plan.canvasHeight)
        )

        struct StaveLookupKey: Hashable {
            let systemIndex: Int
            let partIndex: Int
        }

        let sortedStavePlans = plan.staves
            .sorted { $0.systemIndex < $1.systemIndex }
        let tabStaveKeys = Set(plan.tabPositions.map { tabPositionPlan in
            StaveLookupKey(
                systemIndex: tabPositionPlan.systemIndex,
                partIndex: tabPositionPlan.partIndex
            )
        })
        var keySignatureAvailabilityCache: [String: Bool] = [:]
        var parsedClefNameCache: [String: ClefName?] = [:]
        var parsedTimeSignatureSpecCache: [String: TimeSignatureSpec?] = [:]
        var parsedStaffKeySpecCache: [String: StaffKeySpec?] = [:]

        func hasKeySignature(_ keySignature: String) -> Bool {
            if let cached = keySignatureAvailabilityCache[keySignature] {
                return cached
            }
            let resolved = Tables.hasKeySignature(keySignature)
            keySignatureAvailabilityCache[keySignature] = resolved
            return resolved
        }

        func clefName(from rawClef: String) -> ClefName? {
            if let cached = parsedClefNameCache[rawClef] {
                return cached
            }
            let resolved = ClefName(parsing: rawClef)
            parsedClefNameCache[rawClef] = resolved
            return resolved
        }

        func timeSignatureSpec(from rawTimeSignature: String) -> TimeSignatureSpec? {
            if let cached = parsedTimeSignatureSpecCache[rawTimeSignature] {
                return cached
            }
            let resolved = TimeSignatureSpec(parsing: rawTimeSignature, validate: false)
            parsedTimeSignatureSpecCache[rawTimeSignature] = resolved
            return resolved
        }

        func staffKeySpec(from rawToken: String) -> StaffKeySpec? {
            if let cached = parsedStaffKeySpecCache[rawToken] {
                return cached
            }
            let resolved = try? StaffKeySpec(parsing: rawToken)
            parsedStaffKeySpecCache[rawToken] = resolved
            return resolved
        }

        let createdStaves = sortedStavePlans
            .map { stavePlan in
                let lookupKey = StaveLookupKey(
                    systemIndex: stavePlan.systemIndex,
                    partIndex: stavePlan.partIndex
                )
                if tabStaveKeys.contains(lookupKey) {
                    let tabStaveOptions = StaveOptions(
                        spaceBelowStaffLn: 0,
                        spaceAboveStaffLn: 0,
                        spacingBetweenLinesPx: Tables.STAVE_LINE_DISTANCE * 1.3
                    )
                    return factory.TabStave(
                        x: stavePlan.frame.x,
                        y: stavePlan.frame.y,
                        width: stavePlan.frame.width,
                        options: tabStaveOptions
                    ) as Stave
                }
                let staveOptions = StaveOptions(
                    spaceBelowStaffLn: 0,
                    spaceAboveStaffLn: 0
                )
                return factory.Stave(
                    x: stavePlan.frame.x,
                    y: stavePlan.frame.y,
                    width: stavePlan.frame.width,
                    options: staveOptions
                ) as Stave
            }

        for (stavePlan, stave) in zip(sortedStavePlans, createdStaves) {
            let lookupKey = StaveLookupKey(
                systemIndex: stavePlan.systemIndex,
                partIndex: stavePlan.partIndex
            )
            let isTabSystem = tabStaveKeys.contains(lookupKey)
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
            if isTabSystem {
                _ = stave.setNumLines(6)
                if let tabStave = stave as? TabStave {
                    _ = tabStave.addTabGlyph()
                } else {
                    _ = stave.addClef(.tab)
                }
                continue
            }

            if let clefRaw = stavePlan.initialClef,
               let clefName = clefName(from: clefRaw) {
                let annotation = stavePlan.initialClefAnnotation.flatMap {
                    ClefAnnotation(rawValue: $0)
                }
                _ = stave.addClef(clefName, annotation: annotation)
            }

            if let keySignature = stavePlan.initialKeySignature,
               hasKeySignature(keySignature) {
                _ = stave.addKeySignature(keySignature)
            }

            if let timeSignature = stavePlan.initialTimeSignature,
               let timeSignatureSpec = timeSignatureSpec(from: timeSignature) {
                _ = stave.addTimeSignature(timeSignatureSpec)
            }

            // Render instrument name to the left of the stave.
            // First system: full name; subsequent systems: abbreviation.
            if !plan.partNames.isEmpty {
                let label: String?
                if stavePlan.systemIndex == 0 {
                    label = plan.partNames[stavePlan.partIndex]
                } else {
                    label = plan.partAbbreviations[stavePlan.partIndex]
                }
                if let label, !label.isEmpty {
                    let nameText = StaveText(
                        text: label,
                        position: .left
                    )
                    _ = nameText.setFont(FontInfo(
                        family: VexFont.SERIF,
                        size: 11,
                        weight: VexFontWeight.normal.rawValue,
                        style: VexFontStyle.normal.rawValue
                    ))
                    _ = stave.addModifier(nameText)
                }
            }

            // Render multi-measure rest if present.
            if let mmrCount = stavePlan.multipleRestCount, mmrCount > 1 {
                let mmr = factory.MultiMeasureRest(
                    numberOfMeasures: mmrCount,
                    options: MultiMeasureRestRenderOptions(numberOfMeasures: mmrCount)
                )
                _ = mmr.setStave(stave)
            }
        }

        // Add score metadata text (title, composer, lyricist) to the first system's top stave.
        if let firstStaveKey = sortedStavePlans.firstIndex(where: { $0.systemIndex == 0 }),
           createdStaves.indices.contains(firstStaveKey) {
            let firstStave = createdStaves[firstStaveKey]
            if let title = plan.title, title != "Untitled Score" {
                let titleText = StaveText(
                    text: title,
                    position: .above,
                    shiftY: -14,
                    justification: .center
                )
                _ = titleText.setFont(FontInfo(
                    family: VexFont.SERIF,
                    size: 18,
                    weight: VexFontWeight.bold.rawValue,
                    style: VexFontStyle.normal.rawValue
                ))
                _ = firstStave.addModifier(titleText)
            }
            if let composer = plan.composer {
                let composerText = StaveText(
                    text: composer,
                    position: .above,
                    shiftY: 0,
                    justification: .right
                )
                _ = composerText.setFont(FontInfo(
                    family: VexFont.SERIF,
                    size: 12,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.italic.rawValue
                ))
                _ = firstStave.addModifier(composerText)
            }
            if let lyricist = plan.lyricist {
                let lyricistText = StaveText(
                    text: lyricist,
                    position: .above,
                    shiftY: 0,
                    justification: .left
                )
                _ = lyricistText.setFont(FontInfo(
                    family: VexFont.SERIF,
                    size: 12,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.italic.rawValue
                ))
                _ = firstStave.addModifier(lyricistText)
            }
        }

        let stavesByLookupKey = Dictionary(
            uniqueKeysWithValues: zip(
                sortedStavePlans.map { stavePlan in
                    StaveLookupKey(
                        systemIndex: stavePlan.systemIndex,
                        partIndex: stavePlan.partIndex
                    )
                },
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
        struct MeasureColumnKey: Hashable {
            let systemIndex: Int
            let measureIndexInPart: Int
        }
        struct MeasureColumnAlignmentRecord {
            let stave: Stave
            let tickContextsByOnset: [Int: TickContext]
            let minimumAbsoluteX: Double
            let maximumAbsoluteX: Double
        }
        struct DeferredTempoMark {
            let groupKey: NoteGroupKey
            let plan: VexTempoMarkPlan
        }
        struct DeferredRoadmapRepetition {
            let groupKey: NoteGroupKey
            let plan: VexRoadmapRepetitionPlan
        }

        struct NoteSourceInfo {
            let entryKey: NoteEntryKey
            let partIndex: Int
            let measureIndexInPart: Int
            let sourceOrder: Int
            let crossStaffTarget: Int?
        }

        var createdVoices: [Voice] = []
        var createdNotes: [StaveNote] = []
        var createdTabNotes: [VexFoundation.TabNote] = []
        var noteSourceInfoByEntryKey: [NoteEntryKey: NoteSourceInfo] = [:]
        var createdBeams: [Beam] = []
        var createdTuplets: [Tuplet] = []
        var createdTies: [StaveTie] = []
        var createdSlurs: [Curve] = []
        var createdGlissandos: [StaveLine] = []
        var createdArticulations: [VexFoundation.Articulation] = []
        var createdFingerings: [VexFoundation.FretHandFinger] = []
        var createdStringNumbers: [VexFoundation.StringNumber] = []
        var createdLyrics: [VexFoundation.Annotation] = []
        var createdChordSymbols: [VexFoundation.ChordSymbol] = []
        var createdDirectionTexts: [VexFoundation.Annotation] = []
        var createdTempoMarks: [StaveTempo] = []
        var createdRoadmapRepetitions: [StaveRepetition] = []
        var createdDirectionWedges: [StaveHairpin] = []
        var createdOctaveShiftSpanners: [TextBracket] = []
        var createdPedalMarkings: [PedalMarking] = []
        var createdLyricConnectors: [VexFoundation.Annotation] = []
        var measureColumnAlignmentRecords: [MeasureColumnKey: [MeasureColumnAlignmentRecord]] = [:]
        var deferredTempoMarks: [DeferredTempoMark] = []
        var deferredRoadmapRepetitions: [DeferredRoadmapRepetition] = []
        let quarterTickThreshold = Tables.durationToTicks("4").map(Double.init)
        let stavePadding = (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("stave.padding") as? Double) ?? 0
        let groupedNotes = Dictionary(grouping: plan.notes) { notePlan in
            NoteGroupKey(
                systemIndex: notePlan.systemIndex,
                partIndex: notePlan.partIndex,
                measureIndexInPart: notePlan.measureIndexInPart
            )
        }
        let groupedInlineClefChanges = Dictionary(grouping: plan.inlineClefChanges) { clefPlan in
            NoteGroupKey(
                systemIndex: clefPlan.systemIndex,
                partIndex: clefPlan.partIndex,
                measureIndexInPart: clefPlan.measureIndexInPart
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
        let groupedArticulations = Dictionary(grouping: plan.articulations) { articulationPlan in
            NoteGroupKey(
                systemIndex: articulationPlan.systemIndex,
                partIndex: articulationPlan.partIndex,
                measureIndexInPart: articulationPlan.measureIndexInPart
            )
        }
        let groupedFingerings = Dictionary(grouping: plan.fingerings) { fingeringPlan in
            NoteGroupKey(
                systemIndex: fingeringPlan.systemIndex,
                partIndex: fingeringPlan.partIndex,
                measureIndexInPart: fingeringPlan.measureIndexInPart
            )
        }
        let groupedStringNumbers = Dictionary(grouping: plan.stringNumbers) { stringNumberPlan in
            NoteGroupKey(
                systemIndex: stringNumberPlan.systemIndex,
                partIndex: stringNumberPlan.partIndex,
                measureIndexInPart: stringNumberPlan.measureIndexInPart
            )
        }
        let groupedTabPositions = Dictionary(grouping: plan.tabPositions) { tabPositionPlan in
            NoteGroupKey(
                systemIndex: tabPositionPlan.systemIndex,
                partIndex: tabPositionPlan.partIndex,
                measureIndexInPart: tabPositionPlan.measureIndexInPart
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

        // Pre-compute per-system below-staff stacking offsets.
        // Categories stack in this order (closest to staff first):
        //   direction text (dynamics) → wedges → pedals → lyrics
        // Each category that is present shifts subsequent categories further down.
        struct BelowStaffOffsets {
            var wedgeYShift: Double = 0
            var pedalLineOffset: Double = 0
            var lyricTextLineOffset: Double = 0
        }
        var belowStaffOffsetsBySystem: [Int: BelowStaffOffsets] = [:]
        do {
            var systemIndices: Set<Int> = []
            for key in sortedNoteGroups { systemIndices.insert(key.systemIndex) }

            for systemIndex in systemIndices {
                let hasDirectionTextBelow = plan.directionTexts.contains {
                    $0.systemIndex == systemIndex && ($0.placement == .below || $0.placement == nil)
                }
                let hasDynamicsBelow = plan.notes.contains {
                    $0.systemIndex == systemIndex && !$0.dynamics.isEmpty
                }
                let hasWedgesBelow = plan.directionWedges.contains {
                    $0.systemIndex == systemIndex && ($0.placement == .below || $0.placement == nil)
                }
                let hasPedals = plan.pedalMarkings.contains {
                    $0.systemIndex == systemIndex
                }
                let hasLyrics = plan.lyrics.contains {
                    $0.systemIndex == systemIndex
                }

                var offsets = BelowStaffOffsets()

                // Check if this system has notes with stems extending below the staff.
                // If so, pedals and lyrics need extra offset to avoid collision.
                let hasLowStemNotes = plan.notes.contains { notePlan in
                    guard notePlan.systemIndex == systemIndex,
                          notePlan.stemDirection == .some(.down) else { return false }
                    // Check if note is below the staff
                    for token in notePlan.keyTokens {
                        let parts = token.split(separator: "/")
                        if parts.count >= 2, let octave = Int(parts[1]) {
                            let clefMiddle: Int
                            switch notePlan.clef {
                            case "bass": clefMiddle = 3
                            case "alto", "tenor": clefMiddle = 4
                            default: clefMiddle = 4 // treble
                            }
                            if octave <= clefMiddle - 1 { return true }
                        }
                    }
                    return false
                }
                let stemExtensionShift: Double = hasLowStemNotes ? 16 : 0

                // Direction text and dynamics are rendered at the default position
                // (directly below the stave/stem). Other categories must shift down
                // to avoid overlapping them.
                var cumulativeShift: Double = stemExtensionShift
                if hasDirectionTextBelow || hasDynamicsBelow {
                    cumulativeShift += 20
                }

                // Wedges: shift by cumulative amount from dynamics above them
                offsets.wedgeYShift = cumulativeShift
                if hasWedgesBelow {
                    cumulativeShift += 18
                }

                // Pedals: shift by cumulative from dynamics + wedges
                // pedalLine is in "text line" units (~10px each)
                offsets.pedalLineOffset = cumulativeShift / 10.0
                if hasPedals {
                    // PedalMarking internally adds +3 to the line value, plus ~2 lines
                    // for the marking height. Advance cumulative past the pedal's
                    // actual visual bottom so lyrics don't overlap.
                    cumulativeShift = (offsets.pedalLineOffset + 5.5) * 10.0
                }

                // Lyrics: shift by cumulative from all above categories
                // textLine is in annotation spacing units (~10px each)
                offsets.lyricTextLineOffset = cumulativeShift / 10.0

                // Only store offsets if there are stacking categories that need shifting
                if hasLyrics || hasPedals || hasWedgesBelow {
                    belowStaffOffsetsBySystem[systemIndex] = offsets
                }
            }
        }

        var allAnchorNotesByEntryKey: [NoteEntryKey: Note] = [:]
        var lyricVoiceOffsetByGroupVoice: [GroupVoiceKey: Int] = [:]
        for groupKey in sortedNoteGroups {
            guard let stave = stavesByLookupKey[
                StaveLookupKey(
                    systemIndex: groupKey.systemIndex,
                    partIndex: groupKey.partIndex
                )
            ],
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
            var anchorNotesByEntryKey: [NoteEntryKey: Note] = [:]
            let tabPositionsByEntryKey: [NoteEntryKey: [VexTabPositionPlan]] = {
                guard let tabPlans = groupedTabPositions[groupKey], !tabPlans.isEmpty else {
                    return [:]
                }
                var mapping: [NoteEntryKey: [VexTabPositionPlan]] = [:]
                let sortedTabPlans = tabPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                        return lhs.entryIndexInVoice < rhs.entryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for tabPlan in sortedTabPlans {
                    mapping[
                        NoteEntryKey(
                            systemIndex: tabPlan.systemIndex,
                            partIndex: tabPlan.partIndex,
                            measureIndexInPart: tabPlan.measureIndexInPart,
                            voice: tabPlan.voice,
                            entryIndexInVoice: tabPlan.entryIndexInVoice
                        ),
                        default: []
                    ].append(tabPlan)
                }
                return mapping
            }()
            let inlineClefChangesByEntryKey: [NoteEntryKey: [VexInlineClefChangePlan]] = {
                guard let clefPlans = groupedInlineClefChanges[groupKey], !clefPlans.isEmpty else {
                    return [:]
                }
                var mapping: [NoteEntryKey: [VexInlineClefChangePlan]] = [:]
                let sortedClefPlans = clefPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    return lhs.entryIndexInVoice < rhs.entryIndexInVoice
                }
                for clefPlan in sortedClefPlans {
                    mapping[
                        NoteEntryKey(
                            systemIndex: clefPlan.systemIndex,
                            partIndex: clefPlan.partIndex,
                            measureIndexInPart: clefPlan.measureIndexInPart,
                            voice: clefPlan.voice,
                            entryIndexInVoice: clefPlan.entryIndexInVoice
                        ),
                        default: []
                    ].append(clefPlan)
                }
                return mapping
            }()

            // Ghost note voice alignment (4.15): collect onset positions per voice
            // for multi-voice measures to insert ghost note spacers.
            let allOnsetsByVoice: [Int: Set<Int>] = {
                var result: [Int: Set<Int>] = [:]
                for v in sortedVoices {
                    guard let plans = groupedByVoice[v] else { continue }
                    result[v] = Set(plans.map(\.onsetDivisions))
                }
                return result
            }()
            let globalOnsets: Set<Int> = allOnsetsByVoice.values.reduce(into: Set<Int>()) { $0.formUnion($1) }
            let needsGhostNotes = sortedVoices.count > 1

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
                let voiceStemDirection: StemDirection? = sortedVoices.count > 1
                    ? (voiceNumber == sortedVoices.first ? .up : .down)
                    : nil

                let voiceOnsetSet = allOnsetsByVoice[voiceNumber] ?? []

                var voiceTickables: [Tickable] = []
                var voiceNotes: [StaveNote] = []

                // Insert leading ghost notes for onsets that exist globally but not in this voice,
                // if they fall before this voice's first note.
                if needsGhostNotes, let firstPlan = sortedVoicePlans.first {
                    let leadingOnsets = globalOnsets.filter { $0 < firstPlan.onsetDivisions && !voiceOnsetSet.contains($0) }.sorted()
                    for onset in leadingOnsets {
                        let nextOnset = (globalOnsets.filter { $0 > onset }.min()) ?? firstPlan.onsetDivisions
                        let gapDivisions = nextOnset - onset
                        let divisions = firstPlan.divisions
                        if gapDivisions > 0, divisions > 0 {
                            let ghostDuration = noteDurationSpec(
                                durationDivisions: gapDivisions,
                                divisions: divisions,
                                isRest: true
                            )
                            let ghost = factory.GhostNote(duration: ghostDuration.value, dots: ghostDuration.dots)
                            voiceTickables.append(ghost)
                        }
                    }
                }

                for (planIdx, notePlan) in sortedVoicePlans.enumerated() {
                    // Insert inter-note ghost notes for global onsets between the
                    // previous note's end and this note's onset.
                    if needsGhostNotes {
                        let prevEnd: Int
                        if planIdx == 0 {
                            // After leading ghosts, prevEnd is the first note's onset
                            // (leading ghosts already cover before that).
                            prevEnd = notePlan.onsetDivisions
                        } else {
                            let prev = sortedVoicePlans[planIdx - 1]
                            prevEnd = prev.onsetDivisions + prev.durationDivisions
                        }
                        let gapOnsets = globalOnsets
                            .filter { $0 >= prevEnd && $0 < notePlan.onsetDivisions && !voiceOnsetSet.contains($0) }
                            .sorted()
                        for onset in gapOnsets {
                            let nextOnset = (globalOnsets.filter { $0 > onset }.min()) ?? notePlan.onsetDivisions
                            let gapDivisions = min(nextOnset, notePlan.onsetDivisions) - onset
                            let divisions = notePlan.divisions
                            if gapDivisions > 0, divisions > 0 {
                                let ghostDuration = noteDurationSpec(
                                    durationDivisions: gapDivisions,
                                    divisions: divisions,
                                    isRest: true
                                )
                                let ghost = factory.GhostNote(duration: ghostDuration.value, dots: ghostDuration.dots)
                                voiceTickables.append(ghost)
                            }
                        }
                    }

                    // Prefer explicit stem direction from MusicXML when available.
                    let stemDirection: StemDirection?
                    if let parsed = notePlan.stemDirection {
                        switch parsed {
                        case .up:
                            stemDirection = .up
                        case .down:
                            stemDirection = .down
                        case .none, .double:
                            stemDirection = voiceStemDirection
                        }
                    } else {
                        stemDirection = voiceStemDirection
                    }
                    let entryKey = NoteEntryKey(
                        systemIndex: notePlan.systemIndex,
                        partIndex: notePlan.partIndex,
                        measureIndexInPart: notePlan.measureIndexInPart,
                        voice: notePlan.voice,
                        entryIndexInVoice: notePlan.entryIndexInVoice
                    )
                    if let tabPositionPlans = tabPositionsByEntryKey[entryKey],
                       !tabPositionPlans.isEmpty,
                       let tabNote = makeTabNote(
                            from: notePlan,
                            tabPositions: tabPositionPlans,
                            factory: factory,
                            stave: stave,
                            stemDirection: stemDirection
                       ) {
                        voiceTickables.append(tabNote)
                        createdTabNotes.append(tabNote)
                        anchorNotesByEntryKey[entryKey] = tabNote
                        allAnchorNotesByEntryKey[entryKey] = tabNote
                        continue
                    }

                    guard let note = makeStaveNote(
                        from: notePlan,
                        factory: factory,
                        stave: stave,
                        keys: notePlan.keyTokens.compactMap(staffKeySpec(from:)),
                        clefName: notePlan.clef.flatMap(clefName(from:)),
                        stemDirection: stemDirection
                    ) else {
                        continue
                    }

                    // Render clef changes inline at measure transitions by attaching
                    // a small ClefNote as a NoteSubGroup modifier.
                    if let clefPlans = inlineClefChangesByEntryKey[entryKey] {
                        for clefPlan in clefPlans {
                            guard let inlineClefName = clefName(from: clefPlan.clef) else {
                                continue
                            }
                            let inlineClefAnnotation = clefPlan.annotation.flatMap {
                                ClefAnnotation(rawValue: $0)
                            }
                            let clefNote = factory.ClefNote(
                                type: inlineClefName,
                                size: .small,
                                annotation: inlineClefAnnotation
                            )
                            let subgroup = factory.NoteSubGroup(notes: [clefNote])
                            _ = note.addModifier(subgroup, index: 0)
                        }
                    }

                    // Attach explicit accidentals from MusicXML <accidental> element.
                    if let accidentalValue = notePlan.accidental,
                       let accidentalType = vexAccidentalType(for: accidentalValue) {
                        let accidental = factory.Accidental(type: accidentalType)
                        _ = note.addModifier(accidental, index: 0)
                    }

                    // Attach grace notes as a GraceNoteGroup modifier.
                    if !notePlan.graceNotes.isEmpty {
                        let graceNotes: [StemmableNote] = notePlan.graceNotes.compactMap { gracePlan in
                            let keys: [StaffKeySpec] = gracePlan.keyTokens.compactMap { token in
                                staffKeySpec(from: token)
                            }
                            guard let nonEmptyKeys = NonEmptyArray(validating: keys) else {
                                return nil
                            }
                            let duration: NoteDurationSpec
                            if let noteType = gracePlan.noteType, let vexValue = vexNoteValue(for: noteType) {
                                duration = NoteDurationSpec(uncheckedValue: vexValue, type: .note)
                            } else {
                                duration = .eighth
                            }
                            return factory.GraceNote(
                                GraceNoteStruct(
                                    keys: nonEmptyKeys,
                                    duration: duration,
                                    slash: gracePlan.slash
                                )
                            )
                        }
                        if !graceNotes.isEmpty {
                            let group = factory.GraceNoteGroup(notes: graceNotes, slur: true)
                            _ = group.beamNotes()
                            _ = note.addModifier(group, index: 0)
                        }
                    }

                    // Attach ornaments (trill, mordent, turn, etc.).
                    for ornament in notePlan.ornaments {
                        if let vexOrnamentType = vexOrnamentType(for: ornament.kind) {
                            let ornamentMod = Ornament(vexOrnamentType)
                            _ = ornamentMod.setPosition(
                                ornament.placement == "below" ? .below : .above
                            )
                            _ = note.addModifier(ornamentMod, index: 0)
                        }
                    }

                    // Attach arpeggio stroke.
                    if let arpeggiate = notePlan.arpeggiate {
                        let strokeType: StrokeType
                        switch arpeggiate.direction {
                        case .up: strokeType = .rollUp
                        case .down: strokeType = .rollDown
                        case .none: strokeType = .arpeggioDirectionless
                        }
                        _ = note.addModifier(Stroke(type: strokeType), index: 0)
                    }

                    // Attach tremolo bars.
                    if let tremolo = notePlan.tremolo, tremolo.type == .single {
                        _ = note.addModifier(Tremolo(tremolo.bars), index: 0)
                    }

                    // Attach note-level dynamics (from <notations><dynamics>).
                    for dynamic in notePlan.dynamics {
                        if let text = directionTextValue(for: dynamic) {
                            let annotation = factory.Annotation(text: text)
                            _ = annotation.setFont(FontInfo(
                                family: VexFont.SERIF,
                                size: 12,
                                weight: VexFontWeight.bold.rawValue,
                                style: VexFontStyle.italic.rawValue
                            ))
                            _ = annotation.setVerticalJustification(AnnotationVerticalJustify.bottom)
                            _ = note.addModifier(annotation, index: 0)
                        }
                    }

                    // Apply note color if specified in MusicXML.
                    if let color = notePlan.color {
                        _ = note.setStyle(ElementStyle(
                            fillStyle: color,
                            strokeStyle: color
                        ))
                    }

                    voiceTickables.append(note)
                    voiceNotes.append(note)
                    notesByEntryKey[entryKey] = note
                    anchorNotesByEntryKey[entryKey] = note
                    allAnchorNotesByEntryKey[entryKey] = note
                    noteSourceInfoByEntryKey[entryKey] = NoteSourceInfo(
                        entryKey: entryKey,
                        partIndex: notePlan.partIndex,
                        measureIndexInPart: notePlan.measureIndexInPart,
                        sourceOrder: notePlan.sourceOrder,
                        crossStaffTarget: notePlan.crossStaffTarget
                    )
                }

                // Insert trailing ghost notes after the last note for any remaining
                // global onsets that this voice doesn't cover.
                if needsGhostNotes, let lastPlan = sortedVoicePlans.last {
                    let lastEnd = lastPlan.onsetDivisions + lastPlan.durationDivisions
                    let trailingOnsets = globalOnsets
                        .filter { $0 >= lastEnd && !voiceOnsetSet.contains($0) }
                        .sorted()
                    for onset in trailingOnsets {
                        let nextOnset = globalOnsets.filter { $0 > onset }.min()
                        let gapDivisions: Int
                        if let next = nextOnset {
                            gapDivisions = next - onset
                        } else {
                            // Last global onset — use a quarter-note-equivalent.
                            gapDivisions = lastPlan.divisions
                        }
                        let divisions = lastPlan.divisions
                        if gapDivisions > 0, divisions > 0 {
                            let ghostDuration = noteDurationSpec(
                                durationDivisions: gapDivisions,
                                divisions: divisions,
                                isRest: true
                            )
                            let ghost = factory.GhostNote(duration: ghostDuration.value, dots: ghostDuration.dots)
                            voiceTickables.append(ghost)
                        }
                    }
                }

                guard !voiceTickables.isEmpty else {
                    continue
                }

                let meterBeats = max(1, sortedVoicePlans.first?.timeSignatureBeats ?? 4)
                let meterBeatType = max(1, sortedVoicePlans.first?.timeSignatureBeatType ?? 4)
                let voice = factory.Voice(timeSignature: .meter(meterBeats, meterBeatType))
                _ = voice.setMode(.soft)
                _ = voice.setStave(stave)
                _ = voice.addTickables(voiceTickables)

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
                    guard let note = anchorNotesByEntryKey[
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
                    let lyricStackingOffset = belowStaffOffsetsBySystem[lyricPlan.systemIndex]?.lyricTextLineOffset ?? 0
                    _ = annotation.setTextLine(
                        lyricTextLine(verse: lyricPlan.verse, voiceOffset: voiceOffset, stackingOffset: lyricStackingOffset)
                    )
                    _ = note.addModifier(annotation, index: 0)
                    createdLyrics.append(annotation)
                }
            }

            if let fingeringPlans = groupedFingerings[groupKey] {
                let sortedFingeringPlans = fingeringPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                        return lhs.entryIndexInVoice < rhs.entryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for fingeringPlan in sortedFingeringPlans {
                    guard let note = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: fingeringPlan.systemIndex,
                            partIndex: fingeringPlan.partIndex,
                            measureIndexInPart: fingeringPlan.measureIndexInPart,
                            voice: fingeringPlan.voice,
                            entryIndexInVoice: fingeringPlan.entryIndexInVoice
                        )
                    ], !note.isRest() else {
                        continue
                    }

                    let fingering: VexFoundation.FretHandFinger
                    if let position = fingeringModifierPosition(for: fingeringPlan.position) {
                        fingering = factory.Fingering(number: fingeringPlan.number, position: position)
                    } else {
                        fingering = factory.Fingering(number: fingeringPlan.number)
                    }
                    _ = note.addModifier(fingering, index: 0)
                    createdFingerings.append(fingering)
                }
            }

            if let stringNumberPlans = groupedStringNumbers[groupKey] {
                let sortedStringNumberPlans = stringNumberPlans.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    if lhs.entryIndexInVoice != rhs.entryIndexInVoice {
                        return lhs.entryIndexInVoice < rhs.entryIndexInVoice
                    }
                    return lhs.sourceOrder < rhs.sourceOrder
                }
                for stringNumberPlan in sortedStringNumberPlans {
                    guard let note = notesByEntryKey[
                        NoteEntryKey(
                            systemIndex: stringNumberPlan.systemIndex,
                            partIndex: stringNumberPlan.partIndex,
                            measureIndexInPart: stringNumberPlan.measureIndexInPart,
                            voice: stringNumberPlan.voice,
                            entryIndexInVoice: stringNumberPlan.entryIndexInVoice
                        )
                    ], !note.isRest() else {
                        continue
                    }

                    let stringNumber: VexFoundation.StringNumber
                    if let position = stringNumberModifierPosition(for: stringNumberPlan.position) {
                        stringNumber = factory.StringNumber(number: stringNumberPlan.number, position: position)
                    } else {
                        stringNumber = factory.StringNumber(number: stringNumberPlan.number)
                    }
                    _ = note.addModifier(stringNumber, index: 0)
                    createdStringNumbers.append(stringNumber)
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
                    guard let note = anchorNotesByEntryKey[
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
                    let verticalJustify = chordSymbolVerticalJustify(for: chordSymbolPlan.placement)
                    let chordSymbol = factory.ChordSymbol(vJustify: verticalJustify, hJustify: .center)
                    _ = chordSymbol.addGlyphOrText(chordSymbolPlan.displayText)
                    _ = chordSymbol.setPosition(chordSymbolModifierPosition(for: chordSymbolPlan.placement))
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
                    guard let note = anchorNotesByEntryKey[
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
                    // Apply stacking Y shift so wedges don't overlap dynamics text
                    if wedgePlan.placement != .above,
                       let offsets = belowStaffOffsetsBySystem[wedgePlan.systemIndex] {
                        wedge.renderOptions.yShift = offsets.wedgeYShift
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
                    // Apply stacking line offset so pedals don't overlap wedges/dynamics
                    if let offsets = belowStaffOffsetsBySystem[pedalPlan.systemIndex] {
                        _ = pedal.setLine(offsets.pedalLineOffset)
                    }
                    createdPedalMarkings.append(pedal)
                }
            }

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
            let leadingInset = max(desiredAbsoluteStartX - anchorPlan.measureFrame.x, 0)
            let trailingInset = 4.0
            let justifyWidth = max(
                12,
                anchorPlan.measureFrame.width - leadingInset - trailingInset
            )

            // Cross-staff note reassignment (4.14): reassign notes to their
            // target stave when crossStaffTarget is set.
            for (entryKey, sourceInfo) in noteSourceInfoByEntryKey {
                guard entryKey.systemIndex == groupKey.systemIndex,
                      entryKey.partIndex == groupKey.partIndex,
                      entryKey.measureIndexInPart == groupKey.measureIndexInPart,
                      let targetStaff = sourceInfo.crossStaffTarget,
                      let note = allAnchorNotesByEntryKey[entryKey] as? StaveNote else {
                    continue
                }
                // crossStaffTarget is 1-based MusicXML staff number.
                // Staff 1 = current partIndex, staff 2 = partIndex+1, etc.
                let targetPartIndex = groupKey.partIndex + (targetStaff - 1)
                let targetLookupKey = StaveLookupKey(
                    systemIndex: groupKey.systemIndex,
                    partIndex: targetPartIndex
                )
                if let targetStave = stavesByLookupKey[targetLookupKey], targetStave !== stave {
                    _ = note.setStave(targetStave)
                }
            }

            let formatter = factory.Formatter()
            _ = formatter.joinVoices(measureVoices).format(
                measureVoices,
                justifyWidth: justifyWidth,
                options: FormatParams(alignRests: true, stave: stave)
            )

            let contexts = formatter.getTickContexts().array

            // Safety-net: when the formatter's minimum-width layout exceeds the
            // available measure width, compress all tick context positions
            // proportionally so notes fit within the measure.
            if contexts.count >= 2,
               let ctxMinX = contexts.map({ $0.getX() }).min(),
               let ctxMaxX = contexts.map({ $0.getX() }).max() {
                let formatterSpan = ctxMaxX - ctxMinX
                if formatterSpan > justifyWidth && justifyWidth > 0 {
                    let scale = justifyWidth / formatterSpan
                    let sortedX = contexts.map({ $0.getX() }).sorted()
                    var minGap = Double.infinity
                    if sortedX.count >= 2 {
                        for index in 1..<sortedX.count {
                            minGap = min(minGap, sortedX[index] - sortedX[index - 1])
                        }
                    }
                    // Keep dense passages readable: avoid post-format compression that
                    // would force adjacent tick contexts too close together.
                    let minimumAllowedGap = 12.0
                    if minGap.isFinite, minGap * scale >= minimumAllowedGap {
                        for context in contexts {
                            let relativeX = context.getX() - ctxMinX
                            _ = context.setX(ctxMinX + relativeX * scale)
                        }
                    }
                }
            }

            if let minX = contexts.map({ $0.getX() }).min() {
                let desiredRelativeStartX = desiredAbsoluteStartX - stave.getNoteStartX() - stavePadding
                let delta = desiredRelativeStartX - minX
                for context in contexts {
                    _ = context.setX(context.getX() + delta)
                }
            }

            var tickContextsByOnset: [Int: TickContext] = [:]
            for notePlan in sortedPlans {
                let entryKey = NoteEntryKey(
                    systemIndex: notePlan.systemIndex,
                    partIndex: notePlan.partIndex,
                    measureIndexInPart: notePlan.measureIndexInPart,
                    voice: notePlan.voice,
                    entryIndexInVoice: notePlan.entryIndexInVoice
                )
                guard anchorNotesByEntryKey[entryKey] != nil else {
                    continue
                }
                if tickContextsByOnset[notePlan.onsetDivisions] == nil,
                   let anchorNote = anchorNotesByEntryKey[entryKey] {
                    tickContextsByOnset[notePlan.onsetDivisions] = anchorNote.checkTickContext()
                }
            }
            if !tickContextsByOnset.isEmpty {
                let measureColumnKey = MeasureColumnKey(
                    systemIndex: groupKey.systemIndex,
                    measureIndexInPart: groupKey.measureIndexInPart
                )
                measureColumnAlignmentRecords[measureColumnKey, default: []].append(
                    MeasureColumnAlignmentRecord(
                        stave: stave,
                        tickContextsByOnset: tickContextsByOnset,
                        minimumAbsoluteX: desiredAbsoluteStartX,
                        maximumAbsoluteX: anchorPlan.measureFrame.x + anchorPlan.measureFrame.width - trailingInset
                    )
                )
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
                    deferredTempoMarks.append(
                        DeferredTempoMark(groupKey: groupKey, plan: tempoPlan)
                    )
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
                    deferredRoadmapRepetitions.append(
                        DeferredRoadmapRepetition(groupKey: groupKey, plan: roadmapPlan)
                    )
                }
            }

            if plan.autoBeam {
                // Auto-beam: use VexFoundation's beam generator on each voice.
                for voice in measureVoices {
                    if let autoBeams = try? Beam.applyAndGetBeams(voice) {
                        createdBeams.append(contentsOf: autoBeams)
                    }
                }
            } else if let beamPlans = groupedBeams[groupKey] {
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

            createdVoices.append(contentsOf: measureVoices)
            createdNotes.append(contentsOf: measureNotes)
        }

        let sortedMeasureColumnKeys = measureColumnAlignmentRecords.keys.sorted { lhs, rhs in
            if lhs.systemIndex != rhs.systemIndex {
                return lhs.systemIndex < rhs.systemIndex
            }
            return lhs.measureIndexInPart < rhs.measureIndexInPart
        }
        // Cross-stave column alignment: distribute all onset positions
        // linearly across the available measure width so that notes at the
        // same beat align vertically between staves.  This replaces per-stave
        // formatter positions (which differ because each stave formats its
        // voices independently and may have very different note densities).
        for measureColumnKey in sortedMeasureColumnKeys {
            guard let records = measureColumnAlignmentRecords[measureColumnKey],
                  records.count > 1 else {
                continue
            }
            let sortedOnsets = Set(records.flatMap { $0.tickContextsByOnset.keys }).sorted()
            guard sortedOnsets.count >= 2,
                  let firstOnset = sortedOnsets.first,
                  let lastOnset = sortedOnsets.last,
                  lastOnset > firstOnset else {
                continue
            }
            let minimumAbsoluteX = records.map(\.minimumAbsoluteX).max() ?? 0
            let maximumAbsoluteX = records.map(\.maximumAbsoluteX).min() ?? 0
            guard maximumAbsoluteX > minimumAbsoluteX else { continue }

            let availableWidth = maximumAbsoluteX - minimumAbsoluteX
            let onsetRange = Double(lastOnset - firstOnset)

            for onset in sortedOnsets {
                let ratio = Double(onset - firstOnset) / onsetRange
                let targetAbsoluteX = minimumAbsoluteX + (ratio * availableWidth)
                for record in records {
                    guard let context = record.tickContextsByOnset[onset] else {
                        continue
                    }
                    let targetRelativeX = targetAbsoluteX - record.stave.getNoteStartX() - stavePadding
                    _ = context.setX(targetRelativeX)
                }
            }
        }

        for deferredTempoMark in deferredTempoMarks {
            let tempoPlan = deferredTempoMark.plan
            guard let stave = stavesByLookupKey[
                StaveLookupKey(
                    systemIndex: tempoPlan.systemIndex,
                    partIndex: tempoPlan.partIndex
                )
            ],
            let anchorNote = allAnchorNotesByEntryKey[
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

        for deferredRoadmapRepetition in deferredRoadmapRepetitions {
            let groupKey = deferredRoadmapRepetition.groupKey
            let roadmapPlan = deferredRoadmapRepetition.plan
            guard let stave = stavesByLookupKey[
                StaveLookupKey(
                    systemIndex: groupKey.systemIndex,
                    partIndex: groupKey.partIndex
                )
            ] else {
                continue
            }

            let shiftBase = stave.getNoteStartX() - stave.getX()
            let x: Double
            switch roadmapPlan.anchor {
            case .leftEdge:
                x = stave.getX() - shiftBase
            case .rightEdge:
                x = stave.getX()
            case .entry(let voice, let entryIndexInVoice):
                guard let anchorNote = allAnchorNotesByEntryKey[
                    NoteEntryKey(
                        systemIndex: roadmapPlan.systemIndex,
                        partIndex: roadmapPlan.partIndex,
                        measureIndexInPart: roadmapPlan.measureIndexInPart,
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

        let sortedSlurPlans = plan.slurs.sorted { lhs, rhs in
            if lhs.systemIndex != rhs.systemIndex {
                return lhs.systemIndex < rhs.systemIndex
            }
            if lhs.partIndex != rhs.partIndex {
                return lhs.partIndex < rhs.partIndex
            }
            if lhs.measureIndexInPart != rhs.measureIndexInPart {
                return lhs.measureIndexInPart < rhs.measureIndexInPart
            }
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            if lhs.startEntryIndex != rhs.startEntryIndex {
                return lhs.startEntryIndex < rhs.startEntryIndex
            }
            if lhs.endSystemIndex != rhs.endSystemIndex {
                return lhs.endSystemIndex < rhs.endSystemIndex
            }
            if lhs.endPartIndex != rhs.endPartIndex {
                return lhs.endPartIndex < rhs.endPartIndex
            }
            if lhs.endMeasureIndexInPart != rhs.endMeasureIndexInPart {
                return lhs.endMeasureIndexInPart < rhs.endMeasureIndexInPart
            }
            if lhs.endEntryIndex != rhs.endEntryIndex {
                return lhs.endEntryIndex < rhs.endEntryIndex
            }
            return optionalNumberSortValue(lhs.number) < optionalNumberSortValue(rhs.number)
        }
        for slurPlan in sortedSlurPlans {
            let startKey = NoteEntryKey(
                systemIndex: slurPlan.systemIndex,
                partIndex: slurPlan.partIndex,
                measureIndexInPart: slurPlan.measureIndexInPart,
                voice: slurPlan.voice,
                entryIndexInVoice: slurPlan.startEntryIndex
            )
            let endKey = NoteEntryKey(
                systemIndex: slurPlan.endSystemIndex,
                partIndex: slurPlan.endPartIndex,
                measureIndexInPart: slurPlan.endMeasureIndexInPart,
                voice: slurPlan.voice,
                entryIndexInVoice: slurPlan.endEntryIndex
            )
            guard let startNote = allAnchorNotesByEntryKey[startKey],
                  let endNote = allAnchorNotesByEntryKey[endKey] else {
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

        // Render glissando lines.
        // Collect notes with glissando start markers and pair with stop markers.
        struct GlissandoOpenKey: Hashable {
            let partIndex: Int
            let voice: Int
            let number: Int
        }
        var glissandoStartNotes: [GlissandoOpenKey: (StaveNote, GlissandoMarker)] = [:]
        for notePlan in plan.notes {
            let entryKey = NoteEntryKey(
                systemIndex: notePlan.systemIndex,
                partIndex: notePlan.partIndex,
                measureIndexInPart: notePlan.measureIndexInPart,
                voice: notePlan.voice,
                entryIndexInVoice: notePlan.entryIndexInVoice
            )
            guard let staveNote = allAnchorNotesByEntryKey[entryKey] as? StaveNote else {
                continue
            }
            for gliss in notePlan.glissandos {
                let key = GlissandoOpenKey(
                    partIndex: notePlan.partIndex,
                    voice: notePlan.voice,
                    number: gliss.number
                )
                switch gliss.type {
                case .start:
                    glissandoStartNotes[key] = (staveNote, gliss)
                case .stop:
                    if let (startNote, startGliss) = glissandoStartNotes.removeValue(forKey: key) {
                        let line = StaveLine(notes: StaveLineNotes(
                            firstNote: startNote,
                            lastNote: staveNote
                        ))
                        if let text = startGliss.text {
                            _ = line.setText(text)
                        }
                        switch startGliss.lineType {
                        case .wavy:
                            line.lineRenderOptions.lineDash = [5, 5]
                        case .dashed:
                            line.lineRenderOptions.lineDash = [8, 4]
                        case .dotted:
                            line.lineRenderOptions.lineDash = [2, 3]
                        case .solid:
                            break
                        }
                        createdGlissandos.append(line)
                    }
                default:
                    break
                }
            }
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
            guard let startNote = allAnchorNotesByEntryKey[startKey],
                  let endNote = allAnchorNotesByEntryKey[endKey],
                  !startNote.isRest(),
                  !endNote.isRest() else {
                continue
            }

            let startX = noteHeadEndX(startNote)
            let endX = noteHeadBeginX(endNote)
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
            let connectorStackingOffset = belowStaffOffsetsBySystem[connectorPlan.startSystemIndex]?.lyricTextLineOffset ?? 0
            _ = annotation.setTextLine(
                lyricTextLine(verse: connectorPlan.verse, voiceOffset: voiceOffset, stackingOffset: connectorStackingOffset)
            )
            _ = annotation.setXShift(xShift)
            _ = startNote.addModifier(annotation, index: 0)
            createdLyricConnectors.append(annotation)
        }

        struct MeasureBoundaryGroupKey: Hashable {
            let systemIndex: Int
            let measureIndexInPart: Int
        }
        struct MeasureBoundaryGroupValue {
            var minPartIndex: Int
            var maxPartIndex: Int
            var xSum: Double
            var count: Int
        }

        var measureBoundaryGroups: [MeasureBoundaryGroupKey: MeasureBoundaryGroupValue] = [:]
        for boundaryPlan in plan.measureBoundaries {
            let key = MeasureBoundaryGroupKey(
                systemIndex: boundaryPlan.systemIndex,
                measureIndexInPart: boundaryPlan.measureIndexInPart
            )
            if var existing = measureBoundaryGroups[key] {
                existing.minPartIndex = min(existing.minPartIndex, boundaryPlan.partIndex)
                existing.maxPartIndex = max(existing.maxPartIndex, boundaryPlan.partIndex)
                existing.xSum += boundaryPlan.x
                existing.count += 1
                measureBoundaryGroups[key] = existing
            } else {
                measureBoundaryGroups[key] = MeasureBoundaryGroupValue(
                    minPartIndex: boundaryPlan.partIndex,
                    maxPartIndex: boundaryPlan.partIndex,
                    xSum: boundaryPlan.x,
                    count: 1
                )
            }
        }

        let sortedMeasureBoundaryGroups = measureBoundaryGroups.sorted { lhs, rhs in
            if lhs.key.systemIndex != rhs.key.systemIndex {
                return lhs.key.systemIndex < rhs.key.systemIndex
            }
            return lhs.key.measureIndexInPart < rhs.key.measureIndexInPart
        }

        let measureBarlineConnectors: [StaveConnector] = sortedMeasureBoundaryGroups.compactMap { group in
            guard let topStave = stavesByLookupKey[
                StaveLookupKey(
                    systemIndex: group.key.systemIndex,
                    partIndex: group.value.minPartIndex
                )
            ],
                  let bottomStave = stavesByLookupKey[
                    StaveLookupKey(
                        systemIndex: group.key.systemIndex,
                        partIndex: group.value.maxPartIndex
                    )
                  ] else {
                return nil
            }

            let boundaryX = group.value.xSum / Double(max(group.value.count, 1))

            // Avoid doubling the terminal barline at the stave's right boundary.
            let topStaveRightBoundaryX = topStave.getX() + topStave.getWidth()
            if abs(boundaryX - topStaveRightBoundaryX) < 0.5 {
                return nil
            }

            let connector = factory.StaveConnector(
                topStave: topStave,
                bottomStave: bottomStave,
                type: .singleLeft
            )
            connector.connectorWidth = 1
            connector.thickness = 1
            _ = connector.setXShift(
                connectorXShift(
                    targetX: boundaryX,
                    topStave: topStave,
                    kind: .singleLeft
                )
            )
            return connector
        }

        let partGroupConnectors: [StaveConnector] = plan.partGroupConnectors.compactMap { connectorPlan in
            guard let topStave = stavesByLookupKey[
                StaveLookupKey(
                    systemIndex: connectorPlan.startSystemIndex,
                    partIndex: connectorPlan.startPartIndex
                )
            ],
                  let bottomStave = stavesByLookupKey[
                    StaveLookupKey(
                        systemIndex: connectorPlan.endSystemIndex,
                        partIndex: connectorPlan.endPartIndex
                    )
                  ] else {
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
            guard let topStave = stavesByLookupKey[
                StaveLookupKey(
                    systemIndex: connectorPlan.startSystemIndex,
                    partIndex: connectorPlan.startPartIndex
                )
            ],
                  let bottomStave = stavesByLookupKey[
                    StaveLookupKey(
                        systemIndex: connectorPlan.endSystemIndex,
                        partIndex: connectorPlan.endPartIndex
                    )
                  ] else {
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

        // Extract per-note positions post-format (3.9).
        var extractedNotePositions: [VexNotePosition] = []
        for (entryKey, sourceInfo) in noteSourceInfoByEntryKey {
            guard let note = allAnchorNotesByEntryKey[entryKey] as? StaveNote else { continue }
            let x = note.getAbsoluteX()
            let ys = note.getYs()
            var bbox: MDKBoundingBox?
            if let vexBBox = note.getBoundingBox() {
                bbox = MDKBoundingBox(
                    x: vexBBox.x,
                    y: vexBBox.y,
                    width: vexBBox.w,
                    height: vexBBox.h
                )
            }
            extractedNotePositions.append(VexNotePosition(
                partIndex: sourceInfo.partIndex,
                measureIndexInPart: sourceInfo.measureIndexInPart,
                sourceOrder: sourceInfo.sourceOrder,
                x: x,
                ys: ys,
                boundingBox: bbox
            ))
        }

        // Apply dimmed style to elements outside the active beat range.
        // Pre-format systems so that formatting-triggered resets (e.g.
        // stem direction changes that rebuild noteheads) happen before we
        // set the dimmed style; otherwise formatting would discard the style.
        if activeBeatRange != nil {
            factory.formatSystems()
        }
        if let activeBeatRange {
            // Compute the absolute beat of each measure start from the
            // primary part (partIndex 0), matching TimelineMapBuilder logic.
            let primaryPartNotes = plan.notes
                .filter { $0.partIndex == 0 }
            var measureBeats: [Int: Double] = [:]
            var cumulativeBeat = 0.0
            let measureIndices = Set(primaryPartNotes.map(\.measureIndexInPart)).sorted()
            for measureIndex in measureIndices {
                measureBeats[measureIndex] = cumulativeBeat
                if let sample = primaryPartNotes.first(where: { $0.measureIndexInPart == measureIndex }) {
                    let measureDurationBeats = Double(sample.timeSignatureBeats) * 4.0
                        / Double(sample.timeSignatureBeatType)
                    cumulativeBeat += measureDurationBeats
                }
            }

            // Build a lookup of absolute beat per entry key.
            var absoluteBeatByEntryKey: [NoteEntryKey: Double] = [:]
            for notePlan in plan.notes {
                let key = NoteEntryKey(
                    systemIndex: notePlan.systemIndex,
                    partIndex: notePlan.partIndex,
                    measureIndexInPart: notePlan.measureIndexInPart,
                    voice: notePlan.voice,
                    entryIndexInVoice: notePlan.entryIndexInVoice
                )
                let measureStartBeat = measureBeats[notePlan.measureIndexInPart] ?? 0
                let divisions = max(notePlan.divisions, 1)
                let onsetBeat = Double(notePlan.onsetDivisions) / Double(divisions)
                absoluteBeatByEntryKey[key] = measureStartBeat + onsetBeat
            }

            let dimStyle = ElementStyle(
                fillStyle: "#B0B0B0",
                strokeStyle: "#B0B0B0"
            )
            // Build a set of dimmed note object identities for efficient lookup.
            var dimmedNotes = Set<ObjectIdentifier>()
            for (entryKey, note) in allAnchorNotesByEntryKey {
                let beat = absoluteBeatByEntryKey[entryKey]
                    ?? absoluteBeatByEntryKey[
                        NoteEntryKey(
                            systemIndex: entryKey.systemIndex,
                            partIndex: 0,
                            measureIndexInPart: entryKey.measureIndexInPart,
                            voice: entryKey.voice,
                            entryIndexInVoice: entryKey.entryIndexInVoice
                        )
                    ]
                let outsideRange: Bool
                if let beat {
                    outsideRange = beat < activeBeatRange.lowerBound - 0.001
                        || beat >= activeBeatRange.upperBound + 0.001
                } else {
                    // Fallback: dim if the entire measure is outside.
                    let mStart = measureBeats[entryKey.measureIndexInPart] ?? 0
                    let sample = primaryPartNotes.first {
                        $0.measureIndexInPart == entryKey.measureIndexInPart
                    }
                    let mDuration = sample.map {
                        Double($0.timeSignatureBeats) * 4.0 / Double($0.timeSignatureBeatType)
                    } ?? 4.0
                    let mEnd = mStart + mDuration
                    outsideRange = mEnd <= activeBeatRange.lowerBound + 0.001
                        || mStart >= activeBeatRange.upperBound - 0.001
                }
                if outsideRange {
                    _ = note.setGroupStyle(dimStyle)
                    dimmedNotes.insert(ObjectIdentifier(note))
                }
            }
            for beam in createdBeams {
                if let firstNote = beam.getNotes().first,
                   dimmedNotes.contains(ObjectIdentifier(firstNote)) {
                    _ = beam.setStyle(dimStyle)
                }
            }
            for tie in createdTies {
                let noteToCheck = tie.notes.firstNote ?? tie.notes.lastNote
                if let note = noteToCheck,
                   dimmedNotes.contains(ObjectIdentifier(note)) {
                    _ = tie.setStyle(dimStyle)
                }
            }
            for tuplet in createdTuplets {
                if let firstNote = tuplet.notes.first,
                   dimmedNotes.contains(ObjectIdentifier(firstNote)) {
                    _ = tuplet.setStyle(dimStyle)
                }
            }
            for slur in createdSlurs {
                let noteToCheck = slur.from ?? slur.to
                if let note = noteToCheck,
                   dimmedNotes.contains(ObjectIdentifier(note)) {
                    _ = slur.setStyle(dimStyle)
                }
            }
        }

        return VexFactoryExecution(
            factory: factory,
            staves: createdStaves,
            voices: createdVoices,
            notes: createdNotes,
            tabNotes: createdTabNotes,
            beams: createdBeams,
            tuplets: createdTuplets,
            ties: createdTies,
            slurs: createdSlurs,
            glissandos: createdGlissandos,
            articulations: createdArticulations,
            fingerings: createdFingerings,
            stringNumbers: createdStringNumbers,
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
            barlineConnectors: barlineConnectors,
            notePositions: extractedNotePositions
        )
    }

    /// Converts extracted note positions to `NotePositionKey`/`NotePositionData` pairs
    /// suitable for the `ScoreCalculator`.
    public func notePositionMap(from execution: VexFactoryExecution) -> [NotePositionKey: NotePositionData] {
        var result: [NotePositionKey: NotePositionData] = [:]
        for pos in execution.notePositions {
            let key = NotePositionKey(
                partIndex: pos.partIndex,
                measureIndex: pos.measureIndexInPart,
                noteIndex: pos.sourceOrder
            )
            let firstY = pos.ys.first ?? 0
            let data = NotePositionData(
                position: MDKPoint(x: pos.x, y: firstY),
                boundingBox: pos.boundingBox ?? MDKBoundingBox(
                    x: pos.x - 5,
                    y: firstY - 10,
                    width: 10,
                    height: 20
                )
            )
            result[key] = data
        }
        return result
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

    private func computedContentHeight(
        for score: LaidOutScore,
        notes: [VexNotePlan],
        staves: [VexStavePlan]
    ) -> Double {
        let maxSystemY = score.systems.map { $0.frame.y + $0.frame.height }.max() ?? 0
        let maxGroupY = score.partGroups.map { $0.frame.y + $0.frame.height }.max() ?? 0
        let maxConnectorY = score.barlineConnectors.map { $0.frame.y + $0.frame.height }.max() ?? 0
        let maxFrameY = max(maxSystemY, maxGroupY, maxConnectorY)

        // Estimate the maximum rendered Y from extreme-pitch notes that extend
        // far below the staff via ledger lines.  Each VexFoundation line unit
        // corresponds to half a staff space ≈ 5px (with spacing_between_lines=10).
        // For a note at line L on a stave whose top is at staveY:
        //   noteY ≈ staveY + (5 - L) * (spacing / 2)  where spacing ≈ 10
        // Notes with very negative line values render far below the staff.
        var staveTopBySystem: [Int: Double] = [:]
        for stave in staves {
            let y = stave.frame.y
            if let existing = staveTopBySystem[stave.systemIndex] {
                staveTopBySystem[stave.systemIndex] = min(existing, y)
            } else {
                staveTopBySystem[stave.systemIndex] = y
            }
        }

        let clefMiddleOctave: (String?) -> Int = { clef in
            switch clef {
            case "bass": return 3
            default: return 4
            }
        }

        var maxNoteY = maxFrameY
        for note in notes where !note.isRest {
            guard let staveY = staveTopBySystem[note.systemIndex] else { continue }
            for token in note.keyTokens {
                let parts = token.split(separator: "/")
                guard parts.count >= 2, let octave = Int(parts[1]) else { continue }
                let midOct = clefMiddleOctave(note.clef)
                let octaveDiff = octave - midOct
                guard octaveDiff <= -1 else { continue }
                // Approximate line value for low notes:
                //   line ≈ (octave * 7 - 28 + noteIndex) / 2 + clefShift
                // Rendered Y ≈ staveY + (5 - line) * 5
                // We use a conservative estimate: each octave below mid is ~35px.
                let extraPx = Double(-octaveDiff) * 35 + 20
                maxNoteY = max(maxNoteY, staveY + 40 + extraPx)
            }
        }

        return max(200, maxNoteY + 40)
    }

    private struct InitialStaveState {
        let measureNumber: Int?
        let clefName: String?
        let clefAnnotation: String?
        let keySignature: String?
        let timeSignature: String?
        let multipleRestCount: Int?
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
                multipleRestCount: nil,
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
                multipleRestCount: nil,
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
        let firstSourceMeasure = (laidOutMeasure.measureIndexInPart >= 0
            && laidOutMeasure.measureIndexInPart < part.measures.count)
            ? part.measures[laidOutMeasure.measureIndexInPart]
            : nil
        let lastSourceMeasure = (lastLaidOutMeasure.measureIndexInPart >= 0
            && lastLaidOutMeasure.measureIndexInPart < part.measures.count)
            ? part.measures[lastLaidOutMeasure.measureIndexInPart]
            : nil
        let beginBarline = firstSourceMeasure.flatMap { beginBarlineKind(for: $0.repetitionInstructions) }
        let endBarline = lastSourceMeasure.flatMap { endBarlineKind(for: $0.repetitionInstructions) }
        let displayMeasureNumber: Int? = (firstSourceMeasure?.implicit == true)
            ? nil
            : laidOutMeasure.measureNumber
        let multipleRestCount = firstSourceMeasure?.attributes?.multipleRestCount
        return InitialStaveState(
            measureNumber: displayMeasureNumber,
            clefName: clefName?.rawValue,
            clefAnnotation: clefAnnotation,
            keySignature: keySignature,
            timeSignature: timeSignature,
            multipleRestCount: multipleRestCount,
            beginBarline: beginBarline,
            endBarline: endBarline
        )
    }

    private func effectiveStaveAttributes(
        in part: MusicDisplayKitModel.Part,
        upToMeasureIndex: Int,
        includeInlineClefEventsInCurrentMeasure: Bool = false
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
            let measure = part.measures[measureIndex]
            if let attributes = measure.attributes {
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

            let shouldApplyInlineClefEvents = measureIndex < lastIndex || includeInlineClefEventsInCurrentMeasure
            if shouldApplyInlineClefEvents, !measure.clefEvents.isEmpty {
                let groupedByOnset = Dictionary(grouping: measure.clefEvents) { clefEvent in
                    max(0, clefEvent.onsetDivisions)
                }
                for onset in groupedByOnset.keys.sorted() {
                    guard let events = groupedByOnset[onset] else {
                        continue
                    }
                    if let nextClef = selectedClef(from: events.map(\.clef)) {
                        clef = nextClef
                    }
                }
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

    private func buildCrossMeasureSlurPlans(
        score: MusicDisplayKitModel.Score,
        noteEntryReferenceBySourceKey: [SourceNoteKey: NoteEntryReference]
    ) -> [VexSlurPlan] {
        struct SlurOpenKey: Hashable {
            var number: Int
            var voice: Int
            var staff: Int?
        }
        struct SlurOpenValue {
            var rawNumber: Int?
            var startSourceKey: SourceNoteKey
            var placement: String?
            var sequence: Int
        }

        func normalizedNumber(_ raw: Int?) -> Int {
            raw ?? 1
        }

        func staffSortValue(_ staff: Int?) -> Int {
            staff ?? Int.max
        }

        var plans: [VexSlurPlan] = []

        for (partIndex, part) in score.parts.enumerated() {
            var openByKey: [SlurOpenKey: [SlurOpenValue]] = [:]
            var nextSequence = 0

            func mostRecentKey(
                from candidates: [SlurOpenKey: [SlurOpenValue]],
                preferredStaff: Int?
            ) -> SlurOpenKey? {
                guard !candidates.isEmpty else {
                    return nil
                }
                let preferredCandidates = candidates.filter { candidate in
                    candidate.key.staff == preferredStaff
                }
                let prioritized = preferredCandidates.isEmpty ? candidates : preferredCandidates
                return prioritized.max(by: { lhs, rhs in
                    let lhsSequence = lhs.value.last?.sequence ?? Int.min
                    let rhsSequence = rhs.value.last?.sequence ?? Int.min
                    if lhsSequence != rhsSequence {
                        return lhsSequence < rhsSequence
                    }
                    let lhsStartMeasure = lhs.value.last?.startSourceKey.measureIndexInPart ?? Int.min
                    let rhsStartMeasure = rhs.value.last?.startSourceKey.measureIndexInPart ?? Int.min
                    if lhsStartMeasure != rhsStartMeasure {
                        return lhsStartMeasure < rhsStartMeasure
                    }
                    let lhsStartNote = lhs.value.last?.startSourceKey.noteIndexInMeasure ?? Int.min
                    let rhsStartNote = rhs.value.last?.startSourceKey.noteIndexInMeasure ?? Int.min
                    if lhsStartNote != rhsStartNote {
                        return lhsStartNote < rhsStartNote
                    }
                    return staffSortValue(lhs.key.staff) < staffSortValue(rhs.key.staff)
                })?.key
            }

            func resolveStopKey(
                requestedKey: SlurOpenKey,
                requestedRawNumber: Int?
            ) -> SlurOpenKey? {
                if requestedRawNumber != nil {
                    let voiceNumberCandidates = openByKey.filter { candidate in
                        candidate.key.voice == requestedKey.voice &&
                        candidate.key.number == requestedKey.number &&
                        !candidate.value.isEmpty
                    }
                    if let match = mostRecentKey(
                        from: voiceNumberCandidates,
                        preferredStaff: nil
                    ) {
                        return match
                    }
                    return nil
                }

                if let stack = openByKey[requestedKey], !stack.isEmpty {
                    return requestedKey
                }

                let sameVoiceCandidates = openByKey.filter { candidate in
                    candidate.key.voice == requestedKey.voice &&
                    !candidate.value.isEmpty
                }
                if let match = mostRecentKey(
                    from: sameVoiceCandidates,
                    preferredStaff: requestedKey.staff
                ) {
                    return match
                }

                let voiceNumberCandidates = openByKey.filter { candidate in
                    candidate.key.voice == requestedKey.voice &&
                    candidate.key.number == requestedKey.number &&
                    !candidate.value.isEmpty
                }
                return mostRecentKey(
                    from: voiceNumberCandidates,
                    preferredStaff: requestedKey.staff
                )
            }

            func appendPlan(
                open: SlurOpenValue,
                endSourceKey: SourceNoteKey,
                endNumber: Int?,
                endPlacement: String?
            ) {
                guard let startRef = noteEntryReferenceBySourceKey[open.startSourceKey],
                      let endRef = noteEntryReferenceBySourceKey[endSourceKey],
                      startRef.partIndex == endRef.partIndex,
                      startRef.voice == endRef.voice,
                      startRef.measureIndexInPart != endRef.measureIndexInPart else {
                    return
                }
                plans.append(
                    VexSlurPlan(
                        systemIndex: startRef.systemIndex,
                        partIndex: startRef.partIndex,
                        measureIndexInPart: startRef.measureIndexInPart,
                        endSystemIndex: endRef.systemIndex,
                        endPartIndex: endRef.partIndex,
                        endMeasureIndexInPart: endRef.measureIndexInPart,
                        voice: startRef.voice,
                        number: open.rawNumber ?? endNumber ?? 1,
                        startEntryIndex: startRef.entryIndexInVoice,
                        endEntryIndex: endRef.entryIndexInVoice,
                        placement: open.placement ?? endPlacement
                    )
                )
            }

            for measureIndex in part.measures.indices {
                let measure = part.measures[measureIndex]
                for noteIndex in measure.noteEvents.indices {
                    let note = measure.noteEvents[noteIndex]
                    let sourceKey = SourceNoteKey(
                        partIndex: partIndex,
                        measureIndexInPart: measureIndex,
                        noteIndexInMeasure: noteIndex
                    )
                    for marker in note.slurs {
                        let key = SlurOpenKey(
                            number: normalizedNumber(marker.number),
                            voice: max(1, note.voice),
                            staff: note.staff
                        )

                        switch marker.type {
                        case .start:
                            openByKey[key, default: []].append(
                                SlurOpenValue(
                                    rawNumber: marker.number,
                                    startSourceKey: sourceKey,
                                    placement: marker.placement,
                                    sequence: nextSequence
                                )
                            )
                            nextSequence += 1

                        case .stop:
                            guard let resolvedKey = resolveStopKey(
                                requestedKey: key,
                                requestedRawNumber: marker.number
                            ),
                            var stack = openByKey[resolvedKey],
                            let open = stack.popLast() else {
                                continue
                            }
                            appendPlan(
                                open: open,
                                endSourceKey: sourceKey,
                                endNumber: marker.number,
                                endPlacement: marker.placement
                            )
                            if stack.isEmpty {
                                openByKey.removeValue(forKey: resolvedKey)
                            } else {
                                openByKey[resolvedKey] = stack
                            }

                        case .continue:
                            if let resolvedKey = resolveStopKey(
                                requestedKey: key,
                                requestedRawNumber: marker.number
                            ),
                            var stack = openByKey[resolvedKey],
                            let open = stack.popLast() {
                                appendPlan(
                                    open: open,
                                    endSourceKey: sourceKey,
                                    endNumber: marker.number,
                                    endPlacement: marker.placement
                                )
                                if stack.isEmpty {
                                    openByKey.removeValue(forKey: resolvedKey)
                                } else {
                                    openByKey[resolvedKey] = stack
                                }
                                let continuationRawNumber = marker.number ?? open.rawNumber
                                let continuationKey = SlurOpenKey(
                                    number: normalizedNumber(continuationRawNumber),
                                    voice: max(1, note.voice),
                                    staff: note.staff
                                )
                                openByKey[continuationKey, default: []].append(
                                    SlurOpenValue(
                                        rawNumber: continuationRawNumber,
                                        startSourceKey: sourceKey,
                                        placement: marker.placement ?? open.placement,
                                        sequence: nextSequence
                                    )
                                )
                                nextSequence += 1
                            } else {
                                openByKey[key, default: []].append(
                                    SlurOpenValue(
                                        rawNumber: marker.number,
                                        startSourceKey: sourceKey,
                                        placement: marker.placement,
                                        sequence: nextSequence
                                    )
                                )
                                nextSequence += 1
                            }

                        case .unknown:
                            continue
                        }
                    }
                }
            }
        }

        return plans.sorted { lhs, rhs in
            if lhs.systemIndex != rhs.systemIndex {
                return lhs.systemIndex < rhs.systemIndex
            }
            if lhs.partIndex != rhs.partIndex {
                return lhs.partIndex < rhs.partIndex
            }
            if lhs.measureIndexInPart != rhs.measureIndexInPart {
                return lhs.measureIndexInPart < rhs.measureIndexInPart
            }
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            if lhs.startEntryIndex != rhs.startEntryIndex {
                return lhs.startEntryIndex < rhs.startEntryIndex
            }
            if lhs.endSystemIndex != rhs.endSystemIndex {
                return lhs.endSystemIndex < rhs.endSystemIndex
            }
            if lhs.endMeasureIndexInPart != rhs.endMeasureIndexInPart {
                return lhs.endMeasureIndexInPart < rhs.endMeasureIndexInPart
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
            for fermata in note.fermatas {
                let code: String
                let position: VexArticulationPositionPlan?
                if fermata.placement == "below" || fermata.placement == "inverted" {
                    code = "a@u"
                    position = .below
                } else {
                    code = "a@a"
                    position = .above
                }
                let key = PlanKey(
                    entryIndexInVoice: entryIndex,
                    articulationCode: code,
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
                        articulationCode: code,
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

    private func buildFingeringPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        noteIndices: [Int],
        noteEvents: [MusicDisplayKitModel.NoteEvent],
        noteToEntryIndex: [Int: Int]
    ) -> [VexFingeringPlan] {
        struct PlanKey: Hashable {
            let entryIndexInVoice: Int
            let number: String
            let position: VexFingeringPositionPlan?
        }

        var plans: [VexFingeringPlan] = []
        var seen: Set<PlanKey> = []
        var sourceOrder = 0
        for noteIndex in noteIndices {
            guard let entryIndex = noteToEntryIndex[noteIndex] else {
                continue
            }
            let note = noteEvents[noteIndex]
            let hasTabPositions = !note.tabPositions.isEmpty
            for marker in note.fingerings {
                let trimmedNumber = marker.number.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedNumber.isEmpty else {
                    continue
                }
                let position = fingeringPositionPlan(
                    placement: marker.placement,
                    type: marker.type
                )
                let key = PlanKey(
                    entryIndexInVoice: entryIndex,
                    number: trimmedNumber,
                    position: position
                )
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)
                plans.append(
                    VexFingeringPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: voice,
                        entryIndexInVoice: entryIndex,
                        number: trimmedNumber,
                        position: position,
                        sourceOrder: sourceOrder
                    )
                )
                sourceOrder += 1
            }
            if hasTabPositions {
                continue
            }
            for marker in note.fretNumbers {
                let trimmedNumber = marker.number.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedNumber.isEmpty else {
                    continue
                }
                let position = fingeringPositionPlan(
                    placement: marker.placement,
                    type: marker.type
                )
                let key = PlanKey(
                    entryIndexInVoice: entryIndex,
                    number: trimmedNumber,
                    position: position
                )
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)
                plans.append(
                    VexFingeringPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: voice,
                        entryIndexInVoice: entryIndex,
                        number: trimmedNumber,
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

    private func buildStringNumberPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        noteIndices: [Int],
        noteEvents: [MusicDisplayKitModel.NoteEvent],
        noteToEntryIndex: [Int: Int]
    ) -> [VexStringNumberPlan] {
        struct PlanKey: Hashable {
            let entryIndexInVoice: Int
            let number: String
            let position: VexStringNumberPositionPlan?
        }

        var plans: [VexStringNumberPlan] = []
        var seen: Set<PlanKey> = []
        var sourceOrder = 0
        for noteIndex in noteIndices {
            guard let entryIndex = noteToEntryIndex[noteIndex] else {
                continue
            }
            let note = noteEvents[noteIndex]
            if !note.tabPositions.isEmpty {
                continue
            }
            for marker in note.stringNumbers {
                let trimmedNumber = marker.number.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedNumber.isEmpty else {
                    continue
                }
                let position = stringNumberPositionPlan(
                    placement: marker.placement,
                    type: marker.type
                )
                let key = PlanKey(
                    entryIndexInVoice: entryIndex,
                    number: trimmedNumber,
                    position: position
                )
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)
                plans.append(
                    VexStringNumberPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: voice,
                        entryIndexInVoice: entryIndex,
                        number: trimmedNumber,
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

    private func buildTabPositionPlans(
        systemIndex: Int,
        partIndex: Int,
        measureIndexInPart: Int,
        voice: Int,
        noteIndices: [Int],
        noteEvents: [MusicDisplayKitModel.NoteEvent],
        noteToEntryIndex: [Int: Int]
    ) -> [VexTabPositionPlan] {
        struct PlanKey: Hashable {
            let entryIndexInVoice: Int
            let stringNumber: String
            let fretNumber: String
        }

        var plans: [VexTabPositionPlan] = []
        var seen: Set<PlanKey> = []
        var sourceOrder = 0
        for noteIndex in noteIndices {
            guard let entryIndex = noteToEntryIndex[noteIndex] else {
                continue
            }
            let note = noteEvents[noteIndex]
            for marker in note.tabPositions {
                let stringNumber = marker.stringNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                let fretNumber = marker.fretNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !stringNumber.isEmpty, !fretNumber.isEmpty else {
                    continue
                }
                let key = PlanKey(
                    entryIndexInVoice: entryIndex,
                    stringNumber: stringNumber,
                    fretNumber: fretNumber
                )
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)
                plans.append(
                    VexTabPositionPlan(
                        systemIndex: systemIndex,
                        partIndex: partIndex,
                        measureIndexInPart: measureIndexInPart,
                        voice: voice,
                        entryIndexInVoice: entryIndex,
                        stringNumber: stringNumber,
                        fretNumber: fretNumber,
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
        let sortedNotePlans = notePlans.sorted { lhs, rhs in
            if lhs.onsetDivisions != rhs.onsetDivisions {
                return lhs.onsetDivisions < rhs.onsetDivisions
            }
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            return lhs.sourceOrder < rhs.sourceOrder
        }

        let nonRestAnchors = sortedNotePlans
            .filter { !$0.isRest }
        let anchorCandidates = nonRestAnchors.isEmpty ? sortedNotePlans : nonRestAnchors

        guard !anchorCandidates.isEmpty else {
            return []
        }

        var plans: [VexChordSymbolPlan] = []
        for (sourceOrder, harmony) in harmonyEvents.enumerated() {
            if harmony.printObject == false {
                continue
            }
            guard let displayText = harmonyDisplayText(for: harmony) else {
                continue
            }
            let staffFilteredAnchors: [VexNotePlan]
            if let harmonyStaff = harmony.staff {
                let matchingStaffAnchors = anchorCandidates.filter { $0.staff == harmonyStaff }
                staffFilteredAnchors = matchingStaffAnchors.isEmpty ? anchorCandidates : matchingStaffAnchors
            } else {
                staffFilteredAnchors = anchorCandidates
            }
            let onset = max(0, harmony.onsetDivisions)
            let anchor = staffFilteredAnchors.first(where: { $0.onsetDivisions >= onset })
                ?? staffFilteredAnchors.last
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
                    placement: chordSymbolPlacementPlan(from: harmony.placement) ?? .above,
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
        case .upBow:
            return "a|"
        case .downBow:
            return "am"
        case .harmonicTechnical:
            return "ah"
        case .openString:
            return "ah"
        case .snapPizzicato:
            return "ao"
        case .stopped:
            return "a+"
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

    private func fingeringPositionPlan(
        placement: String?,
        type: String?
    ) -> VexFingeringPositionPlan? {
        if let placement {
            switch placement.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "left":
                return .left
            case "right":
                return .right
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
            case "left":
                return .left
            case "right":
                return .right
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

    private func stringNumberPositionPlan(
        placement: String?,
        type: String?
    ) -> VexStringNumberPositionPlan? {
        if let placement {
            switch placement.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "left":
                return .left
            case "right":
                return .right
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
            case "left":
                return .left
            case "right":
                return .right
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

    private func chordSymbolPlacementPlan(
        from placement: String?
    ) -> VexChordSymbolPlacementPlan? {
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

    private func chordSymbolVerticalJustify(
        for placement: VexChordSymbolPlacementPlan
    ) -> ChordSymbolVerticalJustify {
        switch placement {
        case .above:
            return .top
        case .below:
            return .bottom
        }
    }

    private func chordSymbolModifierPosition(
        for placement: VexChordSymbolPlacementPlan
    ) -> ModifierPosition {
        switch placement {
        case .above:
            return .above
        case .below:
            return .below
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

    private func lyricTextLine(verse: Int, voiceOffset: Int, stackingOffset: Double = 0) -> Double {
        let line = max(0, verse - 1 + voiceOffset)
        return Double(line) + stackingOffset
    }

    private func harmonyDisplayText(
        for harmony: MusicDisplayKitModel.HarmonyEvent
    ) -> String? {
        if let noChordText = harmonyNoChordText(kind: harmony.kind, explicitText: harmony.kindText) {
            return noChordText
        }

        let root = harmonyFormatPitch(step: harmony.rootStep, alter: harmony.rootAlter)
            ?? harmonyFormatNumeralRoot(root: harmony.numeralRoot, alter: harmony.numeralAlter)
        guard let root else {
            return nil
        }

        let kindAndDegrees = resolveHarmonyKindAndDegrees(
            kind: harmony.kind,
            explicitText: harmony.kindText,
            degrees: harmony.degrees
        )
        let kindSuffix = kindAndDegrees.kindSuffix
        let degreesSuffix = harmonyDegreesSuffix(kindAndDegrees.degrees)

        var text = root + kindSuffix + degreesSuffix

        if let bass = harmonyFormatPitch(step: harmony.bassStep, alter: harmony.bassAlter) {
            text += "/\(bass)"
        }

        return text
    }

    private func resolveHarmonyKindAndDegrees(
        kind: String?,
        explicitText: String?,
        degrees: [MusicDisplayKitModel.HarmonyDegree]
    ) -> (kindSuffix: String, degrees: [MusicDisplayKitModel.HarmonyDegree]) {
        let explicitText = explicitText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKind = normalizedHarmonyKind(kind)
        let defaultKindSuffix = harmonyKindSuffix(kind: kind, explicitText: nil)
        var remainingDegrees = degrees
        var kindSuffix = (explicitText?.isEmpty == false) ? explicitText! : defaultKindSuffix
        let allowsAliasReduction = explicitText == nil || explicitText?.isEmpty == true || explicitText == defaultKindSuffix

        if allowsAliasReduction {
            switch normalizedKind {
            case "major":
                if hasHarmonyDegree(remainingDegrees, type: .add, value: 5, alter: 1),
                   hasHarmonyDegree(remainingDegrees, type: .add, value: 9, alter: -1),
                   hasHarmonyDegree(remainingDegrees, type: .add, value: 9, alter: 1),
                   hasHarmonyDegree(remainingDegrees, type: .alter, value: 5, alter: -1) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 5, alter: 1)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 9, alter: -1)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 9, alter: 1)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .alter, value: 5, alter: -1)
                    kindSuffix = "alt"
                }
            case "suspended-fourth":
                for (degreeValue, alias) in [(7, "7sus4"), (9, "9sus4"), (11, "11sus4"), (13, "13sus4")] {
                    if consumeHarmonyDegree(&remainingDegrees, type: .add, value: degreeValue) {
                        kindSuffix = alias
                    }
                }
            case "suspended-second":
                for (degreeValue, alias) in [(7, "7sus2"), (9, "9sus2"), (11, "11sus2"), (13, "13sus2")] {
                    if consumeHarmonyDegree(&remainingDegrees, type: .add, value: degreeValue) {
                        kindSuffix = alias
                    }
                }
            case "dominant":
                if hasHarmonyDegree(remainingDegrees, type: .add, value: 5, alter: 1),
                   hasHarmonyDegree(remainingDegrees, type: .add, value: 9, alter: -1),
                   hasHarmonyDegree(remainingDegrees, type: .add, value: 9, alter: 1),
                   hasHarmonyDegree(remainingDegrees, type: .alter, value: 5, alter: -1) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 5, alter: 1)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 9, alter: -1)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 9, alter: 1)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .alter, value: 5, alter: -1)
                    kindSuffix = "7alt"
                } else if hasHarmonyDegree(remainingDegrees, type: .add, value: 4),
                          hasHarmonyDegree(remainingDegrees, type: .subtract, value: 3) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 4)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .subtract, value: 3)
                    kindSuffix = "7sus4"
                } else if hasHarmonyDegree(remainingDegrees, type: .add, value: 2),
                          hasHarmonyDegree(remainingDegrees, type: .subtract, value: 3) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 2)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .subtract, value: 3)
                    kindSuffix = "7sus2"
                }
            case "dominant-ninth":
                if hasHarmonyDegree(remainingDegrees, type: .add, value: 4),
                   hasHarmonyDegree(remainingDegrees, type: .subtract, value: 3) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 4)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .subtract, value: 3)
                    kindSuffix = "9sus4"
                } else if hasHarmonyDegree(remainingDegrees, type: .add, value: 2),
                          hasHarmonyDegree(remainingDegrees, type: .subtract, value: 3) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 2)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .subtract, value: 3)
                    kindSuffix = "9sus2"
                }
            case "dominant-11th":
                if hasHarmonyDegree(remainingDegrees, type: .add, value: 4),
                   hasHarmonyDegree(remainingDegrees, type: .subtract, value: 3) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 4)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .subtract, value: 3)
                    kindSuffix = "11sus4"
                } else if hasHarmonyDegree(remainingDegrees, type: .add, value: 2),
                          hasHarmonyDegree(remainingDegrees, type: .subtract, value: 3) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 2)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .subtract, value: 3)
                    kindSuffix = "11sus2"
                }
            case "dominant-13th":
                if hasHarmonyDegree(remainingDegrees, type: .add, value: 4),
                   hasHarmonyDegree(remainingDegrees, type: .subtract, value: 3) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 4)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .subtract, value: 3)
                    kindSuffix = "13sus4"
                } else if hasHarmonyDegree(remainingDegrees, type: .add, value: 2),
                          hasHarmonyDegree(remainingDegrees, type: .subtract, value: 3) {
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .add, value: 2)
                    _ = consumeHarmonyDegree(&remainingDegrees, type: .subtract, value: 3)
                    kindSuffix = "13sus2"
                }
            case "major-minor":
                for (degreeValue, alias) in [(9, "m(maj9)"), (11, "m(maj11)"), (13, "m(maj13)")] {
                    if consumeHarmonyDegree(&remainingDegrees, type: .add, value: degreeValue) {
                        kindSuffix = alias
                    }
                }
            case "major-sixth":
                if consumeHarmonyDegree(&remainingDegrees, type: .add, value: 9) {
                    kindSuffix = "69"
                }
            case "minor-sixth":
                if consumeHarmonyDegree(&remainingDegrees, type: .add, value: 9) {
                    kindSuffix = "mi69"
                }
            case "minor-seventh":
                if consumeHarmonyDegree(&remainingDegrees, type: .alter, value: 5, alter: -1) {
                    kindSuffix = "m7b5"
                }
            default:
                break
            }
        }

        return (kindSuffix: kindSuffix, degrees: remainingDegrees)
    }

    private enum HarmonyDegreeTypeMatch {
        case add
        case alter
        case subtract
    }

    private func hasHarmonyDegree(
        _ degrees: [MusicDisplayKitModel.HarmonyDegree],
        type: HarmonyDegreeTypeMatch,
        value: Int,
        alter: Int = 0
    ) -> Bool {
        degrees.contains { degree in
            guard degree.value == value,
                  (degree.alter ?? 0) == alter else {
                return false
            }
            return harmonyDegreeTypeMatches(degree.type, match: type)
        }
    }

    @discardableResult
    private func consumeHarmonyDegree(
        _ degrees: inout [MusicDisplayKitModel.HarmonyDegree],
        type: HarmonyDegreeTypeMatch,
        value: Int,
        alter: Int = 0
    ) -> Bool {
        guard let index = degrees.firstIndex(where: { degree in
            degree.value == value &&
            (degree.alter ?? 0) == alter &&
            harmonyDegreeTypeMatches(degree.type, match: type)
        }) else {
            return false
        }
        degrees.remove(at: index)
        return true
    }

    private func harmonyDegreeTypeMatches(
        _ degreeType: MusicDisplayKitModel.HarmonyDegreeType?,
        match: HarmonyDegreeTypeMatch
    ) -> Bool {
        switch (match, degreeType) {
        case (.add, .add):
            return true
        case (.alter, .alter):
            return true
        case (.subtract, .subtract):
            return true
        default:
            return false
        }
    }

    private func harmonyNoChordText(kind: String?, explicitText: String?) -> String? {
        guard normalizedHarmonyKind(kind) == "none" else {
            return nil
        }
        if let explicitText = explicitText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitText.isEmpty {
            return explicitText
        }
        return "N.C."
    }

    private func harmonyFormatNumeralRoot(root: String?, alter: Int?) -> String? {
        guard let root = root?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !root.isEmpty else {
            return nil
        }
        return harmonyAccidentalString(alter: alter ?? 0) + root
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

        let normalizedKind = normalizedHarmonyKind(kind)

        switch normalizedKind {
        case "", "major":
            return ""
        case "none":
            return "N.C."
        case "minor":
            return "m"
        case "minor-sixth":
            return "m6"
        case "major-seventh":
            return "maj7"
        case "major-11th":
            return "maj11"
        case "major-13th":
            return "maj13"
        case "major-ninth":
            return "maj9"
        case "major-sixth":
            return "maj6"
        case "major-minor":
            return "m(maj7)"
        case "minor-seventh":
            return "m7"
        case "minor-11th":
            return "m11"
        case "minor-13th":
            return "m13"
        case "minor-ninth":
            return "m9"
        case "dominant":
            return "7"
        case "dominant-11th":
            return "11"
        case "dominant-13th":
            return "13"
        case "dominant-ninth":
            return "9"
        case "augmented":
            return "aug"
        case "augmented-seventh":
            return "aug7"
        case "diminished":
            return "dim"
        case "diminished-seventh":
            return "dim7"
        case "half-diminished":
            return "m7b5"
        case "power":
            return "5"
        case "suspended-second":
            return "sus2"
        case "suspended-fourth":
            return "sus4"
        default:
            return normalizedKind.isEmpty ? "" : "(\(normalizedKind))"
        }
    }

    private func normalizedHarmonyKind(_ kind: String?) -> String {
        kind?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func harmonyDegreesSuffix(
        _ degrees: [MusicDisplayKitModel.HarmonyDegree]
    ) -> String {
        var adds: [String] = []
        var alts: [String] = []
        var subs: [String] = []
        var unknowns: [String] = []

        for degree in degrees {
            guard let value = degree.value else {
                continue
            }
            let accidental = harmonyAccidentalString(alter: degree.alter ?? 0)
            let token = "\(accidental)\(value)"
            switch degree.type {
            case .add:
                adds.append(token)
            case .alter:
                alts.append(token)
            case .subtract:
                subs.append(token)
            case .unknown(let raw):
                let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                unknowns.append(cleaned.isEmpty ? token : "\(cleaned)\(token)")
            case .none:
                adds.append(token)
            }
        }

        guard !adds.isEmpty || !alts.isEmpty || !subs.isEmpty || !unknowns.isEmpty else {
            return ""
        }

        var output = ""
        if !adds.isEmpty {
            output += "(\(adds.joined(separator: ",")))"
        }
        if !alts.isEmpty {
            output += "(alt \(alts.joined(separator: ",")))"
        }
        if !subs.isEmpty {
            output += "(omit \(subs.joined(separator: ",")))"
        }
        if !unknowns.isEmpty {
            output += "(\(unknowns.joined(separator: ",")))"
        }
        return output
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
        let roundedAlter = Int(pitch.alter.rounded())
        switch roundedAlter {
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

    private func noteHeadBeginX(_ note: Note) -> Double {
        if let staveNote = note as? StaveNote {
            return staveNote.getNoteHeadBeginX()
        }
        return note.getAbsoluteX() - (note.getGlyphWidth() / 2)
    }

    private func noteHeadEndX(_ note: Note) -> Double {
        if let staveNote = note as? StaveNote {
            return staveNote.getNoteHeadEndX()
        }
        return note.getAbsoluteX() + (note.getGlyphWidth() / 2)
    }

    private func slurCurveInvert(
        placement: String?,
        startNote: Note?,
        endNote: Note?
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

    private func fingeringModifierPosition(
        for planPosition: VexFingeringPositionPlan?
    ) -> ModifierPosition? {
        switch planPosition {
        case .left:
            return .left
        case .right:
            return .right
        case .above:
            return .above
        case .below:
            return .below
        case .none:
            return nil
        }
    }

    private func stringNumberModifierPosition(
        for planPosition: VexStringNumberPositionPlan?
    ) -> ModifierPosition? {
        switch planPosition {
        case .left:
            return .left
        case .right:
            return .right
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
        keys providedKeys: [StaffKeySpec]? = nil,
        clefName: ClefName? = nil,
        stemDirection: StemDirection? = nil
    ) -> StaveNote? {
        let duration = noteDurationSpec(
            durationDivisions: notePlan.durationDivisions,
            divisions: notePlan.divisions,
            isRest: notePlan.isRest,
            noteType: notePlan.noteType,
            dotCount: notePlan.dotCount
        )
        let keys: [StaffKeySpec]
        if let providedKeys {
            keys = providedKeys
        } else {
            keys = notePlan.keyTokens.compactMap { token in
                try? StaffKeySpec(parsing: token)
            }
        }
        guard let nonEmptyKeys = NonEmptyArray(validating: keys) else {
            return nil
        }

        let resolvedNoteType: NoteType?
        if let noteheadType = notePlan.noteheadType {
            resolvedNoteType = vexNoteType(for: noteheadType)
        } else {
            resolvedNoteType = nil
        }

        let cueScale: Double? = notePlan.isCue
            ? (Tables.NOTATION_FONT_SCALE / 5.0) * 3.0
            : nil
        let note = factory.StaveNote(
            StaveNoteStruct(
                keys: nonEmptyKeys,
                duration: duration,
                type: resolvedNoteType,
                glyphFontScale: cueScale,
                clef: clefName
            )
        )
        if let stemDirection {
            _ = note.setStemDirection(stemDirection)
        }
        _ = note.setStave(stave)
        return note
    }

    private func makeTabNote(
        from notePlan: VexNotePlan,
        tabPositions: [VexTabPositionPlan],
        factory: Factory,
        stave: Stave,
        stemDirection: StemDirection? = nil
    ) -> VexFoundation.TabNote? {
        let duration = noteDurationSpec(
            durationDivisions: notePlan.durationDivisions,
            divisions: notePlan.divisions,
            isRest: notePlan.isRest,
            noteType: notePlan.noteType,
            dotCount: notePlan.dotCount
        )
        let positions: [TabNotePosition] = tabPositions.compactMap { positionPlan in
            let stringToken = positionPlan.stringNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let fretToken = positionPlan.fretNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let stringNumber = Int(stringToken), stringNumber > 0, !fretToken.isEmpty else {
                return nil
            }
            return TabNotePosition(str: stringNumber, fret: fretToken)
        }
        guard !positions.isEmpty else {
            return nil
        }
        let sortedPositions = positions.sorted { lhs, rhs in
            if lhs.str != rhs.str {
                return lhs.str < rhs.str
            }
            return lhs.fret < rhs.fret
        }
        let tabNote = factory.TabNote(
            TabNoteStruct(
                positions: sortedPositions,
                duration: duration.value,
                dots: duration.dots > 0 ? duration.dots : nil,
                type: duration.type == .note ? nil : duration.type,
                stemDirection: stemDirection
            )
        )
        _ = tabNote.setStave(stave)
        return tabNote
    }

    private func noteDurationSpec(
        durationDivisions: Int,
        divisions: Int,
        isRest: Bool,
        noteType: NoteTypeValue? = nil,
        dotCount: Int = 0
    ) -> NoteDurationSpec {
        // Prefer explicit note type from MusicXML <type> element when available.
        if let noteType, let vexValue = vexNoteValue(for: noteType) {
            return NoteDurationSpec(
                uncheckedValue: vexValue,
                dots: dotCount,
                type: isRest ? .rest : .note
            )
        }

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

    private func vexNoteValue(for noteType: NoteTypeValue) -> NoteValue? {
        switch noteType {
        case .breve, .maxima, .long:
            return .doubleWhole
        case .whole:
            return .whole
        case .half:
            return .half
        case .quarter:
            return .quarter
        case .eighth:
            return .eighth
        case .sixteenth:
            return .sixteenth
        case .thirtySecond:
            return .thirtySecond
        case .sixtyFourth:
            return .sixtyFourth
        case .oneHundredTwentyEighth:
            return .oneTwentyEighth
        case .twoHundredFiftySixth:
            return .twoFiftySixth
        case .fiveHundredTwelfth, .oneThousandTwentyFourth:
            return nil
        }
    }

    private func vexNoteType(for notehead: NoteheadType) -> NoteType? {
        switch notehead {
        case .normal:
            return nil
        case .diamond:
            return .diamond
        case .x, .cross:
            return .x
        case .triangleUp:
            return .triangleUp
        case .triangleDown:
            return .triangleDown
        case .slash:
            return .slash
        case .square:
            return .square
        case .circleX:
            return .circleX
        case .backSlashed:
            return .slashedBackward
        case .slashed:
            return .slashed
        case .none:
            return .ghost
        case .doNotation, .re, .mi, .fa, .faUp, .so, .la, .ti:
            return nil
        }
    }

    private func vexOrnamentType(for kind: OrnamentKind) -> String? {
        switch kind {
        case .trillMark:
            return "tr"
        case .mordent:
            return "mordent"
        case .invertedMordent:
            return "mordent_inverted"
        case .turn:
            return "turn"
        case .invertedTurn:
            return "turn_inverted"
        case .delayedTurn:
            return "turn"
        case .delayedInvertedTurn:
            return "turn_inverted"
        case .shake:
            return "prallprall"
        case .wavyLine:
            return "tr"
        }
    }

    private func vexAccidentalType(for accidental: AccidentalValue) -> AccidentalType? {
        switch accidental {
        case .sharp:
            return .sharp
        case .flat:
            return .flat
        case .natural:
            return .natural
        case .doubleSharp, .sharpSharp:
            return .doubleSharp
        case .doubleFlat, .flatFlat:
            return .doubleFlat
        case .naturalSharp:
            return .sharp
        case .naturalFlat:
            return .flat
        case .quarterFlat:
            return .quarterFlat
        case .quarterSharp:
            return .quarterSharp
        case .threeQuartersFlat:
            return .threeQuarterFlat
        case .threeQuartersSharp:
            return .threeQuarterSharp
        case .unknown:
            return nil
        }
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

    private func buildInlineClefChangePlans(
        laidOutMeasure: LaidOutMeasure,
        sourceMeasure: MusicDisplayKitModel.Measure,
        part: MusicDisplayKitModel.Part,
        isFirstMeasureInSystem: Bool,
        notePlans: [VexNotePlan],
        effectiveMeasureClef: ClefName?
    ) -> [VexInlineClefChangePlan] {
        var plans: [VexInlineClefChangePlan] = []
        let previousMeasureIndex = laidOutMeasure.measureIndexInPart - 1
        let previousVexClef: ClefName?
        if previousMeasureIndex >= 0 {
            previousVexClef = effectiveStaveAttributes(
                in: part,
                upToMeasureIndex: previousMeasureIndex,
                includeInlineClefEventsInCurrentMeasure: true
            ).clef.flatMap(vexClefName(for:))
        } else {
            previousVexClef = nil
        }
        let anchorComparator: (VexNotePlan, VexNotePlan) -> Bool = { lhs, rhs in
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
        func appendPlanIfAnchored(
            onsetDivisions: Int,
            clefName: ClefName,
            annotation: ClefAnnotation?
        ) {
            guard let anchorNote = notePlans
                .filter({ $0.onsetDivisions >= onsetDivisions })
                .min(by: anchorComparator) else {
                return
            }
            plans.append(
                VexInlineClefChangePlan(
                    systemIndex: laidOutMeasure.systemIndex,
                    partIndex: laidOutMeasure.partIndex,
                    measureIndexInPart: laidOutMeasure.measureIndexInPart,
                    voice: anchorNote.voice,
                    entryIndexInVoice: anchorNote.entryIndexInVoice,
                    clef: clefName.rawValue,
                    annotation: annotation?.rawValue
                )
            )
        }

        let explicitMeasureStartClef = sourceMeasure.attributes
            .flatMap { selectedClef(from: $0.clefs) }
            .flatMap(vexClefName(for:))

        if !isFirstMeasureInSystem,
           let explicitMeasureStartClef,
           explicitMeasureStartClef != .tab,
           explicitMeasureStartClef != previousVexClef {
            let explicitAnnotation = sourceMeasure.attributes
                .flatMap { selectedClef(from: $0.clefs) }
                .flatMap(vexClefAnnotation(for:))
            appendPlanIfAnchored(
                onsetDivisions: 0,
                clefName: explicitMeasureStartClef,
                annotation: explicitAnnotation
            )
        }

        let groupedByOnset = Dictionary(grouping: sourceMeasure.clefEvents) { clefEvent in
            max(0, clefEvent.onsetDivisions)
        }
        var activeClef = effectiveMeasureClef
        for onset in groupedByOnset.keys.filter({ $0 > 0 }).sorted() {
            guard let events = groupedByOnset[onset] else {
                continue
            }
            let selectedAtOnset = selectedClef(from: events.map(\.clef))
            guard let selectedAtOnset,
                  let nextClef = vexClefName(for: selectedAtOnset),
                  nextClef != .tab else {
                continue
            }
            defer { activeClef = nextClef }
            guard nextClef != activeClef else {
                continue
            }
            appendPlanIfAnchored(
                onsetDivisions: onset,
                clefName: nextClef,
                annotation: vexClefAnnotation(for: selectedAtOnset)
            )
        }

        return plans
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
