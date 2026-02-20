import MusicDisplayKitModel

public enum ExpressionSemanticValue: Equatable, Sendable {
    case dynamic(String)
    case words(String)
    case rehearsal(String)
    case wedge(WedgeMarker)
    case octaveShift(OctaveShiftMarker)
    case pedal(PedalMarker)
    case soundTempo(Double)
    case metronome(MetronomeMark)
    case repetition(RepetitionInstruction)
}

public struct ExpressionEvent: Equatable, Sendable {
    public var partIndex: Int
    public var partID: String
    public var measureIndex: Int
    public var measureNumber: Int
    public var onsetDivisions: Int
    public var offsetDivisions: Int
    public var placement: String?
    public var voice: Int?
    public var staff: Int?
    public var value: ExpressionSemanticValue

    public init(
        partIndex: Int,
        partID: String,
        measureIndex: Int,
        measureNumber: Int,
        onsetDivisions: Int,
        offsetDivisions: Int,
        placement: String?,
        voice: Int?,
        staff: Int?,
        value: ExpressionSemanticValue
    ) {
        self.partIndex = partIndex
        self.partID = partID
        self.measureIndex = measureIndex
        self.measureNumber = measureNumber
        self.onsetDivisions = onsetDivisions
        self.offsetDivisions = offsetDivisions
        self.placement = placement
        self.voice = voice
        self.staff = staff
        self.value = value
    }
}

public struct ExpressionGenerator: Sendable {
    public init() {}

    public func generate(from score: Score) -> [ExpressionEvent] {
        var output: [ExpressionEvent] = []

        for (partIndex, part) in score.parts.enumerated() {
            for (measureIndex, measure) in part.measures.enumerated() {
                for direction in measure.directionEvents {
                    output.append(contentsOf: buildDirectionEvents(
                        direction: direction,
                        partIndex: partIndex,
                        partID: part.id,
                        measureIndex: measureIndex,
                        measureNumber: measure.number
                    ))
                }

                for instruction in measure.repetitionInstructions where roadmapInstructionKinds.contains(instruction.kind) {
                    output.append(
                        ExpressionEvent(
                            partIndex: partIndex,
                            partID: part.id,
                            measureIndex: measureIndex,
                            measureNumber: measure.number,
                            onsetDivisions: instruction.onsetDivisions,
                            offsetDivisions: 0,
                            placement: nil,
                            voice: nil,
                            staff: nil,
                            value: .repetition(instruction)
                        )
                    )
                }
            }
        }

        return output.sorted(by: compareExpressions)
    }

    private func buildDirectionEvents(
        direction: DirectionEvent,
        partIndex: Int,
        partID: String,
        measureIndex: Int,
        measureNumber: Int
    ) -> [ExpressionEvent] {
        func baseEvent(_ value: ExpressionSemanticValue) -> ExpressionEvent {
            ExpressionEvent(
                partIndex: partIndex,
                partID: partID,
                measureIndex: measureIndex,
                measureNumber: measureNumber,
                onsetDivisions: direction.onsetDivisions,
                offsetDivisions: direction.offsetDivisions,
                placement: direction.placement,
                voice: direction.voice,
                staff: direction.staff,
                value: value
            )
        }

        var output: [ExpressionEvent] = []

        for dynamic in direction.dynamics where !dynamic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output.append(baseEvent(.dynamic(dynamic)))
        }
        for word in direction.words where !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output.append(baseEvent(.words(word)))
        }
        if let rehearsal = direction.rehearsal?.trimmingCharacters(in: .whitespacesAndNewlines), !rehearsal.isEmpty {
            output.append(baseEvent(.rehearsal(rehearsal)))
        }
        for wedge in direction.wedges {
            output.append(baseEvent(.wedge(wedge)))
        }
        for shift in direction.octaveShifts {
            output.append(baseEvent(.octaveShift(shift)))
        }
        for pedal in direction.pedals {
            output.append(baseEvent(.pedal(pedal)))
        }
        if let soundTempo = direction.soundTempo {
            output.append(baseEvent(.soundTempo(soundTempo)))
        }
        if let metronome = direction.metronome {
            output.append(baseEvent(.metronome(metronome)))
        }

        return output
    }

    private func compareExpressions(lhs: ExpressionEvent, rhs: ExpressionEvent) -> Bool {
        if lhs.partIndex != rhs.partIndex {
            return lhs.partIndex < rhs.partIndex
        }
        if lhs.measureIndex != rhs.measureIndex {
            return lhs.measureIndex < rhs.measureIndex
        }
        if lhs.onsetDivisions != rhs.onsetDivisions {
            return lhs.onsetDivisions < rhs.onsetDivisions
        }
        if valueSortRank(lhs.value) != valueSortRank(rhs.value) {
            return valueSortRank(lhs.value) < valueSortRank(rhs.value)
        }
        return valueSortKey(lhs.value) < valueSortKey(rhs.value)
    }

    private func valueSortRank(_ value: ExpressionSemanticValue) -> Int {
        switch value {
        case .dynamic:
            return 0
        case .words:
            return 1
        case .rehearsal:
            return 2
        case .wedge:
            return 3
        case .octaveShift:
            return 4
        case .pedal:
            return 5
        case .soundTempo:
            return 6
        case .metronome:
            return 7
        case .repetition:
            return 8
        }
    }

    private func valueSortKey(_ value: ExpressionSemanticValue) -> String {
        switch value {
        case .dynamic(let value):
            return value
        case .words(let value):
            return value
        case .rehearsal(let value):
            return value
        case .wedge(let marker):
            return "\(marker.type)|\(marker.number ?? -1)|\(marker.spread ?? -1)"
        case .octaveShift(let marker):
            return "\(marker.type)|\(marker.number ?? -1)|\(marker.size ?? -1)"
        case .pedal(let marker):
            return "\(marker.type)|\(String(describing: marker.line))|\(String(describing: marker.sign))"
        case .soundTempo(let bpm):
            return "\(bpm)"
        case .metronome(let mark):
            return "\(mark.beatUnit ?? "")|\(mark.beatUnitDotCount)|\(mark.perMinute ?? "")"
        case .repetition(let instruction):
            return "\(instruction.kind)|\(instruction.target ?? "")|\(instruction.text ?? "")"
        }
    }

    private var roadmapInstructionKinds: Set<RepetitionInstructionKind> {
        [
            .segno,
            .coda,
            .daCapo,
            .dalSegno,
            .toCoda,
            .fine,
            .alFine,
            .alCoda
        ]
    }
}
