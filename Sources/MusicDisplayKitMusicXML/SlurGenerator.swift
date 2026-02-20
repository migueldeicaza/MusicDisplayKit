import MusicDisplayKitModel

public struct SlurEvent: Equatable, Sendable {
    public var partIndex: Int
    public var partID: String
    public var voice: Int
    public var staff: Int?
    public var number: Int?
    public var placement: String?
    public var startMeasureIndex: Int
    public var startMeasureNumber: Int
    public var startNoteIndex: Int
    public var startOnsetDivisions: Int
    public var endMeasureIndex: Int
    public var endMeasureNumber: Int
    public var endNoteIndex: Int
    public var endOnsetDivisions: Int
    public var spansMultipleMeasures: Bool
    public var isOpenEnded: Bool

    public init(
        partIndex: Int,
        partID: String,
        voice: Int,
        staff: Int?,
        number: Int?,
        placement: String?,
        startMeasureIndex: Int,
        startMeasureNumber: Int,
        startNoteIndex: Int,
        startOnsetDivisions: Int,
        endMeasureIndex: Int,
        endMeasureNumber: Int,
        endNoteIndex: Int,
        endOnsetDivisions: Int,
        spansMultipleMeasures: Bool,
        isOpenEnded: Bool
    ) {
        self.partIndex = partIndex
        self.partID = partID
        self.voice = voice
        self.staff = staff
        self.number = number
        self.placement = placement
        self.startMeasureIndex = startMeasureIndex
        self.startMeasureNumber = startMeasureNumber
        self.startNoteIndex = startNoteIndex
        self.startOnsetDivisions = startOnsetDivisions
        self.endMeasureIndex = endMeasureIndex
        self.endMeasureNumber = endMeasureNumber
        self.endNoteIndex = endNoteIndex
        self.endOnsetDivisions = endOnsetDivisions
        self.spansMultipleMeasures = spansMultipleMeasures
        self.isOpenEnded = isOpenEnded
    }
}

public struct SlurGenerator: Sendable {
    private struct SlurKey: Hashable {
        var voice: Int
        var staff: Int?
        var number: Int?
    }

    private struct NotePosition {
        var measureIndex: Int
        var measureNumber: Int
        var noteIndex: Int
        var onsetDivisions: Int
    }

    private struct OpenSlur {
        var key: SlurKey
        var start: NotePosition
        var placement: String?
    }

    public init() {}

    public func generate(from score: Score) -> [SlurEvent] {
        var output: [SlurEvent] = []

        for (partIndex, part) in score.parts.enumerated() {
            var openByKey: [SlurKey: OpenSlur] = [:]

            for (measureIndex, measure) in part.measures.enumerated() {
                for noteIndex in measure.noteEvents.indices {
                    let note = measure.noteEvents[noteIndex]
                    let notePosition = NotePosition(
                        measureIndex: measureIndex,
                        measureNumber: measure.number,
                        noteIndex: noteIndex,
                        onsetDivisions: note.onsetDivisions
                    )

                    for marker in note.slurs {
                        let key = SlurKey(voice: note.voice, staff: note.staff, number: marker.number)
                        switch marker.type {
                        case .start:
                            if let existing = openByKey.removeValue(forKey: key) {
                                output.append(
                                    buildEvent(
                                        partIndex: partIndex,
                                        partID: part.id,
                                        openSlur: existing,
                                        endPosition: existing.start,
                                        endPlacement: marker.placement,
                                        isOpenEnded: true
                                    )
                                )
                            }
                            openByKey[key] = OpenSlur(
                                key: key,
                                start: notePosition,
                                placement: marker.placement
                            )

                        case .stop:
                            guard let open = openByKey.removeValue(forKey: key) else {
                                continue
                            }
                            output.append(
                                buildEvent(
                                    partIndex: partIndex,
                                    partID: part.id,
                                    openSlur: open,
                                    endPosition: notePosition,
                                    endPlacement: marker.placement,
                                    isOpenEnded: false
                                )
                            )

                        case .`continue`, .unknown:
                            continue
                        }
                    }
                }
            }

            for open in openByKey.values {
                output.append(
                    buildEvent(
                        partIndex: partIndex,
                        partID: part.id,
                        openSlur: open,
                        endPosition: open.start,
                        endPlacement: nil,
                        isOpenEnded: true
                    )
                )
            }
        }

        return output.sorted { lhs, rhs in
            if lhs.partIndex != rhs.partIndex {
                return lhs.partIndex < rhs.partIndex
            }
            if lhs.startMeasureIndex != rhs.startMeasureIndex {
                return lhs.startMeasureIndex < rhs.startMeasureIndex
            }
            if lhs.startOnsetDivisions != rhs.startOnsetDivisions {
                return lhs.startOnsetDivisions < rhs.startOnsetDivisions
            }
            if lhs.startNoteIndex != rhs.startNoteIndex {
                return lhs.startNoteIndex < rhs.startNoteIndex
            }
            if lhs.voice != rhs.voice {
                return lhs.voice < rhs.voice
            }
            return staffSortValue(lhs.staff) < staffSortValue(rhs.staff)
        }
    }

    private func buildEvent(
        partIndex: Int,
        partID: String,
        openSlur: OpenSlur,
        endPosition: NotePosition,
        endPlacement: String?,
        isOpenEnded: Bool
    ) -> SlurEvent {
        SlurEvent(
            partIndex: partIndex,
            partID: partID,
            voice: openSlur.key.voice,
            staff: openSlur.key.staff,
            number: openSlur.key.number,
            placement: openSlur.placement ?? endPlacement,
            startMeasureIndex: openSlur.start.measureIndex,
            startMeasureNumber: openSlur.start.measureNumber,
            startNoteIndex: openSlur.start.noteIndex,
            startOnsetDivisions: openSlur.start.onsetDivisions,
            endMeasureIndex: endPosition.measureIndex,
            endMeasureNumber: endPosition.measureNumber,
            endNoteIndex: endPosition.noteIndex,
            endOnsetDivisions: endPosition.onsetDivisions,
            spansMultipleMeasures: openSlur.start.measureIndex != endPosition.measureIndex,
            isOpenEnded: isOpenEnded
        )
    }

    private func staffSortValue(_ staff: Int?) -> Int {
        staff ?? Int.max
    }
}
