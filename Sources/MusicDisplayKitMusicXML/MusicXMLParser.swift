import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import MusicDisplayKitModel

public protocol ScoreParser {
    func parse(xml: String) throws -> Score
}

public enum MusicXMLParserError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyInput
    case missingScorePartwise
    case parserFailure(String)

    public var description: String {
        switch self {
        case .emptyInput:
            return "MusicXML input is empty."
        case .missingScorePartwise:
            return "MusicXML root <score-partwise> not found."
        case .parserFailure(let message):
            return "XML parser failure: \(message)"
        }
    }
}

public struct MusicXMLParser: ScoreDataParser {
    public init() {}

    public func parse(xml: String) throws -> Score {
        guard !xml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MusicXMLParserError.emptyInput
        }

        let parser = XMLParser(data: Data(xml.utf8))
        let delegate = ScorePartwiseXMLDelegate()
        parser.delegate = delegate

        let ok = parser.parse()
        if !ok {
            let message = parser.parserError?.localizedDescription ?? "Unknown XML parser error"
            throw MusicXMLParserError.parserFailure(message)
        }

        return try delegate.makeScore()
    }

    public func parse(data: Data, pathExtension: String? = nil) throws -> Score {
        let xml: String
        do {
            xml = try MusicXMLDocumentLoader().loadMusicXMLString(
                from: data,
                pathExtension: pathExtension
            )
        } catch let documentError as MusicXMLDocumentLoaderError {
            throw MusicXMLParserError.parserFailure(documentError.description)
        }
        return try parse(xml: xml)
    }

    public func parse(fileURL: URL) throws -> Score {
        do {
            let data = try Data(contentsOf: fileURL)
            return try parse(data: data, pathExtension: fileURL.pathExtension)
        } catch let parserError as MusicXMLParserError {
            throw parserError
        } catch {
            throw MusicXMLParserError.parserFailure(error.localizedDescription)
        }
    }
}

private final class ScorePartwiseXMLDelegate: NSObject, XMLParserDelegate {
    private struct PartBuilder {
        let id: String
        let name: String?
        var measures: [Measure] = []

        func build() -> Part {
            Part(id: id, name: name, measures: measures)
        }
    }

    private struct PartGroupBuilder {
        var number: Int?
        var startPartID: String?
        var endPartID: String?
        var symbol: PartGroupSymbol?
        var barline: Bool?
        var name: String?

        func build() -> PartGroup? {
            guard let startPartID, let endPartID else {
                return nil
            }
            return PartGroup(
                number: number,
                startPartID: startPartID,
                endPartID: endPartID,
                symbol: symbol,
                barline: barline,
                name: name
            )
        }
    }

    private struct MeasureBuilder {
        let number: Int
        let xmlNumber: String?
        var divisions: Int?
        var attributes: MeasureAttributes?
        var noteEvents: [NoteEvent] = []
        var timingDirectives: [TimingDirective] = []
        var directionEvents: [DirectionEvent] = []
        var harmonyEvents: [HarmonyEvent] = []
        var repetitionInstructions: [RepetitionInstruction] = []
        var tempoEvents: [TempoEvent] = []
        var timeCursorDivisions: Int = 0
        var lastNonChordOnsetByVoice: [Int: Int] = [:]

        func build() -> Measure {
            Measure(
                number: number,
                xmlNumber: xmlNumber,
                divisions: divisions,
                attributes: attributes,
                noteEvents: noteEvents,
                timingDirectives: timingDirectives,
                directionEvents: directionEvents,
                harmonyEvents: harmonyEvents,
                repetitionInstructions: repetitionInstructions,
                tempoEvents: tempoEvents
            )
        }
    }

    private struct KeyBuilder {
        var fifths: Int?
        var mode: String?
    }

    private struct TimeBuilder {
        var beats: Int?
        var beatType: Int?
        var symbol: String?
    }

    private struct ClefBuilder {
        var sign: String?
        var line: Int?
        var number: Int?
        var octaveChange: Int?
    }

    private struct LyricBuilder {
        var number: Int = 1
        var text: String?
        var syllabic: String?
        var extend: Bool = false
    }

    private struct MetronomeBuilder {
        var beatUnit: String?
        var beatUnitDotCount: Int = 0
        var perMinute: String?
        var parentheses: Bool?

        func build() -> MetronomeMark? {
            if beatUnit == nil && beatUnitDotCount == 0 && perMinute == nil {
                return nil
            }
            return MetronomeMark(
                beatUnit: beatUnit,
                beatUnitDotCount: beatUnitDotCount,
                perMinute: perMinute,
                parentheses: parentheses
            )
        }
    }

    private struct DirectionBuilder {
        var placement: String?
        var offsetDivisions: Int = 0
        var voice: Int?
        var staff: Int?
        var soundTempo: Double?
        var metronome: MetronomeMark?
        var dynamics: [String] = []
        var words: [String] = []
        var rehearsal: String?
        var wedges: [WedgeMarker] = []
        var octaveShifts: [OctaveShiftMarker] = []
        var pedals: [PedalMarker] = []
        var repetitionInstructions: [RepetitionInstruction] = []

        func build(currentOnset: Int) -> DirectionEvent? {
            let onset = max(0, currentOnset + offsetDivisions)
            if soundTempo == nil,
               metronome == nil,
               dynamics.isEmpty,
               words.isEmpty,
               rehearsal == nil,
               wedges.isEmpty,
               octaveShifts.isEmpty,
               pedals.isEmpty {
                return nil
            }
            return DirectionEvent(
                onsetDivisions: onset,
                offsetDivisions: offsetDivisions,
                placement: placement,
                voice: voice,
                staff: staff,
                soundTempo: soundTempo,
                metronome: metronome,
                dynamics: dynamics,
                words: words,
                rehearsal: rehearsal,
                wedges: wedges,
                octaveShifts: octaveShifts,
                pedals: pedals
            )
        }

        func buildRepetitionInstructions(currentOnset: Int) -> [RepetitionInstruction] {
            let onset = max(0, currentOnset + offsetDivisions)
            return repetitionInstructions.map { instruction in
                RepetitionInstruction(
                    onsetDivisions: onset,
                    kind: instruction.kind,
                    location: instruction.location,
                    times: instruction.times,
                    endingNumbers: instruction.endingNumbers,
                    target: instruction.target,
                    text: instruction.text
                )
            }
        }
    }

    private struct HarmonyDegreeBuilder {
        var value: Int?
        var alter: Int?
        var type: HarmonyDegreeType?

        enum BuildResult {
            case valid(HarmonyDegree)
            case invalid
        }

        func build() -> BuildResult {
            guard let value,
                  let alter,
                  let type else {
                return .invalid
            }
            if case .unknown = type {
                return .invalid
            }
            return .valid(HarmonyDegree(value: value, alter: alter, type: type))
        }
    }

    private struct HarmonyBuilder {
        var offsetDivisions: Int = 0
        var placement: String?
        var printObject: Bool?
        var numeralRoot: String?
        var numeralAlter: Int?
        var rootStep: String?
        var rootAlter: Int = 0
        var bassStep: String?
        var bassAlter: Int = 0
        var kind: String?
        var kindText: String?
        var kindUsesSymbols: Bool?
        var staff: Int?
        var degrees: [HarmonyDegree] = []
        var hasInvalidDegree: Bool = false
        var hasInvalidPitchStep: Bool = false

        func build(currentOnset: Int) -> HarmonyEvent? {
            if hasInvalidDegree || hasInvalidPitchStep {
                return nil
            }
            if numeralRoot == nil && rootStep == nil {
                return nil
            }
            let onset = max(0, currentOnset + offsetDivisions)
            if numeralRoot == nil,
               rootStep == nil,
               bassStep == nil,
               kind == nil,
               kindText == nil,
               degrees.isEmpty {
                return nil
            }
            return HarmonyEvent(
                onsetDivisions: onset,
                offsetDivisions: offsetDivisions,
                placement: placement,
                printObject: printObject,
                numeralRoot: numeralRoot,
                numeralAlter: numeralAlter,
                rootStep: rootStep,
                rootAlter: rootAlter,
                bassStep: bassStep,
                bassAlter: bassAlter,
                kind: kind,
                kindText: kindText,
                kindUsesSymbols: kindUsesSymbols,
                staff: staff,
                degrees: degrees
            )
        }
    }

    private struct NoteBuilder {
        var isRest = false
        var isChord = false
        var isGrace = false
        var voice: Int?
        var staff: Int?
        var durationDivisions: Int?
        var pitchStep: String?
        var pitchAlter: Int?
        var pitchOctave: Int?
        var lyrics: [LyricEvent] = []
        var ties: [TieMarker] = []
        var slurs: [SlurMarker] = []
        var beams: [BeamMarker] = []
        var tuplets: [TupletMarker] = []
        var timeModificationActualNotes: Int?
        var timeModificationNormalNotes: Int?
        var articulations: [ArticulationMarker] = []

        func build(onsetDivisions: Int) -> NoteEvent? {
            let resolvedVoice = max(voice ?? 1, 1)
            let timeModification = (
                timeModificationActualNotes != nil || timeModificationNormalNotes != nil
            ) ? TimeModification(
                actualNotes: timeModificationActualNotes,
                normalNotes: timeModificationNormalNotes
            ) : nil
            if isRest {
                return NoteEvent(
                    kind: .rest,
                    onsetDivisions: onsetDivisions,
                    durationDivisions: durationDivisions,
                    voice: resolvedVoice,
                    staff: staff,
                    isChord: isChord,
                    isGrace: isGrace,
                    lyrics: lyrics,
                    ties: ties,
                    slurs: slurs,
                    beams: beams,
                    tuplets: tuplets,
                    timeModification: timeModification,
                    articulations: articulations
                )
            }

            guard let pitchStep, let pitchOctave else {
                return nil
            }

            return NoteEvent(
                kind: .pitched,
                pitch: PitchValue(step: pitchStep, alter: pitchAlter ?? 0, octave: pitchOctave),
                onsetDivisions: onsetDivisions,
                durationDivisions: durationDivisions,
                voice: resolvedVoice,
                staff: staff,
                isChord: isChord,
                isGrace: isGrace,
                lyrics: lyrics,
                ties: ties,
                slurs: slurs,
                beams: beams,
                tuplets: tuplets,
                timeModification: timeModification,
                articulations: articulations
            )
        }
    }

    private struct PlaybackEndingRange {
        var start: Int
        var end: Int
        var numbers: Set<Int>
        var repeatEnd: Int?
    }

    private enum TextTarget {
        case workTitle
        case movementTitle
        case partName(partID: String)
        case partGroupSymbol
        case partGroupName
        case partGroupBarline
        case measureDivisions
        case noteDuration
        case noteVoice
        case pitchStep
        case pitchAlter
        case pitchOctave
        case noteStaff
        case lyricText
        case lyricSyllabic
        case beamValue
        case timeModificationActualNotes
        case timeModificationNormalNotes
        case directionOffset
        case directionVoice
        case directionStaff
        case directionWords
        case directionRehearsal
        case directionOtherDynamics
        case directionSegnoTarget
        case directionCodaTarget
        case harmonyOffset
        case harmonyRootStep
        case harmonyRootAlter
        case harmonyNumeralRoot
        case harmonyNumeralAlter
        case harmonyBassStep
        case harmonyBassAlter
        case harmonyKind
        case harmonyDegreeValue
        case harmonyDegreeAlter
        case harmonyDegreeType
        case harmonyStaff
        case metronomeBeatUnit
        case metronomePerMinute
        case timingDirectiveDuration
        case keyFifths
        case keyMode
        case timeBeats
        case timeBeatType
        case clefSign
        case clefLine
        case clefOctaveChange
    }

    private var sawScorePartwise = false
    private var insidePartList = false
    private var currentScorePartID: String?
    private var currentPart: PartBuilder?
    private var currentMeasure: MeasureBuilder?
    private var insideAttributes = false
    private var currentKeyBuilder: KeyBuilder?
    private var currentTimeBuilder: TimeBuilder?
    private var currentClefBuilder: ClefBuilder?
    private var currentNote: NoteBuilder?
    private var currentLyricBuilder: LyricBuilder?
    private var currentDirectionBuilder: DirectionBuilder?
    private var currentMetronomeBuilder: MetronomeBuilder?
    private var currentHarmonyBuilder: HarmonyBuilder?
    private var currentHarmonyDegreeBuilder: HarmonyDegreeBuilder?
    private var currentBarlineLocation: String?
    private var insideTimeModification = false
    private var insideArticulations = false
    private var currentArticulationsPlacement: String?
    private var insideDirectionType = false
    private var insideDynamics = false
    private var currentBeamNumber: Int?
    private var currentTimingDirectiveKind: TimingDirectiveKind?
    private var currentTimingDirectiveDuration: Int?
    private var currentTextTarget: TextTarget?
    private var textBuffer = ""
    private var partCounter = 0

    private var workTitle: String?
    private var movementTitle: String?
    private var partNamesByID: [String: String] = [:]
    private var parts: [Part] = []
    private var activePartGroupsByKey: [String: PartGroupBuilder] = [:]
    private var activePartGroupOrder: [String] = []
    private var currentPartGroupKey: String?
    private var parsedPartGroups: [PartGroup] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let element = elementName.lowercased()
        switch element {
        case "score-partwise":
            sawScorePartwise = true

        case "part-list":
            insidePartList = true

        case "score-part" where insidePartList:
            currentScorePartID = attributeDict["id"]?.trimmedNonEmpty
            if let currentScorePartID {
                registerPartIDForActivePartGroups(currentScorePartID)
            }

        case "part-group" where insidePartList:
            let key = partGroupKey(from: attributeDict["number"])
            let groupType = attributeDict["type"]?.trimmedNonEmpty?.lowercased()
            switch groupType {
            case "start":
                var builder = activePartGroupsByKey[key] ?? PartGroupBuilder()
                if builder.number == nil {
                    builder.number = attributeDict["number"]?.trimmedNonEmpty.flatMap(Int.init)
                }
                activePartGroupsByKey[key] = builder
                if !activePartGroupOrder.contains(key) {
                    activePartGroupOrder.append(key)
                }
                currentPartGroupKey = key
            case "stop":
                finalizePartGroup(forKey: key)
                currentPartGroupKey = nil
            default:
                currentPartGroupKey = nil
            }

        case "part-name" where insidePartList && currentScorePartID != nil:
            startTextCapture(.partName(partID: currentScorePartID!))

        case "group-symbol" where insidePartList && currentPartGroupKey != nil:
            startTextCapture(.partGroupSymbol)

        case "group-name" where insidePartList && currentPartGroupKey != nil:
            startTextCapture(.partGroupName)

        case "group-barline" where insidePartList && currentPartGroupKey != nil:
            startTextCapture(.partGroupBarline)

        case "part":
            partCounter += 1
            let id = attributeDict["id"]?.trimmedNonEmpty ?? "P\(partCounter)"
            let name = partNamesByID[id]
            currentPart = PartBuilder(id: id, name: name)

        case "measure":
            guard currentPart != nil else {
                return
            }
            let xmlNumber = attributeDict["number"]?.trimmedNonEmpty
            let parsedNumber = xmlNumber.flatMap(Int.init)
            let fallbackNumber = (currentPart?.measures.count ?? 0) + 1
            currentMeasure = MeasureBuilder(number: parsedNumber ?? fallbackNumber, xmlNumber: xmlNumber)
            currentBarlineLocation = nil

        case "barline" where currentMeasure != nil:
            currentBarlineLocation = attributeDict["location"]?.trimmedNonEmpty?.lowercased()

        case "repeat" where currentMeasure != nil:
            if let kind = parseRepeatInstructionKind(direction: attributeDict["direction"]),
               var currentMeasure {
                currentMeasure.repetitionInstructions.append(
                    RepetitionInstruction(
                        onsetDivisions: currentMeasure.timeCursorDivisions,
                        kind: kind,
                        location: currentBarlineLocation,
                        times: attributeDict["times"].flatMap(Int.init)
                    )
                )
                self.currentMeasure = currentMeasure
            }

        case "ending" where currentMeasure != nil:
            if let kind = parseEndingInstructionKind(type: attributeDict["type"]),
               var currentMeasure {
                currentMeasure.repetitionInstructions.append(
                    RepetitionInstruction(
                        onsetDivisions: currentMeasure.timeCursorDivisions,
                        kind: kind,
                        location: currentBarlineLocation,
                        endingNumbers: parseEndingNumbers(attributeDict["number"])
                    )
                )
                self.currentMeasure = currentMeasure
            }

        case "attributes" where currentMeasure != nil:
            insideAttributes = true

        case "divisions" where currentMeasure != nil && currentNote == nil:
            startTextCapture(.measureDivisions)

        case "key" where insideAttributes:
            currentKeyBuilder = KeyBuilder()

        case "fifths" where currentKeyBuilder != nil:
            startTextCapture(.keyFifths)

        case "mode" where currentKeyBuilder != nil:
            startTextCapture(.keyMode)

        case "time" where insideAttributes:
            currentTimeBuilder = TimeBuilder(symbol: attributeDict["symbol"]?.trimmedNonEmpty)

        case "beats" where currentTimeBuilder != nil:
            startTextCapture(.timeBeats)

        case "beat-type" where currentTimeBuilder != nil:
            startTextCapture(.timeBeatType)

        case "clef" where insideAttributes:
            currentClefBuilder = ClefBuilder(number: attributeDict["number"].flatMap(Int.init))

        case "sign" where currentClefBuilder != nil:
            startTextCapture(.clefSign)

        case "line" where currentClefBuilder != nil:
            startTextCapture(.clefLine)

        case "clef-octave-change" where currentClefBuilder != nil:
            startTextCapture(.clefOctaveChange)

        case "note":
            currentNote = NoteBuilder()
            currentLyricBuilder = nil
            insideTimeModification = false
            insideArticulations = false
            currentArticulationsPlacement = nil
            currentBeamNumber = nil

        case "direction" where currentMeasure != nil:
            currentDirectionBuilder = DirectionBuilder(
                placement: attributeDict["placement"]?.trimmedNonEmpty?.lowercased()
            )
            currentMetronomeBuilder = nil
            insideDirectionType = false
            insideDynamics = false

        case "direction-type" where currentDirectionBuilder != nil:
            insideDirectionType = true

        case "offset" where currentDirectionBuilder != nil && currentNote == nil:
            startTextCapture(.directionOffset)

        case "harmony" where currentMeasure != nil:
            currentHarmonyBuilder = HarmonyBuilder(
                placement: attributeDict["placement"]?.trimmedNonEmpty?.lowercased(),
                printObject: yesNoToBool(attributeDict["print-object"])
            )
            currentHarmonyDegreeBuilder = nil

        case "offset" where currentHarmonyBuilder != nil && currentNote == nil:
            startTextCapture(.harmonyOffset)

        case "root-step" where currentHarmonyBuilder != nil:
            startTextCapture(.harmonyRootStep)

        case "root-alter" where currentHarmonyBuilder != nil:
            startTextCapture(.harmonyRootAlter)

        case "numeral-root" where currentHarmonyBuilder != nil:
            if var currentHarmonyBuilder {
                currentHarmonyBuilder.numeralRoot = harmonyNumeralRootToken(
                    from: attributeDict["text"]
                )
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }
            startTextCapture(.harmonyNumeralRoot)

        case "numeral-alter" where currentHarmonyBuilder != nil:
            startTextCapture(.harmonyNumeralAlter)

        case "bass-step" where currentHarmonyBuilder != nil:
            startTextCapture(.harmonyBassStep)

        case "bass-alter" where currentHarmonyBuilder != nil:
            startTextCapture(.harmonyBassAlter)

        case "kind" where currentHarmonyBuilder != nil:
            if var currentHarmonyBuilder {
                currentHarmonyBuilder.kindText = attributeDict["text"]?.trimmedNonEmpty
                currentHarmonyBuilder.kindUsesSymbols = yesNoToBool(attributeDict["use-symbols"])
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }
            startTextCapture(.harmonyKind)

        case "degree" where currentHarmonyBuilder != nil:
            currentHarmonyDegreeBuilder = HarmonyDegreeBuilder()

        case "degree-value" where currentHarmonyDegreeBuilder != nil:
            startTextCapture(.harmonyDegreeValue)

        case "degree-alter" where currentHarmonyDegreeBuilder != nil:
            startTextCapture(.harmonyDegreeAlter)

        case "degree-type" where currentHarmonyDegreeBuilder != nil:
            startTextCapture(.harmonyDegreeType)

        case "voice" where currentDirectionBuilder != nil && currentNote == nil:
            startTextCapture(.directionVoice)

        case "staff" where currentDirectionBuilder != nil && currentNote == nil:
            startTextCapture(.directionStaff)

        case "staff" where currentHarmonyBuilder != nil && currentNote == nil:
            startTextCapture(.harmonyStaff)

        case "sound" where currentDirectionBuilder != nil:
            if var currentDirectionBuilder,
               let tempo = attributeDict["tempo"]?.trimmedNonEmpty.flatMap(Double.init) {
                currentDirectionBuilder.soundTempo = tempo
                self.currentDirectionBuilder = currentDirectionBuilder
            }
            if var currentDirectionBuilder {
                if yesNoToBool(attributeDict["dacapo"]) == true {
                    currentDirectionBuilder.repetitionInstructions.append(
                        RepetitionInstruction(onsetDivisions: 0, kind: .daCapo)
                    )
                }
                if let raw = attributeDict["dalsegno"]?.trimmedNonEmpty {
                    let target = normalizeMarkerTarget(raw)
                    currentDirectionBuilder.repetitionInstructions.append(
                        RepetitionInstruction(
                            onsetDivisions: 0,
                            kind: .dalSegno,
                            target: yesNoToBool(raw) == true ? nil : target
                        )
                    )
                }
                if let raw = attributeDict["tocoda"]?.trimmedNonEmpty {
                    let target = normalizeMarkerTarget(raw)
                    let resolvedTarget = yesNoToBool(raw) == true ? nil : target
                    currentDirectionBuilder.repetitionInstructions.append(
                        RepetitionInstruction(
                            onsetDivisions: 0,
                            kind: .alCoda,
                            target: resolvedTarget
                        )
                    )
                    currentDirectionBuilder.repetitionInstructions.append(
                        RepetitionInstruction(
                            onsetDivisions: 0,
                            kind: .toCoda,
                            target: resolvedTarget
                        )
                    )
                }
                if let fine = attributeDict["fine"]?.trimmedNonEmpty {
                    currentDirectionBuilder.repetitionInstructions.append(
                        RepetitionInstruction(
                            onsetDivisions: 0,
                            kind: .alFine,
                            target: yesNoToBool(fine) == true ? nil : normalizeMarkerTarget(fine),
                            text: fine
                        )
                    )
                }
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "segno" where currentDirectionBuilder != nil && insideDirectionType:
            startTextCapture(.directionSegnoTarget)

        case "coda" where currentDirectionBuilder != nil && insideDirectionType:
            startTextCapture(.directionCodaTarget)

        case "metronome" where currentDirectionBuilder != nil:
            currentMetronomeBuilder = MetronomeBuilder(
                parentheses: yesNoToBool(attributeDict["parentheses"])
            )

        case "beat-unit" where currentMetronomeBuilder != nil:
            startTextCapture(.metronomeBeatUnit)

        case "beat-unit-dot" where currentMetronomeBuilder != nil:
            if var currentMetronomeBuilder {
                currentMetronomeBuilder.beatUnitDotCount += 1
                self.currentMetronomeBuilder = currentMetronomeBuilder
            }

        case "per-minute" where currentMetronomeBuilder != nil:
            startTextCapture(.metronomePerMinute)

        case "dynamics" where currentDirectionBuilder != nil && insideDirectionType:
            insideDynamics = true

        case "other-dynamics" where currentDirectionBuilder != nil && insideDynamics:
            startTextCapture(.directionOtherDynamics)

        case "words" where currentDirectionBuilder != nil:
            startTextCapture(.directionWords)

        case "rehearsal" where currentDirectionBuilder != nil:
            startTextCapture(.directionRehearsal)

        case "wedge" where currentDirectionBuilder != nil:
            if var currentDirectionBuilder {
                currentDirectionBuilder.wedges.append(
                    WedgeMarker(
                        type: parseWedgeType(from: attributeDict["type"]),
                        number: attributeDict["number"].flatMap(Int.init),
                        spread: attributeDict["spread"]?.trimmedNonEmpty.flatMap(Double.init),
                        niente: yesNoToBool(attributeDict["niente"]),
                        lineType: attributeDict["line-type"]?.trimmedNonEmpty?.lowercased()
                    )
                )
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "octave-shift" where currentDirectionBuilder != nil:
            if var currentDirectionBuilder {
                currentDirectionBuilder.octaveShifts.append(
                    OctaveShiftMarker(
                        type: parseOctaveShiftType(from: attributeDict["type"]),
                        number: attributeDict["number"].flatMap(Int.init),
                        size: attributeDict["size"].flatMap(Int.init)
                    )
                )
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "pedal" where currentDirectionBuilder != nil:
            if var currentDirectionBuilder {
                currentDirectionBuilder.pedals.append(
                    PedalMarker(
                        type: parsePedalType(from: attributeDict["type"]),
                        line: yesNoToBool(attributeDict["line"]),
                        sign: yesNoToBool(attributeDict["sign"])
                    )
                )
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "rest" where currentNote != nil:
            currentNote?.isRest = true

        case "chord" where currentNote != nil:
            currentNote?.isChord = true

        case "grace" where currentNote != nil:
            currentNote?.isGrace = true

        case "lyric" where currentNote != nil:
            let parsedNumber = attributeDict["number"].flatMap(Int.init) ?? 1
            currentLyricBuilder = LyricBuilder(number: max(1, parsedNumber))

        case "text" where currentLyricBuilder != nil:
            startTextCapture(.lyricText)

        case "syllabic" where currentLyricBuilder != nil:
            startTextCapture(.lyricSyllabic)

        case "extend" where currentLyricBuilder != nil:
            currentLyricBuilder?.extend = true

        case "tie" where currentNote != nil:
            if var currentNote {
                let tieType = notationSpanType(from: attributeDict["type"])
                currentNote.ties.append(TieMarker(type: tieType, source: .tieElement))
                self.currentNote = currentNote
            }

        case "tied" where currentNote != nil:
            if var currentNote {
                let tieType = notationSpanType(from: attributeDict["type"])
                currentNote.ties.append(TieMarker(type: tieType, source: .tiedNotation))
                self.currentNote = currentNote
            }

        case "slur" where currentNote != nil:
            if var currentNote {
                let slur = SlurMarker(
                    type: notationSpanType(from: attributeDict["type"]),
                    number: attributeDict["number"].flatMap(Int.init),
                    placement: parseSlurPlacement(from: attributeDict)
                )
                currentNote.slurs.append(slur)
                self.currentNote = currentNote
            }

        case "beam" where currentNote != nil:
            currentBeamNumber = attributeDict["number"].flatMap(Int.init)
            startTextCapture(.beamValue)

        case "time-modification" where currentNote != nil:
            insideTimeModification = true

        case "actual-notes" where currentNote != nil && insideTimeModification:
            startTextCapture(.timeModificationActualNotes)

        case "normal-notes" where currentNote != nil && insideTimeModification:
            startTextCapture(.timeModificationNormalNotes)

        case "tuplet" where currentNote != nil:
            if var currentNote {
                currentNote.tuplets.append(
                    TupletMarker(
                        type: notationSpanType(from: attributeDict["type"]),
                        number: attributeDict["number"].flatMap(Int.init),
                        bracket: yesNoToBool(attributeDict["bracket"]),
                        placement: attributeDict["placement"]?.trimmedNonEmpty?.lowercased(),
                        showNumber: attributeDict["show-number"]?.trimmedNonEmpty,
                        showType: attributeDict["show-type"]?.trimmedNonEmpty
                    )
                )
                self.currentNote = currentNote
            }

        case "articulations" where currentNote != nil:
            insideArticulations = true
            currentArticulationsPlacement = attributeDict["placement"]?.trimmedNonEmpty?.lowercased()

        case _ where currentNote != nil && insideArticulations && isArticulationElement(element):
            if var currentNote {
                currentNote.articulations.append(
                    ArticulationMarker(
                        kind: parseArticulationKind(from: element),
                        placement: attributeDict["placement"]?.trimmedNonEmpty?.lowercased() ?? currentArticulationsPlacement,
                        type: attributeDict["type"]?.trimmedNonEmpty?.lowercased()
                    )
                )
                self.currentNote = currentNote
            }

        case _ where currentDirectionBuilder != nil && insideDynamics && element != "dynamics" && element != "other-dynamics":
            if var currentDirectionBuilder {
                currentDirectionBuilder.dynamics.append(element)
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "duration":
            if currentNote != nil {
                startTextCapture(.noteDuration)
            } else if currentTimingDirectiveKind != nil {
                startTextCapture(.timingDirectiveDuration)
            }

        case "voice" where currentNote != nil:
            startTextCapture(.noteVoice)

        case "staff" where currentNote != nil:
            startTextCapture(.noteStaff)

        case "step" where currentNote != nil:
            startTextCapture(.pitchStep)

        case "alter" where currentNote != nil:
            startTextCapture(.pitchAlter)

        case "octave" where currentNote != nil:
            startTextCapture(.pitchOctave)

        case "backup":
            currentTimingDirectiveKind = .backup
            currentTimingDirectiveDuration = nil

        case "forward":
            currentTimingDirectiveKind = .forward
            currentTimingDirectiveDuration = nil

        case "work-title":
            startTextCapture(.workTitle)

        case "movement-title":
            startTextCapture(.movementTitle)

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentTextTarget != nil else {
            return
        }
        textBuffer.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let element = elementName.lowercased()
        switch element {
        case "part":
            if let currentPart {
                parts.append(postProcessPart(currentPart.build()))
                self.currentPart = nil
            }

        case "measure":
            if let currentMeasure, var currentPart {
                var measure = currentMeasure.build()
                measure.tieSpans = linkTieSpans(in: measure.noteEvents)
                measure.slurSpans = linkSlurSpans(in: measure.noteEvents)
                measure.lyricWords = assembleLyricWords(in: measure.noteEvents)
                currentPart.measures.append(measure)
                self.currentPart = currentPart
                self.currentMeasure = nil
            }
            currentBarlineLocation = nil

        case "attributes":
            insideAttributes = false

        case "key":
            if let key = buildKeySignature(), var currentMeasure {
                var attributes = currentMeasure.attributes ?? MeasureAttributes()
                attributes.key = key
                currentMeasure.attributes = attributes
                self.currentMeasure = currentMeasure
            }
            currentKeyBuilder = nil

        case "time":
            if let time = buildTimeSignature(), var currentMeasure {
                var attributes = currentMeasure.attributes ?? MeasureAttributes()
                attributes.time = time
                currentMeasure.attributes = attributes
                self.currentMeasure = currentMeasure
            }
            currentTimeBuilder = nil

        case "clef":
            if let clef = buildClefSetting(), var currentMeasure {
                var attributes = currentMeasure.attributes ?? MeasureAttributes()
                attributes.clefs.append(clef)
                currentMeasure.attributes = attributes
                self.currentMeasure = currentMeasure
            }
            currentClefBuilder = nil

        case "note":
            if let noteBuilder = currentNote, var currentMeasure {
                let resolvedVoice = max(noteBuilder.voice ?? 1, 1)
                let onset = noteBuilder.isChord
                    ? (currentMeasure.lastNonChordOnsetByVoice[resolvedVoice] ?? currentMeasure.timeCursorDivisions)
                    : currentMeasure.timeCursorDivisions
                if let note = noteBuilder.build(onsetDivisions: onset) {
                    currentMeasure.noteEvents.append(note)
                }

                if !noteBuilder.isGrace && !noteBuilder.isChord {
                    currentMeasure.lastNonChordOnsetByVoice[resolvedVoice] = onset
                    currentMeasure.timeCursorDivisions += max(noteBuilder.durationDivisions ?? 0, 0)
                } else if noteBuilder.isGrace && !noteBuilder.isChord {
                    currentMeasure.lastNonChordOnsetByVoice[resolvedVoice] = onset
                }
                self.currentMeasure = currentMeasure
            }
            currentNote = nil
            currentLyricBuilder = nil
            insideTimeModification = false
            insideArticulations = false
            currentArticulationsPlacement = nil
            currentBeamNumber = nil

        case "direction":
            if let directionBuilder = currentDirectionBuilder,
               var currentMeasure {
                if let direction = directionBuilder.build(currentOnset: currentMeasure.timeCursorDivisions) {
                    currentMeasure.directionEvents.append(direction)
                }
                let repeats = directionBuilder.buildRepetitionInstructions(
                    currentOnset: currentMeasure.timeCursorDivisions
                )
                currentMeasure.repetitionInstructions.append(contentsOf: repeats)
                self.currentMeasure = currentMeasure
            }
            currentDirectionBuilder = nil
            currentMetronomeBuilder = nil
            insideDirectionType = false
            insideDynamics = false

        case "segno":
            if var currentDirectionBuilder {
                let target: String?
                if case .directionSegnoTarget = currentTextTarget {
                    target = normalizeMarkerTarget(consumeCapturedText())
                } else {
                    target = nil
                }
                currentDirectionBuilder.repetitionInstructions.append(
                    RepetitionInstruction(onsetDivisions: 0, kind: .segno, target: target)
                )
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "coda":
            if var currentDirectionBuilder {
                let target: String?
                if case .directionCodaTarget = currentTextTarget {
                    target = normalizeMarkerTarget(consumeCapturedText())
                } else {
                    target = nil
                }
                currentDirectionBuilder.repetitionInstructions.append(
                    RepetitionInstruction(onsetDivisions: 0, kind: .coda, target: target)
                )
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "harmony":
            if let harmonyBuilder = currentHarmonyBuilder,
               var currentMeasure,
               let harmony = harmonyBuilder.build(currentOnset: currentMeasure.timeCursorDivisions) {
                currentMeasure.harmonyEvents.append(harmony)
                self.currentMeasure = currentMeasure
            }
            currentHarmonyBuilder = nil
            currentHarmonyDegreeBuilder = nil

        case "degree":
            if let degreeBuilder = currentHarmonyDegreeBuilder,
               var currentHarmonyBuilder {
                switch degreeBuilder.build() {
                case .valid(let degree):
                    currentHarmonyBuilder.degrees.append(degree)
                case .invalid:
                    currentHarmonyBuilder.hasInvalidDegree = true
                }
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }
            currentHarmonyDegreeBuilder = nil

        case "direction-type":
            insideDirectionType = false

        case "dynamics":
            insideDynamics = false

        case "metronome":
            if let metronome = currentMetronomeBuilder?.build(),
               var currentDirectionBuilder {
                currentDirectionBuilder.metronome = metronome
                self.currentDirectionBuilder = currentDirectionBuilder
            }
            currentMetronomeBuilder = nil

        case "articulations":
            insideArticulations = false
            currentArticulationsPlacement = nil

        case "barline":
            currentBarlineLocation = nil

        case "beam":
            if case .beamValue = currentTextTarget,
               var currentNote {
                let beamValue = parseBeamValue(from: consumeCapturedText())
                currentNote.beams.append(BeamMarker(number: currentBeamNumber, value: beamValue))
                self.currentNote = currentNote
            }
            currentBeamNumber = nil

        case "time-modification":
            insideTimeModification = false

        case "lyric":
            if let lyric = buildLyricEvent(),
               var currentNote {
                currentNote.lyrics.append(lyric)
                self.currentNote = currentNote
            }
            currentLyricBuilder = nil

        case "backup":
            finishTimingDirective(.backup)

        case "forward":
            finishTimingDirective(.forward)

        case "part-group":
            currentPartGroupKey = nil

        case "score-part":
            currentScorePartID = nil

        case "part-list":
            insidePartList = false
            finalizeAllOpenPartGroups()

        case "work-title":
            if case .workTitle = currentTextTarget {
                workTitle = consumeCapturedText()
            }

        case "movement-title":
            if case .movementTitle = currentTextTarget {
                movementTitle = consumeCapturedText()
            }

        case "part-name":
            if case .partName = currentTextTarget {
                finishPartNameCapture()
            }

        case "group-symbol":
            if case .partGroupSymbol = currentTextTarget,
               let value = consumeCapturedText(),
               var currentPartGroup = currentBuilderPartGroup() {
                currentPartGroup.symbol = parsePartGroupSymbol(from: value)
                updateCurrentBuilderPartGroup(currentPartGroup)
            }

        case "group-name":
            if case .partGroupName = currentTextTarget,
               let value = consumeCapturedText(),
               var currentPartGroup = currentBuilderPartGroup() {
                currentPartGroup.name = value
                updateCurrentBuilderPartGroup(currentPartGroup)
            }

        case "group-barline":
            if case .partGroupBarline = currentTextTarget,
               let value = consumeCapturedText(),
               var currentPartGroup = currentBuilderPartGroup() {
                currentPartGroup.barline = yesNoToBool(value)
                updateCurrentBuilderPartGroup(currentPartGroup)
            }

        case "divisions":
            if case .measureDivisions = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentMeasure {
                currentMeasure.divisions = value
                self.currentMeasure = currentMeasure
            }

        case "fifths":
            if case .keyFifths = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var keyBuilder = currentKeyBuilder {
                keyBuilder.fifths = value
                currentKeyBuilder = keyBuilder
            }

        case "mode":
            if case .keyMode = currentTextTarget,
               let value = consumeCapturedText(),
               var keyBuilder = currentKeyBuilder {
                keyBuilder.mode = value.lowercased()
                currentKeyBuilder = keyBuilder
            }

        case "beats":
            if case .timeBeats = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var timeBuilder = currentTimeBuilder {
                timeBuilder.beats = value
                currentTimeBuilder = timeBuilder
            }

        case "beat-type":
            if case .timeBeatType = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var timeBuilder = currentTimeBuilder {
                timeBuilder.beatType = value
                currentTimeBuilder = timeBuilder
            }

        case "sign":
            if case .clefSign = currentTextTarget,
               let value = consumeCapturedText(),
               var clefBuilder = currentClefBuilder {
                clefBuilder.sign = value.uppercased()
                currentClefBuilder = clefBuilder
            }

        case "line":
            if case .clefLine = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var clefBuilder = currentClefBuilder {
                clefBuilder.line = value
                currentClefBuilder = clefBuilder
            }

        case "clef-octave-change":
            if case .clefOctaveChange = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var clefBuilder = currentClefBuilder {
                clefBuilder.octaveChange = value
                currentClefBuilder = clefBuilder
            }

        case "duration":
            if case .noteDuration = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentNote {
                currentNote.durationDivisions = value
                self.currentNote = currentNote
            } else if case .timingDirectiveDuration = currentTextTarget,
                      let value = consumeCapturedText().flatMap(Int.init) {
                currentTimingDirectiveDuration = value
            }

        case "offset":
            if case .directionOffset = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentDirectionBuilder {
                currentDirectionBuilder.offsetDivisions = value
                self.currentDirectionBuilder = currentDirectionBuilder
            } else if case .harmonyOffset = currentTextTarget,
                      let value = consumeCapturedText().flatMap(Int.init),
                      var currentHarmonyBuilder {
                currentHarmonyBuilder.offsetDivisions = value
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }

        case "voice":
            if case .noteVoice = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentNote {
                currentNote.voice = value
                self.currentNote = currentNote
            } else if case .directionVoice = currentTextTarget,
                      let value = consumeCapturedText().flatMap(Int.init),
                      var currentDirectionBuilder {
                currentDirectionBuilder.voice = value
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "staff":
            if case .noteStaff = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentNote {
                currentNote.staff = value
                self.currentNote = currentNote
            } else if case .directionStaff = currentTextTarget,
                      let value = consumeCapturedText().flatMap(Int.init),
                      var currentDirectionBuilder {
                currentDirectionBuilder.staff = value
                self.currentDirectionBuilder = currentDirectionBuilder
            } else if case .harmonyStaff = currentTextTarget,
                      let value = consumeCapturedText().flatMap(Int.init),
                      var currentHarmonyBuilder {
                currentHarmonyBuilder.staff = value
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }

        case "text":
            if case .lyricText = currentTextTarget,
               let value = consumeCapturedText(),
               var lyricBuilder = currentLyricBuilder {
                lyricBuilder.text = value
                currentLyricBuilder = lyricBuilder
            }

        case "words":
            if case .directionWords = currentTextTarget,
               let value = consumeCapturedText(),
               var currentDirectionBuilder {
                currentDirectionBuilder.words.append(value)
                currentDirectionBuilder.repetitionInstructions.append(
                    contentsOf: parseWordBasedRepetitionInstructions(words: value)
                )
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "rehearsal":
            if case .directionRehearsal = currentTextTarget,
               let value = consumeCapturedText(),
               var currentDirectionBuilder {
                currentDirectionBuilder.rehearsal = value
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "root-step":
            if case .harmonyRootStep = currentTextTarget,
               var currentHarmonyBuilder {
                let value = harmonyStepToken(from: consumeCapturedText())
                if let value {
                    currentHarmonyBuilder.rootStep = value
                } else {
                    currentHarmonyBuilder.hasInvalidPitchStep = true
                }
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }

        case "root-alter":
            if case .harmonyRootAlter = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentHarmonyBuilder {
                currentHarmonyBuilder.rootAlter = value
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }

        case "numeral-root":
            if case .harmonyNumeralRoot = currentTextTarget,
               var currentHarmonyBuilder {
                if currentHarmonyBuilder.numeralRoot == nil {
                    currentHarmonyBuilder.numeralRoot = harmonyNumeralRootToken(
                        from: consumeCapturedText()
                    )
                } else {
                    _ = consumeCapturedText()
                }
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }

        case "numeral-alter":
            if case .harmonyNumeralAlter = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentHarmonyBuilder {
                currentHarmonyBuilder.numeralAlter = value
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }

        case "bass-step":
            if case .harmonyBassStep = currentTextTarget,
               var currentHarmonyBuilder {
                let value = harmonyStepToken(from: consumeCapturedText())
                if let value {
                    currentHarmonyBuilder.bassStep = value
                } else {
                    currentHarmonyBuilder.hasInvalidPitchStep = true
                }
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }

        case "bass-alter":
            if case .harmonyBassAlter = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentHarmonyBuilder {
                currentHarmonyBuilder.bassAlter = value
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }

        case "kind":
            if case .harmonyKind = currentTextTarget,
               let value = consumeCapturedText()?.lowercased(),
               var currentHarmonyBuilder {
                currentHarmonyBuilder.kind = value
                self.currentHarmonyBuilder = currentHarmonyBuilder
            }

        case "other-dynamics":
            if case .directionOtherDynamics = currentTextTarget,
               let value = consumeCapturedText(),
               var currentDirectionBuilder {
                currentDirectionBuilder.dynamics.append(value.lowercased())
                self.currentDirectionBuilder = currentDirectionBuilder
            }

        case "syllabic":
            if case .lyricSyllabic = currentTextTarget,
               let value = consumeCapturedText(),
               var lyricBuilder = currentLyricBuilder {
                lyricBuilder.syllabic = value.lowercased()
                currentLyricBuilder = lyricBuilder
            }

        case "degree-value":
            if case .harmonyDegreeValue = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentHarmonyDegreeBuilder {
                currentHarmonyDegreeBuilder.value = value
                self.currentHarmonyDegreeBuilder = currentHarmonyDegreeBuilder
            }

        case "degree-alter":
            if case .harmonyDegreeAlter = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentHarmonyDegreeBuilder {
                currentHarmonyDegreeBuilder.alter = value
                self.currentHarmonyDegreeBuilder = currentHarmonyDegreeBuilder
            }

        case "degree-type":
            if case .harmonyDegreeType = currentTextTarget,
               let value = consumeCapturedText(),
               var currentHarmonyDegreeBuilder {
                currentHarmonyDegreeBuilder.type = parseHarmonyDegreeType(from: value)
                self.currentHarmonyDegreeBuilder = currentHarmonyDegreeBuilder
            }

        case "beat-unit":
            if case .metronomeBeatUnit = currentTextTarget,
               let value = consumeCapturedText(),
               var currentMetronomeBuilder {
                currentMetronomeBuilder.beatUnit = value.lowercased()
                self.currentMetronomeBuilder = currentMetronomeBuilder
            }

        case "per-minute":
            if case .metronomePerMinute = currentTextTarget,
               let value = consumeCapturedText(),
               var currentMetronomeBuilder {
                currentMetronomeBuilder.perMinute = value
                self.currentMetronomeBuilder = currentMetronomeBuilder
            }

        case "actual-notes":
            if case .timeModificationActualNotes = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentNote {
                currentNote.timeModificationActualNotes = value
                self.currentNote = currentNote
            }

        case "normal-notes":
            if case .timeModificationNormalNotes = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentNote {
                currentNote.timeModificationNormalNotes = value
                self.currentNote = currentNote
            }

        case "step":
            if case .pitchStep = currentTextTarget,
               let step = consumeCapturedText()?.uppercased(),
               var currentNote {
                currentNote.pitchStep = step
                self.currentNote = currentNote
            }

        case "alter":
            if case .pitchAlter = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentNote {
                currentNote.pitchAlter = value
                self.currentNote = currentNote
            }

        case "octave":
            if case .pitchOctave = currentTextTarget,
               let value = consumeCapturedText().flatMap(Int.init),
               var currentNote {
                currentNote.pitchOctave = value
                self.currentNote = currentNote
            }

        default:
            break
        }
    }

    func makeScore() throws -> Score {
        if let currentPart {
            parts.append(postProcessPart(currentPart.build()))
        }
        finalizeAllOpenPartGroups()

        guard sawScorePartwise else {
            throw MusicXMLParserError.missingScorePartwise
        }

        let title = workTitle?.trimmedNonEmpty
            ?? movementTitle?.trimmedNonEmpty
            ?? "Untitled Score"
        return Score(
            title: title,
            parts: parts,
            partGroups: normalizedPartGroups(filteredTo: parts)
        )
    }

    private func postProcessPart(_ part: Part) -> Part {
        var part = part
        var runningTempoBPM = 120.0

        for index in part.measures.indices {
            var measure = part.measures[index]
            var tempoEvents: [TempoEvent] = [
                TempoEvent(onsetDivisions: 0, bpm: runningTempoBPM, source: .carryForward)
            ]

            let explicitEvents = explicitTempoEvents(from: measure.directionEvents)
            for event in explicitEvents {
                runningTempoBPM = event.bpm
                tempoEvents.append(event)
            }

            measure.tempoEvents = tempoEvents
            part.measures[index] = measure
        }

        part.playbackOrder = buildPlaybackOrder(for: part.measures)

        return part
    }

    private func explicitTempoEvents(from directions: [DirectionEvent]) -> [TempoEvent] {
        let ordered = directions.enumerated().sorted { lhs, rhs in
            let lhsOnset = lhs.element.onsetDivisions
            let rhsOnset = rhs.element.onsetDivisions
            if lhsOnset != rhsOnset {
                return lhsOnset < rhsOnset
            }
            return lhs.offset < rhs.offset
        }

        var eventByOnset: [Int: TempoEvent] = [:]

        for (_, direction) in ordered {
            let onset = max(0, direction.onsetDivisions)
            var candidates: [TempoEvent] = []

            if let bpm = direction.soundTempo, bpm > 0 {
                candidates.append(
                    TempoEvent(onsetDivisions: onset, bpm: bpm, source: .sound)
                )
            }

            if let perMinute = direction.metronome?.perMinute,
               let bpm = parseBPM(perMinute),
               bpm > 0 {
                let dottedBPM = bpm * metronomeDotMultiplier(direction.metronome?.beatUnitDotCount ?? 0)
                candidates.append(
                    TempoEvent(onsetDivisions: onset, bpm: dottedBPM, source: .metronome)
                )
            }

            for candidate in candidates {
                guard let existing = eventByOnset[onset] else {
                    eventByOnset[onset] = candidate
                    continue
                }

                if explicitTempoSourcePriority(candidate.source) <
                    explicitTempoSourcePriority(existing.source) {
                    eventByOnset[onset] = candidate
                }
            }
        }

        return eventByOnset.values.sorted { lhs, rhs in
            if lhs.onsetDivisions != rhs.onsetDivisions {
                return lhs.onsetDivisions < rhs.onsetDivisions
            }
            return explicitTempoSourcePriority(lhs.source) < explicitTempoSourcePriority(rhs.source)
        }
    }

    private func explicitTempoSourcePriority(_ source: TempoEventSource) -> Int {
        switch source {
        case .metronome:
            return 0
        case .sound:
            return 1
        case .carryForward:
            return 2
        }
    }

    private func metronomeDotMultiplier(_ dotCount: Int) -> Double {
        guard dotCount > 0 else {
            return 1
        }

        // Dotted beat units add halves repeatedly: 1 dot = 1.5, 2 dots = 1.75, ...
        var multiplier = 1.0
        var increment = 0.5
        for _ in 0..<dotCount {
            multiplier += increment
            increment *= 0.5
        }
        return multiplier
    }

    private func parseBPM(_ value: String) -> Double? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = Double(normalized.replacingOccurrences(of: ",", with: ".")) {
            return direct
        }

        if let range = normalized.range(
            of: #"[-+]?\d+(?:[.,]\d+)?"#,
            options: .regularExpression
        ) {
            let token = normalized[range].replacingOccurrences(of: ",", with: ".")
            return Double(token)
        }

        return nil
    }

    private func normalizeMarkerTarget(_ value: String?) -> String? {
        value?.trimmedNonEmpty?.lowercased()
    }

    private func buildPlaybackOrder(for measures: [Measure]) -> PlaybackOrder {
        struct JumpExecutionKey: Hashable {
            var measureIndex: Int
            var kind: RepetitionInstructionKind
            var target: String?
        }

        struct RoadmapState {
            var isActive: Bool = false
            var stopAtFine: Bool = false
            var requiresCoda: Bool = false
            var codaTarget: String?
        }

        guard !measures.isEmpty else {
            return PlaybackOrder(visits: [], termination: .endOfScore)
        }

        let repeatForwardSet = Set(
            measures.indices.filter { index in
                measures[index].repetitionInstructions.contains { $0.kind == .repeatForward }
            }
        )

        var backwardRepeatTotalIterationsByMeasure: [Int: Int] = [:]
        for index in measures.indices {
            if let instruction = measures[index].repetitionInstructions.first(where: { $0.kind == .repeatBackward }) {
                backwardRepeatTotalIterationsByMeasure[index] = max(1, instruction.times ?? 2)
            }
        }

        let repeatSectionStartByBackwardMeasure = buildRepeatSectionStartByBackwardMeasure(
            repeatForwardSet: repeatForwardSet,
            backwardRepeatTotalIterationsByMeasure: backwardRepeatTotalIterationsByMeasure,
            measureCount: measures.count
        )

        let endingRanges = buildEndingRanges(
            measures: measures,
            backwardRepeatTotalIterationsByMeasure: backwardRepeatTotalIterationsByMeasure
        )

        let segnoMarkers = buildMarkerIndex(kind: .segno, measures: measures)
        let codaMarkers = buildMarkerIndex(kind: .coda, measures: measures)

        var visits: [PlaybackVisit] = []
        var visitCountByMeasure: [Int: Int] = [:]
        var repeatIterationByEndMeasure: [Int: Int] = [:]
        var executedJumps: Set<JumpExecutionKey> = []
        var roadmap = RoadmapState()

        let maxSteps = max(256, measures.count * 24)
        var currentMeasureIndex = 0
        var termination: PlaybackTermination = .endOfScore
        var stepCount = 0

        playbackLoop: while currentMeasureIndex >= 0 && currentMeasureIndex < measures.count {
            if stepCount >= maxSteps {
                termination = .stepLimit
                break
            }

            if let skippedIndex = nextPlayableMeasureIndex(
                from: currentMeasureIndex,
                endingRanges: endingRanges,
                repeatIterationByEndMeasure: repeatIterationByEndMeasure
            ) {
                currentMeasureIndex = skippedIndex
                continue
            }

            let measure = measures[currentMeasureIndex]
            let visitNumber = (visitCountByMeasure[currentMeasureIndex] ?? 0) + 1
            visitCountByMeasure[currentMeasureIndex] = visitNumber
            visits.append(
                PlaybackVisit(
                    measureIndex: currentMeasureIndex,
                    measureNumber: measure.number,
                    visitNumber: visitNumber
                )
            )
            stepCount += 1

            let instructions = measure.repetitionInstructions

            if roadmap.isActive,
               roadmap.stopAtFine,
               instructions.contains(where: { $0.kind == .fine }) {
                termination = .fine
                break playbackLoop
            }

            let jumpDescriptor = preferredJumpInstruction(
                from: instructions,
                segnoMarkers: segnoMarkers,
                currentMeasureIndex: currentMeasureIndex
            )
            let jumpExecutionKey = jumpDescriptor.map {
                JumpExecutionKey(
                    measureIndex: currentMeasureIndex,
                    kind: $0.kind,
                    target: $0.target
                )
            }
            let hasPendingJumpCommand = {
                guard let jumpDescriptor,
                      let jumpExecutionKey else {
                    return false
                }
                guard !executedJumps.contains(jumpExecutionKey) else {
                    return false
                }
                return resolveJumpDestination(
                    jumpDescriptor,
                    segnoMarkers: segnoMarkers,
                    currentMeasureIndex: currentMeasureIndex
                ) != nil
            }()

            if roadmap.requiresCoda,
               !hasPendingJumpCommand,
               let toCodaInstruction = selectToCodaInstruction(
                   from: instructions,
                   requiredTarget: roadmap.codaTarget,
                   preferExplicitMarkersOnJumpCommandMeasure: instructions.contains {
                       $0.kind == .daCapo || $0.kind == .dalSegno
                   },
                   allowSoundFallbackWhenNoExplicitForwardMarker: !hasForwardExplicitToCodaTrigger(
                       measures: measures,
                       afterMeasureIndex: currentMeasureIndex,
                       requiredTarget: roadmap.codaTarget
                   )
               ) {
                let codaTarget = roadmap.codaTarget ?? toCodaInstruction.target
                let strictCodaTarget = normalizeMarkerTarget(codaTarget) != nil
                if let codaIndex = resolveMarkerIndex(
                    from: codaMarkers,
                    target: codaTarget,
                    strictTarget: strictCodaTarget,
                    anchorIndex: currentMeasureIndex,
                    direction: .forwardInclusive
                ) {
                    roadmap.requiresCoda = false
                    roadmap.codaTarget = nil
                    currentMeasureIndex = codaIndex
                    continue playbackLoop
                }
            }

            if let jump = jumpDescriptor,
               let executionKey = jumpExecutionKey,
               !executedJumps.contains(executionKey),
               let destination = resolveJumpDestination(
                       jump,
                       segnoMarkers: segnoMarkers,
                       currentMeasureIndex: currentMeasureIndex
                   ) {
                executedJumps.insert(executionKey)
                roadmap.isActive = true
                roadmap.stopAtFine = jump.stopAtFine
                roadmap.requiresCoda = jump.requiresCoda
                roadmap.codaTarget = jump.codaTarget
                currentMeasureIndex = destination
                continue playbackLoop
            }

            if let totalIterations = backwardRepeatTotalIterationsByMeasure[currentMeasureIndex] {
                let sectionStart = repeatSectionStartByBackwardMeasure[currentMeasureIndex] ?? 0
                let currentIteration = repeatIterationByEndMeasure[currentMeasureIndex] ?? 1

                if currentIteration < totalIterations {
                    repeatIterationByEndMeasure[currentMeasureIndex] = currentIteration + 1
                    currentMeasureIndex = sectionStart
                    continue playbackLoop
                }
            }

            currentMeasureIndex += 1
        }

        if currentMeasureIndex >= measures.count && termination != .stepLimit {
            termination = .endOfScore
        }

        return PlaybackOrder(visits: visits, termination: termination)
    }

    private struct JumpInstructionDescriptor {
        var kind: RepetitionInstructionKind
        var target: String?
        var stopAtFine: Bool
        var requiresCoda: Bool
        var codaTarget: String?
    }

    private enum MarkerSearchDirection {
        case any
        case backwardInclusive
        case forwardInclusive
    }

    private struct PlaybackMarkerIndex {
        var indexesByTarget: [String: [Int]]
        var untargeted: [Int]
        var all: [Int]
    }

    private func preferredJumpInstruction(
        from instructions: [RepetitionInstruction],
        segnoMarkers: PlaybackMarkerIndex,
        currentMeasureIndex: Int
    ) -> JumpInstructionDescriptor? {
        let stopAtFine = instructions.contains(where: { $0.kind == .alFine })
        let requiresCoda = instructions.contains(where: { $0.kind == .alCoda })
        let codaTarget = normalizeMarkerTarget(
            instructions.first(where: { $0.kind == .toCoda })?.target
        )

        let dalSegnoInstructions = instructions
            .filter { $0.kind == .dalSegno }
            .sorted { lhs, rhs in
                // Prefer targeted dalsegno over untargeted.
                (lhs.target != nil ? 0 : 1) < (rhs.target != nil ? 0 : 1)
            }

        for dalSegno in dalSegnoInstructions {
            let target = normalizeMarkerTarget(dalSegno.target)
            if resolveMarkerIndex(
                from: segnoMarkers,
                target: target,
                strictTarget: target != nil,
                anchorIndex: currentMeasureIndex,
                direction: .backwardInclusive,
                allowDirectionFallback: true
            ) != nil {
                return JumpInstructionDescriptor(
                    kind: .dalSegno,
                    target: target,
                    stopAtFine: stopAtFine,
                    requiresCoda: requiresCoda,
                    codaTarget: codaTarget
                )
            }
        }

        if instructions.contains(where: { $0.kind == .daCapo }) {
            return JumpInstructionDescriptor(
                kind: .daCapo,
                target: nil,
                stopAtFine: stopAtFine,
                requiresCoda: requiresCoda,
                codaTarget: codaTarget
            )
        }

        return nil
    }

    private func resolveJumpDestination(
        _ descriptor: JumpInstructionDescriptor,
        segnoMarkers: PlaybackMarkerIndex,
        currentMeasureIndex: Int
    ) -> Int? {
        switch descriptor.kind {
        case .daCapo:
            return 0
        case .dalSegno:
            return resolveMarkerIndex(
                from: segnoMarkers,
                target: descriptor.target,
                strictTarget: descriptor.target != nil,
                anchorIndex: currentMeasureIndex,
                direction: .backwardInclusive,
                allowDirectionFallback: true
            )
        default:
            return nil
        }
    }

    private func buildMarkerIndex(
        kind: RepetitionInstructionKind,
        measures: [Measure]
    ) -> PlaybackMarkerIndex {
        var indexesByTarget: [String: [Int]] = [:]
        var untargeted: [Int] = []
        var all: [Int] = []

        for measureIndex in measures.indices {
            let markers = measures[measureIndex].repetitionInstructions.filter { $0.kind == kind }
            for marker in markers {
                all.append(measureIndex)
                if let target = normalizeMarkerTarget(marker.target) {
                    indexesByTarget[target, default: []].append(measureIndex)
                } else {
                    untargeted.append(measureIndex)
                }
            }
        }

        return PlaybackMarkerIndex(
            indexesByTarget: indexesByTarget,
            untargeted: untargeted,
            all: all
        )
    }

    private func resolveMarkerIndex(
        from markers: PlaybackMarkerIndex,
        target: String?,
        strictTarget: Bool = false,
        anchorIndex: Int? = nil,
        direction: MarkerSearchDirection = .any,
        allowDirectionFallback: Bool = false
    ) -> Int? {
        if let target = normalizeMarkerTarget(target) {
            if let index = selectMarkerIndex(
                from: markers.indexesByTarget[target] ?? [],
                anchorIndex: anchorIndex,
                direction: direction,
                allowDirectionFallback: allowDirectionFallback
            ) {
                return index
            }
            if strictTarget {
                return nil
            }
        }

        if let untargeted = selectMarkerIndex(
            from: markers.untargeted,
            anchorIndex: anchorIndex,
            direction: direction,
            allowDirectionFallback: allowDirectionFallback
        ) {
            return untargeted
        }

        return selectMarkerIndex(
            from: markers.all,
            anchorIndex: anchorIndex,
            direction: direction,
            allowDirectionFallback: allowDirectionFallback
        )
    }

    private func selectMarkerIndex(
        from indexes: [Int],
        anchorIndex: Int?,
        direction: MarkerSearchDirection,
        allowDirectionFallback: Bool
    ) -> Int? {
        guard !indexes.isEmpty else {
            return nil
        }

        guard let anchorIndex else {
            return indexes.first
        }

        switch direction {
        case .any:
            return indexes.first
        case .backwardInclusive:
            if let match = indexes.last(where: { $0 <= anchorIndex }) {
                return match
            }
            return allowDirectionFallback ? indexes.first : nil
        case .forwardInclusive:
            if let match = indexes.first(where: { $0 >= anchorIndex }) {
                return match
            }
            return allowDirectionFallback ? indexes.last : nil
        }
    }

    private func selectToCodaInstruction(
        from instructions: [RepetitionInstruction],
        requiredTarget: String?,
        preferExplicitMarkersOnJumpCommandMeasure: Bool = false,
        allowSoundFallbackWhenNoExplicitForwardMarker: Bool = false
    ) -> RepetitionInstruction? {
        let allToCoda = instructions.filter { $0.kind == .toCoda }
        let toCoda: [RepetitionInstruction]
        if preferExplicitMarkersOnJumpCommandMeasure {
            let explicit = allToCoda.filter { $0.text?.trimmedNonEmpty != nil }
            if !explicit.isEmpty {
                toCoda = explicit
            } else if allowSoundFallbackWhenNoExplicitForwardMarker {
                toCoda = allToCoda
            } else {
                toCoda = []
            }
        } else {
            toCoda = allToCoda
        }

        guard !toCoda.isEmpty else {
            return nil
        }

        if let requiredTarget = normalizeMarkerTarget(requiredTarget) {
            if let exact = toCoda.first(where: { normalizeMarkerTarget($0.target) == requiredTarget }) {
                return exact
            }
            if let untargeted = toCoda.first(where: { $0.target == nil }) {
                return untargeted
            }
            return nil
        }

        return toCoda.first
    }

    private func hasForwardExplicitToCodaTrigger(
        measures: [Measure],
        afterMeasureIndex: Int,
        requiredTarget: String?
    ) -> Bool {
        guard afterMeasureIndex + 1 < measures.count else {
            return false
        }

        let normalizedRequired = normalizeMarkerTarget(requiredTarget)
        for index in (afterMeasureIndex + 1)..<measures.count {
            let instructions = measures[index].repetitionInstructions.filter {
                $0.kind == .toCoda && $0.text?.trimmedNonEmpty != nil
            }
            if instructions.isEmpty {
                continue
            }

            if normalizedRequired == nil {
                return true
            }

            if instructions.contains(where: { instruction in
                let target = normalizeMarkerTarget(instruction.target)
                return target == nil || target == normalizedRequired
            }) {
                return true
            }
        }

        return false
    }

    private func buildRepeatSectionStartByBackwardMeasure(
        repeatForwardSet: Set<Int>,
        backwardRepeatTotalIterationsByMeasure: [Int: Int],
        measureCount: Int
    ) -> [Int: Int] {
        var lastForwardByMeasure: [Int?] = Array(repeating: nil, count: measureCount)
        var lastForward: Int?
        for index in 0..<measureCount {
            if repeatForwardSet.contains(index) {
                lastForward = index
            }
            lastForwardByMeasure[index] = lastForward
        }

        let backwardIndices = backwardRepeatTotalIterationsByMeasure.keys.sorted()
        var output: [Int: Int] = [:]
        var lastImplicitSectionStart = 0

        for backwardIndex in backwardIndices {
            if let explicitStart = lastForwardByMeasure[backwardIndex] {
                output[backwardIndex] = explicitStart
                // Future implicit starts should continue from after this repeated section.
                lastImplicitSectionStart = backwardIndex + 1
            } else {
                let clampedStart = min(lastImplicitSectionStart, max(0, backwardIndex))
                output[backwardIndex] = clampedStart
                lastImplicitSectionStart = backwardIndex + 1
            }
        }

        return output
    }

    private func buildEndingRanges(
        measures: [Measure],
        backwardRepeatTotalIterationsByMeasure: [Int: Int]
    ) -> [PlaybackEndingRange] {
        let backwardIndices = backwardRepeatTotalIterationsByMeasure.keys.sorted()
        var ranges: [PlaybackEndingRange] = []
        var openStart: Int?
        var openNumbers: Set<Int> = []

        for index in measures.indices {
            let instructions = measures[index].repetitionInstructions
            if openStart == nil,
               let startInstruction = instructions.first(where: { $0.kind == .endingStart }) {
                openStart = index
                openNumbers = Set(startInstruction.endingNumbers)
            }

            if let start = openStart,
               instructions.contains(where: { $0.kind == .endingStop || $0.kind == .endingDiscontinue }) {
                let repeatEnd = resolveEndingRepeatEnd(
                    start: start,
                    end: index,
                    backwardIndices: backwardIndices
                )
                ranges.append(
                    PlaybackEndingRange(
                        start: start,
                        end: index,
                        numbers: openNumbers,
                        repeatEnd: repeatEnd
                    )
                )
                openStart = nil
                openNumbers = []
            }
        }

        if let start = openStart {
            let end = measures.count - 1
            let repeatEnd = resolveEndingRepeatEnd(
                start: start,
                end: end,
                backwardIndices: backwardIndices
            )
            ranges.append(
                PlaybackEndingRange(
                    start: start,
                    end: end,
                    numbers: openNumbers,
                    repeatEnd: repeatEnd
                )
            )
        }

        return ranges
    }

    private func resolveEndingRepeatEnd(
        start: Int,
        end: Int,
        backwardIndices: [Int]
    ) -> Int? {
        if let afterOrAt = backwardIndices.first(where: { $0 >= end }) {
            return afterOrAt
        }
        if let before = backwardIndices.last(where: { $0 <= start }) {
            return before
        }
        return nil
    }

    private func nextPlayableMeasureIndex(
        from currentIndex: Int,
        endingRanges: [PlaybackEndingRange],
        repeatIterationByEndMeasure: [Int: Int]
    ) -> Int? {
        for range in endingRanges where currentIndex >= range.start && currentIndex <= range.end {
            if range.numbers.isEmpty {
                continue
            }
            guard let repeatEnd = range.repeatEnd else {
                continue
            }
            let iteration = repeatIterationByEndMeasure[repeatEnd] ?? 1
            if !range.numbers.contains(iteration) {
                return range.end + 1
            }
        }
        return nil
    }

    private func startTextCapture(_ target: TextTarget) {
        currentTextTarget = target
        textBuffer = ""
    }

    private func consumeCapturedText() -> String? {
        defer {
            currentTextTarget = nil
            textBuffer = ""
        }
        return textBuffer.trimmedNonEmpty
    }

    private func finishPartNameCapture() {
        defer {
            currentTextTarget = nil
            textBuffer = ""
        }

        guard case .partName(let partID)? = currentTextTarget else {
            return
        }

        if let name = textBuffer.trimmedNonEmpty {
            partNamesByID[partID] = name
        }
    }

    private func buildKeySignature() -> KeySignature? {
        guard let keyBuilder = currentKeyBuilder,
              let fifths = keyBuilder.fifths else {
            return nil
        }
        return KeySignature(fifths: fifths, mode: keyBuilder.mode)
    }

    private func buildTimeSignature() -> TimeSignature? {
        guard let timeBuilder = currentTimeBuilder,
              let beats = timeBuilder.beats,
              let beatType = timeBuilder.beatType else {
            return nil
        }
        return TimeSignature(beats: beats, beatType: beatType, symbol: timeBuilder.symbol)
    }

    private func buildClefSetting() -> ClefSetting? {
        guard let clefBuilder = currentClefBuilder,
              let sign = clefBuilder.sign else {
            return nil
        }
        return ClefSetting(
            sign: sign,
            line: clefBuilder.line,
            number: clefBuilder.number,
            octaveChange: clefBuilder.octaveChange
        )
    }

    private func buildLyricEvent() -> LyricEvent? {
        guard let lyricBuilder = currentLyricBuilder else {
            return nil
        }
        if lyricBuilder.text == nil && !lyricBuilder.extend {
            return nil
        }
        return LyricEvent(
            number: lyricBuilder.number,
            text: lyricBuilder.text,
            syllabic: lyricBuilder.syllabic,
            extend: lyricBuilder.extend
        )
    }

    private func notationSpanType(from value: String?) -> NotationSpanType {
        switch value?.trimmedNonEmpty?.lowercased() {
        case "start":
            return .start
        case "stop":
            return .stop
        case "continue":
            return .`continue`
        default:
            return .unknown
        }
    }

    private func parseSlurPlacement(from attributes: [String: String]) -> String? {
        if let placement = attributes["placement"]?.trimmedNonEmpty?.lowercased() {
            switch placement {
            case "above", "top", "over":
                return "above"
            case "below", "bottom", "under":
                return "below"
            default:
                return placement
            }
        }
        switch attributes["orientation"]?.trimmedNonEmpty?.lowercased() {
        case "over", "top":
            return "above"
        case "under", "bottom":
            return "below"
        default:
            return nil
        }
    }

    private func parseBeamValue(from value: String?) -> BeamValue {
        switch value?.trimmedNonEmpty?.lowercased() {
        case "begin":
            return .begin
        case "end":
            return .end
        case "continue":
            return .`continue`
        case "forward hook", "forward-hook":
            return .forwardHook
        case "backward hook", "backward-hook":
            return .backwardHook
        default:
            return .unknown
        }
    }

    private func isArticulationElement(_ element: String) -> Bool {
        switch element {
        case "accent",
             "strong-accent",
             "staccato",
             "tenuto",
             "detached-legato",
             "staccatissimo",
             "spiccato",
             "scoop",
             "plop",
             "doit",
             "falloff",
             "breath-mark",
             "caesura",
             "stress",
             "unstress":
            return true
        default:
            return false
        }
    }

    private func parseArticulationKind(from element: String) -> ArticulationKind {
        switch element {
        case "accent":
            return .accent
        case "strong-accent":
            return .strongAccent
        case "staccato":
            return .staccato
        case "tenuto":
            return .tenuto
        case "detached-legato":
            return .detachedLegato
        case "staccatissimo":
            return .staccatissimo
        case "spiccato":
            return .spiccato
        case "scoop":
            return .scoop
        case "plop":
            return .plop
        case "doit":
            return .doit
        case "falloff":
            return .falloff
        case "breath-mark":
            return .breathMark
        case "caesura":
            return .caesura
        case "stress":
            return .stress
        case "unstress":
            return .unstress
        default:
            return .unknown(element)
        }
    }

    private func parseWedgeType(from value: String?) -> WedgeType {
        let normalized = value?.trimmedNonEmpty?.lowercased() ?? "unknown"
        switch normalized {
        case "crescendo":
            return .crescendo
        case "diminuendo":
            return .diminuendo
        case "stop":
            return .stop
        case "continue":
            return .`continue`
        default:
            return .unknown(normalized)
        }
    }

    private func parseOctaveShiftType(from value: String?) -> OctaveShiftType {
        let normalized = value?.trimmedNonEmpty?.lowercased() ?? "unknown"
        switch normalized {
        case "up":
            return .up
        case "down":
            return .down
        case "stop":
            return .stop
        case "continue":
            return .`continue`
        default:
            return .unknown(normalized)
        }
    }

    private func parsePedalType(from value: String?) -> PedalType {
        let normalized = value?.trimmedNonEmpty?.lowercased() ?? "unknown"
        switch normalized {
        case "start":
            return .start
        case "stop":
            return .stop
        case "change":
            return .change
        case "continue":
            return .`continue`
        case "discontinue":
            return .discontinue
        case "resume":
            return .resume
        default:
            return .unknown(normalized)
        }
    }

    private func parseHarmonyDegreeType(from value: String) -> HarmonyDegreeType {
        let normalized = value.trimmedNonEmpty?.lowercased() ?? "unknown"
        switch normalized {
        case "add":
            return .add
        case "alter":
            return .alter
        case "subtract":
            return .subtract
        default:
            return .unknown(normalized)
        }
    }

    private func harmonyStepToken(from value: String?) -> String? {
        guard let normalized = value?.trimmedNonEmpty?.uppercased() else {
            return nil
        }
        switch normalized {
        case "A", "B", "C", "D", "E", "F", "G":
            return normalized
        default:
            return nil
        }
    }

    private func harmonyNumeralRootToken(from value: String?) -> String? {
        guard let raw = value?.trimmedNonEmpty else {
            return nil
        }
        if let number = Int(raw), let roman = romanNumeralString(for: number) {
            return roman
        }
        return raw
    }

    private func romanNumeralString(for value: Int) -> String? {
        switch value {
        case 1:
            return "I"
        case 2:
            return "II"
        case 3:
            return "III"
        case 4:
            return "IV"
        case 5:
            return "V"
        case 6:
            return "VI"
        case 7:
            return "VII"
        case 8:
            return "VIII"
        case 9:
            return "IX"
        case 10:
            return "X"
        case 11:
            return "XI"
        case 12:
            return "XII"
        default:
            return nil
        }
    }

    private func parseRepeatInstructionKind(direction: String?) -> RepetitionInstructionKind? {
        switch direction?.trimmedNonEmpty?.lowercased() {
        case "forward":
            return .repeatForward
        case "backward":
            return .repeatBackward
        default:
            return nil
        }
    }

    private func parseEndingInstructionKind(type: String?) -> RepetitionInstructionKind? {
        switch type?.trimmedNonEmpty?.lowercased() {
        case "start":
            return .endingStart
        case "stop":
            return .endingStop
        case "discontinue":
            return .endingDiscontinue
        default:
            return nil
        }
    }

    private func parseEndingNumbers(_ value: String?) -> [Int] {
        guard let value else {
            return []
        }
        let tokens = value
            .replacingOccurrences(of: "+", with: " ")
            .split(whereSeparator: { $0 == "," || $0 == ";" })

        var parsed: [Int] = []
        for token in tokens {
            let text = String(token).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                continue
            }

            let rangeParts = text
                .split(separator: "-", maxSplits: 1)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if rangeParts.count == 2,
               let start = Int(rangeParts[0]),
               let end = Int(rangeParts[1]) {
                if start <= end {
                    parsed.append(contentsOf: start...end)
                } else {
                    parsed.append(contentsOf: stride(from: start, through: end, by: -1))
                }
                continue
            }

            parsed.append(
                contentsOf: text
                    .split(whereSeparator: { !$0.isNumber })
                    .compactMap { Int($0) }
            )
        }

        var seen: Set<Int> = []
        var deduplicated: [Int] = []
        for value in parsed where !seen.contains(value) {
            seen.insert(value)
            deduplicated.append(value)
        }
        return deduplicated
    }

    private func parseWordBasedRepetitionInstructions(words: String) -> [RepetitionInstruction] {
        let normalized = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return []
        }

        let hasDalSegno = containsRegex(normalized, pattern: #"\bd\s*\.?\s*s\.?\b"#)
            || containsRegex(normalized, pattern: #"\bdal\s+segno\b"#)
        let hasDaCapo = containsRegex(normalized, pattern: #"\bd\s*\.?\s*c\.?\b"#)
            || containsRegex(normalized, pattern: #"\bda\s*capo\b"#)
            || containsRegex(normalized, pattern: #"\bdacapo\b"#)
        let hasAlCoda = containsRegex(normalized, pattern: #"\bal\s+coda\b"#)
        let hasAlFine = containsRegex(normalized, pattern: #"\bal\s+fine\b"#)
        let hasToCoda = containsRegex(normalized, pattern: #"\bto\s+coda\b"#)
            || containsRegex(normalized, pattern: #"\ba\s+(?:la\s+)?coda\b"#)
        let hasFineMarker = containsRegex(normalized, pattern: #"\bfine\b"#) && !hasAlFine

        var kinds: [RepetitionInstructionKind] = []

        if hasDalSegno {
            kinds.append(.dalSegno)
        }
        if hasDaCapo {
            kinds.append(.daCapo)
        }
        if hasAlCoda {
            kinds.append(.alCoda)
        }
        if hasAlFine {
            kinds.append(.alFine)
        }
        if hasToCoda {
            kinds.append(.toCoda)
        }
        if hasFineMarker {
            kinds.append(.fine)
        }

        var seen: Set<RepetitionInstructionKind> = []
        var instructions: [RepetitionInstruction] = []
        for kind in kinds where !seen.contains(kind) {
            seen.insert(kind)
            instructions.append(
                RepetitionInstruction(onsetDivisions: 0, kind: kind, text: words)
            )
        }
        return instructions
    }

    private func containsRegex(_ input: String, pattern: String) -> Bool {
        input.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func linkTieSpans(in notes: [NoteEvent]) -> [TieSpan] {
        struct TieOpenKey: Hashable {
            var voice: Int
            var staff: Int?
            var step: String
            var alter: Int
            var octave: Int
        }

        var openByKey: [TieOpenKey: Int] = [:]
        var spans: [TieSpan] = []

        for (index, note) in notes.enumerated() {
            guard note.kind == .pitched, let pitch = note.pitch else {
                continue
            }

            let markers = tieMarkersForLinking(note)
            for marker in markers {
                let key = TieOpenKey(
                    voice: note.voice,
                    staff: note.staff,
                    step: pitch.step,
                    alter: pitch.alter,
                    octave: pitch.octave
                )
                switch marker.type {
                case .start:
                    openByKey[key] = index
                case .stop:
                    if let startIndex = openByKey.removeValue(forKey: key) {
                        spans.append(
                            TieSpan(
                                startNoteIndex: startIndex,
                                endNoteIndex: index,
                                source: marker.source,
                                voice: note.voice,
                                staff: note.staff,
                                pitch: pitch
                            )
                        )
                    }
                case .continue:
                    if let startIndex = openByKey.removeValue(forKey: key) {
                        spans.append(
                            TieSpan(
                                startNoteIndex: startIndex,
                                endNoteIndex: index,
                                source: marker.source,
                                voice: note.voice,
                                staff: note.staff,
                                pitch: pitch
                            )
                        )
                    }
                    openByKey[key] = index
                case .unknown:
                    break
                }
            }
        }

        return spans
    }

    private func tieMarkersForLinking(_ note: NoteEvent) -> [TieMarker] {
        let tieElements = note.ties.filter { $0.source == .tieElement }
        if !tieElements.isEmpty {
            return tieElements
        }
        return note.ties
    }

    private func linkSlurSpans(in notes: [NoteEvent]) -> [SlurSpan] {
        struct SlurOpenKey: Hashable {
            var number: Int
            var voice: Int
            var staff: Int?
        }
        struct SlurOpenValue {
            var rawNumber: Int?
            var startIndex: Int
            var placement: String?
            var sequence: Int
        }

        var openByKey: [SlurOpenKey: [SlurOpenValue]] = [:]
        var spans: [SlurSpan] = []
        var nextOpenSequence: Int = 0

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
                let lhsStart = lhs.value.last?.startIndex ?? Int.min
                let rhsStart = rhs.value.last?.startIndex ?? Int.min
                if lhsStart != rhsStart {
                    return lhsStart < rhsStart
                }
                let lhsStaff = lhs.key.staff ?? Int.max
                let rhsStaff = rhs.key.staff ?? Int.max
                return lhsStaff < rhsStaff
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

            // Robustness fallback for malformed input:
            // if stop/continue omits a number and no implicit "1" match exists,
            // close the most recent open slur in the same voice/staff.
            if requestedRawNumber == nil {
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
            }

            // Cross-staff fallback for implicit number-one slurs:
            // allow voice+number pairing when staff changes.
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

        for (index, note) in notes.enumerated() {
            for marker in note.slurs {
                let normalizedNumber = marker.number ?? 1
                let key = SlurOpenKey(number: normalizedNumber, voice: note.voice, staff: note.staff)

                switch marker.type {
                case .start:
                    let open = SlurOpenValue(
                        rawNumber: marker.number,
                        startIndex: index,
                        placement: marker.placement,
                        sequence: nextOpenSequence
                    )
                    nextOpenSequence += 1
                    openByKey[key, default: []].append(open)

                case .stop:
                    guard let resolvedKey = resolveStopKey(
                        requestedKey: key,
                        requestedRawNumber: marker.number
                    ),
                    var stack = openByKey[resolvedKey],
                    let open = stack.popLast() else {
                        continue
                    }
                    spans.append(
                        SlurSpan(
                            number: open.rawNumber ?? marker.number,
                            startNoteIndex: open.startIndex,
                            endNoteIndex: index,
                            voice: note.voice,
                            staff: note.staff,
                            placement: open.placement ?? marker.placement
                        )
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
                        spans.append(
                            SlurSpan(
                                number: open.rawNumber ?? marker.number,
                                startNoteIndex: open.startIndex,
                                endNoteIndex: index,
                                voice: note.voice,
                                staff: note.staff,
                                placement: open.placement ?? marker.placement
                            )
                        )
                        if stack.isEmpty {
                            openByKey.removeValue(forKey: resolvedKey)
                        } else {
                            openByKey[resolvedKey] = stack
                        }
                        let continuationRawNumber = marker.number ?? open.rawNumber
                        let continuationKey = SlurOpenKey(
                            number: continuationRawNumber ?? 1,
                            voice: note.voice,
                            staff: note.staff
                        )
                        let continuation = SlurOpenValue(
                            rawNumber: continuationRawNumber,
                            startIndex: index,
                            placement: marker.placement ?? open.placement,
                            sequence: nextOpenSequence
                        )
                        nextOpenSequence += 1
                        openByKey[continuationKey, default: []].append(continuation)
                    } else {
                        let open = SlurOpenValue(
                            rawNumber: marker.number,
                            startIndex: index,
                            placement: marker.placement,
                            sequence: nextOpenSequence
                        )
                        nextOpenSequence += 1
                        openByKey[key, default: []].append(open)
                    }

                case .unknown:
                    break
                }
            }
        }

        return spans
    }

    private func assembleLyricWords(in notes: [NoteEvent]) -> [LyricWord] {
        struct LyricWordBuilderState {
            var startIndex: Int
            var endIndex: Int
            var text: String?
            var hasExtension: Bool

            mutating func appendText(_ value: String?) {
                guard let value = value?.trimmedNonEmpty else {
                    return
                }
                if let existing = text {
                    text = existing + value
                } else {
                    text = value
                }
            }

            func build(number: Int) -> LyricWord {
                LyricWord(
                    number: number,
                    startNoteIndex: startIndex,
                    endNoteIndex: endIndex,
                    text: text,
                    hasExtension: hasExtension
                )
            }
        }

        var activeByNumber: [Int: LyricWordBuilderState] = [:]
        var words: [LyricWord] = []

        for (noteIndex, note) in notes.enumerated() {
            for lyric in note.lyrics {
                let number = max(lyric.number, 1)
                let syllabic = lyric.syllabic?.lowercased()
                let text = lyric.text?.trimmedNonEmpty

                switch syllabic {
                case "begin":
                    if let open = activeByNumber.removeValue(forKey: number) {
                        words.append(open.build(number: number))
                    }
                    activeByNumber[number] = LyricWordBuilderState(
                        startIndex: noteIndex,
                        endIndex: noteIndex,
                        text: text,
                        hasExtension: lyric.extend
                    )

                case "middle":
                    var open = activeByNumber[number] ?? LyricWordBuilderState(
                        startIndex: noteIndex,
                        endIndex: noteIndex,
                        text: nil,
                        hasExtension: false
                    )
                    open.endIndex = noteIndex
                    open.appendText(text)
                    open.hasExtension = open.hasExtension || lyric.extend
                    activeByNumber[number] = open

                case "end":
                    var open = activeByNumber[number] ?? LyricWordBuilderState(
                        startIndex: noteIndex,
                        endIndex: noteIndex,
                        text: nil,
                        hasExtension: false
                    )
                    open.endIndex = noteIndex
                    open.appendText(text)
                    open.hasExtension = open.hasExtension || lyric.extend
                    words.append(open.build(number: number))
                    activeByNumber.removeValue(forKey: number)

                default:
                    if let open = activeByNumber.removeValue(forKey: number) {
                        words.append(open.build(number: number))
                    }
                    if text != nil || lyric.extend {
                        words.append(
                            LyricWord(
                                number: number,
                                startNoteIndex: noteIndex,
                                endNoteIndex: noteIndex,
                                text: text,
                                hasExtension: lyric.extend
                            )
                        )
                    }
                }
            }
        }

        let remaining = activeByNumber.keys.sorted()
        for number in remaining {
            if let open = activeByNumber[number] {
                words.append(open.build(number: number))
            }
        }

        return words.sorted {
            if $0.startNoteIndex != $1.startNoteIndex {
                return $0.startNoteIndex < $1.startNoteIndex
            }
            if $0.number != $1.number {
                return $0.number < $1.number
            }
            return $0.endNoteIndex < $1.endNoteIndex
        }
    }

    private func registerPartIDForActivePartGroups(_ partID: String) {
        for key in activePartGroupOrder {
            guard var group = activePartGroupsByKey[key] else {
                continue
            }
            if group.startPartID == nil {
                group.startPartID = partID
            }
            group.endPartID = partID
            activePartGroupsByKey[key] = group
        }
    }

    private func partGroupKey(from number: String?) -> String {
        number?.trimmedNonEmpty ?? "1"
    }

    private func currentBuilderPartGroup() -> PartGroupBuilder? {
        guard let key = currentPartGroupKey else {
            return nil
        }
        return activePartGroupsByKey[key]
    }

    private func updateCurrentBuilderPartGroup(_ builder: PartGroupBuilder) {
        guard let key = currentPartGroupKey else {
            return
        }
        activePartGroupsByKey[key] = builder
    }

    private func finalizePartGroup(forKey key: String) {
        guard let group = activePartGroupsByKey.removeValue(forKey: key)?.build() else {
            activePartGroupOrder.removeAll { $0 == key }
            return
        }
        activePartGroupOrder.removeAll { $0 == key }
        parsedPartGroups.append(group)
    }

    private func finalizeAllOpenPartGroups() {
        let keys = activePartGroupOrder
        for key in keys {
            finalizePartGroup(forKey: key)
        }
        activePartGroupOrder = []
    }

    private func normalizedPartGroups(filteredTo parts: [Part]) -> [PartGroup] {
        let validIDs = Set(parts.map(\.id))
        return parsedPartGroups.filter { group in
            validIDs.contains(group.startPartID) && validIDs.contains(group.endPartID)
        }
    }

    private func parsePartGroupSymbol(from value: String) -> PartGroupSymbol? {
        switch value.trimmedNonEmpty?.lowercased() {
        case "brace":
            return .brace
        case "bracket":
            return .bracket
        case "line":
            return .line
        case "square":
            return .square
        case let raw?:
            return .unknown(raw)
        default:
            return nil
        }
    }

    private func yesNoToBool(_ value: String?) -> Bool? {
        switch value?.trimmedNonEmpty?.lowercased() {
        case "yes":
            return true
        case "no":
            return false
        default:
            return nil
        }
    }

    private func finishTimingDirective(_ expected: TimingDirectiveKind) {
        guard currentTimingDirectiveKind == expected else {
            return
        }
        defer {
            currentTimingDirectiveKind = nil
            currentTimingDirectiveDuration = nil
        }

        guard let duration = currentTimingDirectiveDuration,
              duration > 0,
              var currentMeasure else {
            return
        }

        currentMeasure.timingDirectives.append(
            TimingDirective(kind: expected, durationDivisions: duration)
        )
        switch expected {
        case .backup:
            currentMeasure.timeCursorDivisions = max(0, currentMeasure.timeCursorDivisions - duration)
        case .forward:
            currentMeasure.timeCursorDivisions += duration
        }
        self.currentMeasure = currentMeasure
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
