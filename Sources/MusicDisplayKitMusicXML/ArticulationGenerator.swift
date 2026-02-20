import MusicDisplayKitModel

public struct ArticulationEvent: Equatable, Sendable {
    public var partIndex: Int
    public var partID: String
    public var measureIndex: Int
    public var measureNumber: Int
    public var noteIndex: Int
    public var onsetDivisions: Int
    public var voice: Int
    public var staff: Int?
    public var kind: ArticulationKind
    public var placement: String?
    public var type: String?

    public init(
        partIndex: Int,
        partID: String,
        measureIndex: Int,
        measureNumber: Int,
        noteIndex: Int,
        onsetDivisions: Int,
        voice: Int,
        staff: Int?,
        kind: ArticulationKind,
        placement: String?,
        type: String?
    ) {
        self.partIndex = partIndex
        self.partID = partID
        self.measureIndex = measureIndex
        self.measureNumber = measureNumber
        self.noteIndex = noteIndex
        self.onsetDivisions = onsetDivisions
        self.voice = voice
        self.staff = staff
        self.kind = kind
        self.placement = placement
        self.type = type
    }
}

public struct ArticulationGenerator: Sendable {
    public init() {}

    public func generate(from score: Score) -> [ArticulationEvent] {
        var output: [ArticulationEvent] = []

        for (partIndex, part) in score.parts.enumerated() {
            for (measureIndex, measure) in part.measures.enumerated() {
                for noteIndex in measure.noteEvents.indices {
                    let note = measure.noteEvents[noteIndex]
                    guard !note.articulations.isEmpty else {
                        continue
                    }

                    for marker in note.articulations {
                        output.append(
                            ArticulationEvent(
                                partIndex: partIndex,
                                partID: part.id,
                                measureIndex: measureIndex,
                                measureNumber: measure.number,
                                noteIndex: noteIndex,
                                onsetDivisions: note.onsetDivisions,
                                voice: note.voice,
                                staff: note.staff,
                                kind: marker.kind,
                                placement: marker.placement,
                                type: marker.type
                            )
                        )
                    }
                }
            }
        }

        return output.sorted { lhs, rhs in
            if lhs.partIndex != rhs.partIndex {
                return lhs.partIndex < rhs.partIndex
            }
            if lhs.measureIndex != rhs.measureIndex {
                return lhs.measureIndex < rhs.measureIndex
            }
            if lhs.onsetDivisions != rhs.onsetDivisions {
                return lhs.onsetDivisions < rhs.onsetDivisions
            }
            return lhs.noteIndex < rhs.noteIndex
        }
    }
}
