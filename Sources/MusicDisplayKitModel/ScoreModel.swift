import MusicDisplayKitCore

public struct Score: Equatable, Sendable {
    public var title: String
    public var parts: [Part]
    public var partGroups: [PartGroup]

    public init(
        title: String = "Untitled Score",
        parts: [Part] = [],
        partGroups: [PartGroup] = []
    ) {
        self.title = title
        self.parts = parts
        self.partGroups = partGroups
    }
}

public struct Part: Equatable, Sendable {
    public var id: String
    public var name: String?
    public var measures: [Measure]
    public var playbackOrder: PlaybackOrder?

    public init(
        id: String,
        name: String? = nil,
        measures: [Measure] = [],
        playbackOrder: PlaybackOrder? = nil
    ) {
        self.id = id
        self.name = name
        self.measures = measures
        self.playbackOrder = playbackOrder
    }
}

public struct PartGroup: Equatable, Sendable {
    public var number: Int?
    public var startPartID: String
    public var endPartID: String
    public var symbol: PartGroupSymbol?
    public var barline: Bool?
    public var name: String?

    public init(
        number: Int? = nil,
        startPartID: String,
        endPartID: String,
        symbol: PartGroupSymbol? = nil,
        barline: Bool? = nil,
        name: String? = nil
    ) {
        self.number = number
        self.startPartID = startPartID
        self.endPartID = endPartID
        self.symbol = symbol
        self.barline = barline
        self.name = name
    }
}

public enum PartGroupSymbol: Equatable, Sendable {
    case brace
    case bracket
    case line
    case square
    case unknown(String)
}

public struct Measure: Equatable, Sendable {
    public var number: Int
    public var xmlNumber: String?
    public var divisions: Int?
    public var attributes: MeasureAttributes?
    public var noteEvents: [NoteEvent]
    public var timingDirectives: [TimingDirective]
    public var directionEvents: [DirectionEvent]
    public var harmonyEvents: [HarmonyEvent]
    public var repetitionInstructions: [RepetitionInstruction]
    public var tempoEvents: [TempoEvent]
    public var tieSpans: [TieSpan]
    public var slurSpans: [SlurSpan]
    public var lyricWords: [LyricWord]

    public init(
        number: Int,
        xmlNumber: String? = nil,
        divisions: Int? = nil,
        attributes: MeasureAttributes? = nil,
        noteEvents: [NoteEvent] = [],
        timingDirectives: [TimingDirective] = [],
        directionEvents: [DirectionEvent] = [],
        harmonyEvents: [HarmonyEvent] = [],
        repetitionInstructions: [RepetitionInstruction] = [],
        tempoEvents: [TempoEvent] = [],
        tieSpans: [TieSpan] = [],
        slurSpans: [SlurSpan] = [],
        lyricWords: [LyricWord] = []
    ) {
        self.number = number
        self.xmlNumber = xmlNumber
        self.divisions = divisions
        self.attributes = attributes
        self.noteEvents = noteEvents
        self.timingDirectives = timingDirectives
        self.directionEvents = directionEvents
        self.harmonyEvents = harmonyEvents
        self.repetitionInstructions = repetitionInstructions
        self.tempoEvents = tempoEvents
        self.tieSpans = tieSpans
        self.slurSpans = slurSpans
        self.lyricWords = lyricWords
    }
}

public struct MeasureAttributes: Equatable, Sendable {
    public var key: KeySignature?
    public var time: TimeSignature?
    public var clefs: [ClefSetting]

    public init(key: KeySignature? = nil, time: TimeSignature? = nil, clefs: [ClefSetting] = []) {
        self.key = key
        self.time = time
        self.clefs = clefs
    }
}

public struct KeySignature: Equatable, Sendable {
    public var fifths: Int
    public var mode: String?

    public init(fifths: Int, mode: String? = nil) {
        self.fifths = fifths
        self.mode = mode
    }
}

public struct TimeSignature: Equatable, Sendable {
    public var beats: Int
    public var beatType: Int
    public var symbol: String?

    public init(beats: Int, beatType: Int, symbol: String? = nil) {
        self.beats = beats
        self.beatType = beatType
        self.symbol = symbol
    }
}

public struct ClefSetting: Equatable, Sendable {
    public var sign: String
    public var line: Int?
    public var number: Int?
    public var octaveChange: Int?

    public init(sign: String, line: Int? = nil, number: Int? = nil, octaveChange: Int? = nil) {
        self.sign = sign
        self.line = line
        self.number = number
        self.octaveChange = octaveChange
    }
}

public struct PitchValue: Equatable, Sendable {
    public var step: String
    public var alter: Int
    public var octave: Int

    public init(step: String, alter: Int = 0, octave: Int) {
        self.step = step
        self.alter = alter
        self.octave = octave
    }
}

public enum NoteEventKind: Equatable, Sendable {
    case pitched
    case rest
}

public struct NoteEvent: Equatable, Sendable {
    public var kind: NoteEventKind
    public var pitch: PitchValue?
    public var onsetDivisions: Int
    public var durationDivisions: Int?
    public var voice: Int
    public var staff: Int?
    public var isChord: Bool
    public var isGrace: Bool
    public var lyrics: [LyricEvent]
    public var ties: [TieMarker]
    public var slurs: [SlurMarker]
    public var beams: [BeamMarker]
    public var tuplets: [TupletMarker]
    public var timeModification: TimeModification?
    public var articulations: [ArticulationMarker]
    public var fingerings: [FingeringMarker]
    public var stringNumbers: [StringNumberMarker]
    public var fretNumbers: [FretNumberMarker]
    public var tabPositions: [TabPositionMarker]

    public init(
        kind: NoteEventKind,
        pitch: PitchValue? = nil,
        onsetDivisions: Int = 0,
        durationDivisions: Int? = nil,
        voice: Int = 1,
        staff: Int? = nil,
        isChord: Bool = false,
        isGrace: Bool = false,
        lyrics: [LyricEvent] = [],
        ties: [TieMarker] = [],
        slurs: [SlurMarker] = [],
        beams: [BeamMarker] = [],
        tuplets: [TupletMarker] = [],
        timeModification: TimeModification? = nil,
        articulations: [ArticulationMarker] = [],
        fingerings: [FingeringMarker] = [],
        stringNumbers: [StringNumberMarker] = [],
        fretNumbers: [FretNumberMarker] = [],
        tabPositions: [TabPositionMarker] = []
    ) {
        self.kind = kind
        self.pitch = pitch
        self.onsetDivisions = onsetDivisions
        self.durationDivisions = durationDivisions
        self.voice = voice
        self.staff = staff
        self.isChord = isChord
        self.isGrace = isGrace
        self.lyrics = lyrics
        self.ties = ties
        self.slurs = slurs
        self.beams = beams
        self.tuplets = tuplets
        self.timeModification = timeModification
        self.articulations = articulations
        self.fingerings = fingerings
        self.stringNumbers = stringNumbers
        self.fretNumbers = fretNumbers
        self.tabPositions = tabPositions
    }
}

public struct ArticulationMarker: Equatable, Sendable {
    public var kind: ArticulationKind
    public var placement: String?
    public var type: String?

    public init(kind: ArticulationKind, placement: String? = nil, type: String? = nil) {
        self.kind = kind
        self.placement = placement
        self.type = type
    }
}

public enum ArticulationKind: Equatable, Sendable {
    case accent
    case strongAccent
    case staccato
    case tenuto
    case detachedLegato
    case staccatissimo
    case spiccato
    case scoop
    case plop
    case doit
    case falloff
    case breathMark
    case caesura
    case stress
    case unstress
    case unknown(String)
}

public struct FingeringMarker: Equatable, Sendable {
    public var number: String
    public var placement: String?
    public var type: String?
    public var substitution: Bool?
    public var alternate: Bool?

    public init(
        number: String,
        placement: String? = nil,
        type: String? = nil,
        substitution: Bool? = nil,
        alternate: Bool? = nil
    ) {
        self.number = number
        self.placement = placement
        self.type = type
        self.substitution = substitution
        self.alternate = alternate
    }
}

public struct StringNumberMarker: Equatable, Sendable {
    public var number: String
    public var placement: String?
    public var type: String?

    public init(
        number: String,
        placement: String? = nil,
        type: String? = nil
    ) {
        self.number = number
        self.placement = placement
        self.type = type
    }
}

public struct FretNumberMarker: Equatable, Sendable {
    public var number: String
    public var placement: String?
    public var type: String?

    public init(
        number: String,
        placement: String? = nil,
        type: String? = nil
    ) {
        self.number = number
        self.placement = placement
        self.type = type
    }
}

public struct TabPositionMarker: Equatable, Sendable {
    public var stringNumber: String
    public var fretNumber: String

    public init(
        stringNumber: String,
        fretNumber: String
    ) {
        self.stringNumber = stringNumber
        self.fretNumber = fretNumber
    }
}

public struct DirectionEvent: Equatable, Sendable {
    public var onsetDivisions: Int
    public var offsetDivisions: Int
    public var placement: String?
    public var voice: Int?
    public var staff: Int?
    public var soundTempo: Double?
    public var metronome: MetronomeMark?
    public var dynamics: [String]
    public var words: [String]
    public var rehearsal: String?
    public var wedges: [WedgeMarker]
    public var octaveShifts: [OctaveShiftMarker]
    public var pedals: [PedalMarker]

    public init(
        onsetDivisions: Int,
        offsetDivisions: Int = 0,
        placement: String? = nil,
        voice: Int? = nil,
        staff: Int? = nil,
        soundTempo: Double? = nil,
        metronome: MetronomeMark? = nil,
        dynamics: [String] = [],
        words: [String] = [],
        rehearsal: String? = nil,
        wedges: [WedgeMarker] = [],
        octaveShifts: [OctaveShiftMarker] = [],
        pedals: [PedalMarker] = []
    ) {
        self.onsetDivisions = onsetDivisions
        self.offsetDivisions = offsetDivisions
        self.placement = placement
        self.voice = voice
        self.staff = staff
        self.soundTempo = soundTempo
        self.metronome = metronome
        self.dynamics = dynamics
        self.words = words
        self.rehearsal = rehearsal
        self.wedges = wedges
        self.octaveShifts = octaveShifts
        self.pedals = pedals
    }
}

public struct HarmonyEvent: Equatable, Sendable {
    public var onsetDivisions: Int
    public var offsetDivisions: Int
    public var placement: String?
    public var printObject: Bool?
    public var numeralRoot: String?
    public var numeralAlter: Int?
    public var rootStep: String?
    public var rootAlter: Int
    public var bassStep: String?
    public var bassAlter: Int
    public var kind: String?
    public var kindText: String?
    public var kindUsesSymbols: Bool?
    public var staff: Int?
    public var degrees: [HarmonyDegree]

    public init(
        onsetDivisions: Int,
        offsetDivisions: Int = 0,
        placement: String? = nil,
        printObject: Bool? = nil,
        numeralRoot: String? = nil,
        numeralAlter: Int? = nil,
        rootStep: String? = nil,
        rootAlter: Int = 0,
        bassStep: String? = nil,
        bassAlter: Int = 0,
        kind: String? = nil,
        kindText: String? = nil,
        kindUsesSymbols: Bool? = nil,
        staff: Int? = nil,
        degrees: [HarmonyDegree] = []
    ) {
        self.onsetDivisions = onsetDivisions
        self.offsetDivisions = offsetDivisions
        self.placement = placement
        self.printObject = printObject
        self.numeralRoot = numeralRoot
        self.numeralAlter = numeralAlter
        self.rootStep = rootStep
        self.rootAlter = rootAlter
        self.bassStep = bassStep
        self.bassAlter = bassAlter
        self.kind = kind
        self.kindText = kindText
        self.kindUsesSymbols = kindUsesSymbols
        self.staff = staff
        self.degrees = degrees
    }
}

public struct HarmonyDegree: Equatable, Sendable {
    public var value: Int?
    public var alter: Int?
    public var type: HarmonyDegreeType?

    public init(value: Int? = nil, alter: Int? = nil, type: HarmonyDegreeType? = nil) {
        self.value = value
        self.alter = alter
        self.type = type
    }
}

public enum HarmonyDegreeType: Equatable, Sendable {
    case add
    case alter
    case subtract
    case unknown(String)
}

public struct RepetitionInstruction: Equatable, Sendable {
    public var onsetDivisions: Int
    public var kind: RepetitionInstructionKind
    public var location: String?
    public var times: Int?
    public var endingNumbers: [Int]
    public var target: String?
    public var text: String?

    public init(
        onsetDivisions: Int,
        kind: RepetitionInstructionKind,
        location: String? = nil,
        times: Int? = nil,
        endingNumbers: [Int] = [],
        target: String? = nil,
        text: String? = nil
    ) {
        self.onsetDivisions = onsetDivisions
        self.kind = kind
        self.location = location
        self.times = times
        self.endingNumbers = endingNumbers
        self.target = target
        self.text = text
    }
}

public enum RepetitionInstructionKind: Hashable, Sendable {
    case repeatForward
    case repeatBackward
    case endingStart
    case endingStop
    case endingDiscontinue
    case segno
    case coda
    case daCapo
    case dalSegno
    case toCoda
    case fine
    case alFine
    case alCoda
    case unknown(String)
}

public struct TempoEvent: Equatable, Sendable {
    public var onsetDivisions: Int
    public var bpm: Double
    public var source: TempoEventSource

    public init(onsetDivisions: Int, bpm: Double, source: TempoEventSource) {
        self.onsetDivisions = onsetDivisions
        self.bpm = bpm
        self.source = source
    }
}

public enum TempoEventSource: Equatable, Sendable {
    case carryForward
    case sound
    case metronome
}

public struct PlaybackOrder: Equatable, Sendable {
    public var visits: [PlaybackVisit]
    public var termination: PlaybackTermination

    public init(visits: [PlaybackVisit] = [], termination: PlaybackTermination = .endOfScore) {
        self.visits = visits
        self.termination = termination
    }
}

public struct PlaybackVisit: Equatable, Sendable {
    public var measureIndex: Int
    public var measureNumber: Int
    public var visitNumber: Int

    public init(measureIndex: Int, measureNumber: Int, visitNumber: Int) {
        self.measureIndex = measureIndex
        self.measureNumber = measureNumber
        self.visitNumber = visitNumber
    }
}

public enum PlaybackTermination: Equatable, Sendable {
    case endOfScore
    case fine
    case stepLimit
}

public struct TieSpan: Equatable, Sendable {
    public var startNoteIndex: Int
    public var endNoteIndex: Int
    public var source: TieMarkerSource
    public var voice: Int
    public var staff: Int?
    public var pitch: PitchValue?

    public init(
        startNoteIndex: Int,
        endNoteIndex: Int,
        source: TieMarkerSource,
        voice: Int,
        staff: Int? = nil,
        pitch: PitchValue? = nil
    ) {
        self.startNoteIndex = startNoteIndex
        self.endNoteIndex = endNoteIndex
        self.source = source
        self.voice = voice
        self.staff = staff
        self.pitch = pitch
    }
}

public struct SlurSpan: Equatable, Sendable {
    public var number: Int?
    public var startNoteIndex: Int
    public var endNoteIndex: Int
    public var voice: Int
    public var staff: Int?
    public var placement: String?

    public init(
        number: Int? = nil,
        startNoteIndex: Int,
        endNoteIndex: Int,
        voice: Int,
        staff: Int? = nil,
        placement: String? = nil
    ) {
        self.number = number
        self.startNoteIndex = startNoteIndex
        self.endNoteIndex = endNoteIndex
        self.voice = voice
        self.staff = staff
        self.placement = placement
    }
}

public struct LyricWord: Equatable, Sendable {
    public var number: Int
    public var startNoteIndex: Int
    public var endNoteIndex: Int
    public var text: String?
    public var hasExtension: Bool

    public init(
        number: Int,
        startNoteIndex: Int,
        endNoteIndex: Int,
        text: String? = nil,
        hasExtension: Bool = false
    ) {
        self.number = number
        self.startNoteIndex = startNoteIndex
        self.endNoteIndex = endNoteIndex
        self.text = text
        self.hasExtension = hasExtension
    }
}

public struct MetronomeMark: Equatable, Sendable {
    public var beatUnit: String?
    public var beatUnitDotCount: Int
    public var perMinute: String?
    public var parentheses: Bool?

    public init(
        beatUnit: String? = nil,
        beatUnitDotCount: Int = 0,
        perMinute: String? = nil,
        parentheses: Bool? = nil
    ) {
        self.beatUnit = beatUnit
        self.beatUnitDotCount = beatUnitDotCount
        self.perMinute = perMinute
        self.parentheses = parentheses
    }
}

public struct WedgeMarker: Equatable, Sendable {
    public var type: WedgeType
    public var number: Int?
    public var spread: Double?
    public var niente: Bool?
    public var lineType: String?

    public init(
        type: WedgeType,
        number: Int? = nil,
        spread: Double? = nil,
        niente: Bool? = nil,
        lineType: String? = nil
    ) {
        self.type = type
        self.number = number
        self.spread = spread
        self.niente = niente
        self.lineType = lineType
    }
}

public enum WedgeType: Equatable, Sendable {
    case crescendo
    case diminuendo
    case stop
    case `continue`
    case unknown(String)
}

public struct OctaveShiftMarker: Equatable, Sendable {
    public var type: OctaveShiftType
    public var number: Int?
    public var size: Int?

    public init(type: OctaveShiftType, number: Int? = nil, size: Int? = nil) {
        self.type = type
        self.number = number
        self.size = size
    }
}

public enum OctaveShiftType: Equatable, Sendable {
    case up
    case down
    case stop
    case `continue`
    case unknown(String)
}

public struct PedalMarker: Equatable, Sendable {
    public var type: PedalType
    public var line: Bool?
    public var sign: Bool?

    public init(type: PedalType, line: Bool? = nil, sign: Bool? = nil) {
        self.type = type
        self.line = line
        self.sign = sign
    }
}

public enum PedalType: Equatable, Sendable {
    case start
    case stop
    case change
    case `continue`
    case discontinue
    case resume
    case unknown(String)
}

public enum NotationSpanType: String, Equatable, Sendable {
    case start
    case stop
    case `continue`
    case unknown
}

public struct TieMarker: Equatable, Sendable {
    public var type: NotationSpanType
    public var source: TieMarkerSource

    public init(type: NotationSpanType, source: TieMarkerSource) {
        self.type = type
        self.source = source
    }
}

public enum TieMarkerSource: Equatable, Sendable {
    case tieElement
    case tiedNotation
}

public struct SlurMarker: Equatable, Sendable {
    public var type: NotationSpanType
    public var number: Int?
    public var placement: String?

    public init(type: NotationSpanType, number: Int? = nil, placement: String? = nil) {
        self.type = type
        self.number = number
        self.placement = placement
    }
}

public enum BeamValue: String, Equatable, Sendable {
    case begin
    case end
    case `continue`
    case forwardHook
    case backwardHook
    case unknown
}

public struct BeamMarker: Equatable, Sendable {
    public var number: Int?
    public var value: BeamValue

    public init(number: Int? = nil, value: BeamValue) {
        self.number = number
        self.value = value
    }
}

public struct TupletMarker: Equatable, Sendable {
    public var type: NotationSpanType
    public var number: Int?
    public var bracket: Bool?
    public var placement: String?
    public var showNumber: String?
    public var showType: String?

    public init(
        type: NotationSpanType,
        number: Int? = nil,
        bracket: Bool? = nil,
        placement: String? = nil,
        showNumber: String? = nil,
        showType: String? = nil
    ) {
        self.type = type
        self.number = number
        self.bracket = bracket
        self.placement = placement
        self.showNumber = showNumber
        self.showType = showType
    }
}

public struct TimeModification: Equatable, Sendable {
    public var actualNotes: Int?
    public var normalNotes: Int?

    public init(actualNotes: Int? = nil, normalNotes: Int? = nil) {
        self.actualNotes = actualNotes
        self.normalNotes = normalNotes
    }
}

public struct LyricEvent: Equatable, Sendable {
    public var number: Int
    public var text: String?
    public var syllabic: String?
    public var extend: Bool

    public init(number: Int = 1, text: String? = nil, syllabic: String? = nil, extend: Bool = false) {
        self.number = number
        self.text = text
        self.syllabic = syllabic
        self.extend = extend
    }
}

public enum TimingDirectiveKind: Equatable, Sendable {
    case backup
    case forward
}

public struct TimingDirective: Equatable, Sendable {
    public var kind: TimingDirectiveKind
    public var durationDivisions: Int

    public init(kind: TimingDirectiveKind, durationDivisions: Int) {
        self.kind = kind
        self.durationDivisions = durationDivisions
    }
}
