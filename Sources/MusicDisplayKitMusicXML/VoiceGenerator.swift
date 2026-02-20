import MusicDisplayKitModel

public struct VoiceGeneratedEntry: Equatable, Sendable {
    public var voice: Int
    public var staff: Int?
    public var onsetDivisions: Int
    public var noteIndices: [Int]
    public var durationDivisions: Int?
    public var isGrace: Bool

    public init(
        voice: Int,
        staff: Int?,
        onsetDivisions: Int,
        noteIndices: [Int],
        durationDivisions: Int?,
        isGrace: Bool
    ) {
        self.voice = voice
        self.staff = staff
        self.onsetDivisions = onsetDivisions
        self.noteIndices = noteIndices
        self.durationDivisions = durationDivisions
        self.isGrace = isGrace
    }
}

public struct VoiceBeamSpan: Equatable, Sendable {
    public var number: Int?
    public var startEntryIndex: Int
    public var endEntryIndex: Int

    public init(number: Int?, startEntryIndex: Int, endEntryIndex: Int) {
        self.number = number
        self.startEntryIndex = startEntryIndex
        self.endEntryIndex = endEntryIndex
    }
}

public struct VoiceTupletSpan: Equatable, Sendable {
    public var number: Int?
    public var startEntryIndex: Int
    public var endEntryIndex: Int

    public init(number: Int?, startEntryIndex: Int, endEntryIndex: Int) {
        self.number = number
        self.startEntryIndex = startEntryIndex
        self.endEntryIndex = endEntryIndex
    }
}

public struct VoiceTieSpan: Equatable, Sendable {
    public var startEntryIndex: Int
    public var endEntryIndex: Int
    public var source: TieMarkerSource
    public var voice: Int
    public var staff: Int?
    public var pitch: PitchValue?

    public init(
        startEntryIndex: Int,
        endEntryIndex: Int,
        source: TieMarkerSource,
        voice: Int,
        staff: Int?,
        pitch: PitchValue?
    ) {
        self.startEntryIndex = startEntryIndex
        self.endEntryIndex = endEntryIndex
        self.source = source
        self.voice = voice
        self.staff = staff
        self.pitch = pitch
    }
}

public struct VoiceSlurSpan: Equatable, Sendable {
    public var number: Int?
    public var startEntryIndex: Int
    public var endEntryIndex: Int
    public var voice: Int
    public var staff: Int?
    public var placement: String?

    public init(
        number: Int?,
        startEntryIndex: Int,
        endEntryIndex: Int,
        voice: Int,
        staff: Int?,
        placement: String?
    ) {
        self.number = number
        self.startEntryIndex = startEntryIndex
        self.endEntryIndex = endEntryIndex
        self.voice = voice
        self.staff = staff
        self.placement = placement
    }
}

public struct VoiceMeasureData: Equatable, Sendable {
    public var partIndex: Int
    public var partID: String
    public var measureIndex: Int
    public var measureNumber: Int
    public var voice: Int
    public var staff: Int?
    public var entries: [VoiceGeneratedEntry]
    public var beamSpans: [VoiceBeamSpan]
    public var tupletSpans: [VoiceTupletSpan]
    public var tieSpans: [VoiceTieSpan]
    public var slurSpans: [VoiceSlurSpan]

    public init(
        partIndex: Int,
        partID: String,
        measureIndex: Int,
        measureNumber: Int,
        voice: Int,
        staff: Int?,
        entries: [VoiceGeneratedEntry],
        beamSpans: [VoiceBeamSpan],
        tupletSpans: [VoiceTupletSpan],
        tieSpans: [VoiceTieSpan],
        slurSpans: [VoiceSlurSpan]
    ) {
        self.partIndex = partIndex
        self.partID = partID
        self.measureIndex = measureIndex
        self.measureNumber = measureNumber
        self.voice = voice
        self.staff = staff
        self.entries = entries
        self.beamSpans = beamSpans
        self.tupletSpans = tupletSpans
        self.tieSpans = tieSpans
        self.slurSpans = slurSpans
    }
}

public struct VoiceGenerator: Sendable {
    private struct VoiceStaffKey: Hashable {
        var voice: Int
        var staff: Int?
    }

    private struct NumberKey: Hashable {
        var number: Int?
    }

    private struct SpanKey: Hashable {
        var number: Int?
        var start: Int
        var end: Int
    }

    private struct MarkerOccurrenceKey: Hashable {
        var entryIndex: Int
        var number: Int?
        var beamValue: BeamValue?
        var spanType: NotationSpanType?
    }

    public init() {}

    public func generate(from score: Score) -> [VoiceMeasureData] {
        var output: [VoiceMeasureData] = []

        for (partIndex, part) in score.parts.enumerated() {
            for (measureIndex, measure) in part.measures.enumerated() {
                let noteEvents = measure.noteEvents
                guard !noteEvents.isEmpty else {
                    continue
                }

                var grouped: [VoiceStaffKey: [Int]] = [:]
                for noteIndex in noteEvents.indices {
                    let note = noteEvents[noteIndex]
                    let key = VoiceStaffKey(voice: note.voice, staff: note.staff)
                    grouped[key, default: []].append(noteIndex)
                }

                let sortedKeys = grouped.keys.sorted { lhs, rhs in
                    if lhs.voice != rhs.voice {
                        return lhs.voice < rhs.voice
                    }
                    return staffSortValue(lhs.staff) < staffSortValue(rhs.staff)
                }

                for key in sortedKeys {
                    let noteIndices = grouped[key] ?? []
                    let sortedNoteIndices = noteIndices.sorted { lhs, rhs in
                        let l = noteEvents[lhs]
                        let r = noteEvents[rhs]
                        if l.onsetDivisions != r.onsetDivisions {
                            return l.onsetDivisions < r.onsetDivisions
                        }
                        return lhs < rhs
                    }

                    let groupedByOnset = Dictionary(grouping: sortedNoteIndices) { noteEvents[$0].onsetDivisions }
                    let sortedOnsets = groupedByOnset.keys.sorted()
                    var entries: [VoiceGeneratedEntry] = []
                    var noteToEntryIndex: [Int: Int] = [:]

                    for onset in sortedOnsets {
                        let entryNoteIndices = (groupedByOnset[onset] ?? []).sorted()
                        let durations = entryNoteIndices.compactMap { noteEvents[$0].durationDivisions }
                        let duration = durations.max()
                        let isGrace = entryNoteIndices.allSatisfy { noteEvents[$0].isGrace }
                        let entry = VoiceGeneratedEntry(
                            voice: key.voice,
                            staff: key.staff,
                            onsetDivisions: onset,
                            noteIndices: entryNoteIndices,
                            durationDivisions: duration,
                            isGrace: isGrace
                        )
                        let entryIndex = entries.count
                        entries.append(entry)
                        for noteIndex in entryNoteIndices {
                            noteToEntryIndex[noteIndex] = entryIndex
                        }
                    }

                    let beamSpans = buildBeamSpans(
                        noteIndices: sortedNoteIndices,
                        noteEvents: noteEvents,
                        noteToEntryIndex: noteToEntryIndex
                    )

                    let tupletSpans = buildTupletSpans(
                        noteIndices: sortedNoteIndices,
                        noteEvents: noteEvents,
                        noteToEntryIndex: noteToEntryIndex
                    )

                    let tieSpans: [VoiceTieSpan] = measure.tieSpans.compactMap { (tie: TieSpan) -> VoiceTieSpan? in
                        guard tie.voice == key.voice, tie.staff == key.staff else {
                            return nil
                        }
                        guard let start = noteToEntryIndex[tie.startNoteIndex],
                              let end = noteToEntryIndex[tie.endNoteIndex] else {
                            return nil
                        }
                        return VoiceTieSpan(
                            startEntryIndex: start,
                            endEntryIndex: end,
                            source: tie.source,
                            voice: tie.voice,
                            staff: tie.staff,
                            pitch: tie.pitch
                        )
                    }.sorted { (lhs: VoiceTieSpan, rhs: VoiceTieSpan) in
                        if lhs.startEntryIndex != rhs.startEntryIndex {
                            return lhs.startEntryIndex < rhs.startEntryIndex
                        }
                        return lhs.endEntryIndex < rhs.endEntryIndex
                    }

                    let slurSpans: [VoiceSlurSpan] = measure.slurSpans.compactMap { (slur: SlurSpan) -> VoiceSlurSpan? in
                        guard slur.voice == key.voice, slur.staff == key.staff else {
                            return nil
                        }
                        guard let start = noteToEntryIndex[slur.startNoteIndex],
                              let end = noteToEntryIndex[slur.endNoteIndex] else {
                            return nil
                        }
                        return VoiceSlurSpan(
                            number: slur.number,
                            startEntryIndex: start,
                            endEntryIndex: end,
                            voice: slur.voice,
                            staff: slur.staff,
                            placement: slur.placement
                        )
                    }.sorted { (lhs: VoiceSlurSpan, rhs: VoiceSlurSpan) in
                        if lhs.startEntryIndex != rhs.startEntryIndex {
                            return lhs.startEntryIndex < rhs.startEntryIndex
                        }
                        return lhs.endEntryIndex < rhs.endEntryIndex
                    }

                    output.append(
                        VoiceMeasureData(
                            partIndex: partIndex,
                            partID: part.id,
                            measureIndex: measureIndex,
                            measureNumber: measure.number,
                            voice: key.voice,
                            staff: key.staff,
                            entries: entries,
                            beamSpans: beamSpans,
                            tupletSpans: tupletSpans,
                            tieSpans: tieSpans,
                            slurSpans: slurSpans
                        )
                    )
                }
            }
        }

        return output
    }

    private func buildBeamSpans(
        noteIndices: [Int],
        noteEvents: [NoteEvent],
        noteToEntryIndex: [Int: Int]
    ) -> [VoiceBeamSpan] {
        var spans: [VoiceBeamSpan] = []
        var seen: Set<SpanKey> = []
        var processed: Set<MarkerOccurrenceKey> = []
        var openByNumber: [NumberKey: Int] = [:]

        for noteIndex in noteIndices {
            guard let entryIndex = noteToEntryIndex[noteIndex] else {
                continue
            }

            for beam in noteEvents[noteIndex].beams {
                let numberKey = NumberKey(number: beam.number)
                let markerKey = MarkerOccurrenceKey(
                    entryIndex: entryIndex,
                    number: beam.number,
                    beamValue: beam.value,
                    spanType: nil
                )
                if processed.contains(markerKey) {
                    continue
                }
                processed.insert(markerKey)

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
                        let key = SpanKey(number: beam.number, start: min(start, entryIndex), end: max(start, entryIndex))
                        if !seen.contains(key) {
                            seen.insert(key)
                            spans.append(
                                VoiceBeamSpan(number: beam.number, startEntryIndex: key.start, endEntryIndex: key.end)
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
            return staffSortValue(lhs.number) < staffSortValue(rhs.number)
        }
    }

    private func buildTupletSpans(
        noteIndices: [Int],
        noteEvents: [NoteEvent],
        noteToEntryIndex: [Int: Int]
    ) -> [VoiceTupletSpan] {
        var spans: [VoiceTupletSpan] = []
        var seen: Set<SpanKey> = []
        var processed: Set<MarkerOccurrenceKey> = []
        var openByNumber: [NumberKey: Int] = [:]

        for noteIndex in noteIndices {
            guard let entryIndex = noteToEntryIndex[noteIndex] else {
                continue
            }

            for tuplet in noteEvents[noteIndex].tuplets {
                let numberKey = NumberKey(number: tuplet.number)
                let markerKey = MarkerOccurrenceKey(
                    entryIndex: entryIndex,
                    number: tuplet.number,
                    beamValue: nil,
                    spanType: tuplet.type
                )
                if processed.contains(markerKey) {
                    continue
                }
                processed.insert(markerKey)

                switch tuplet.type {
                case .start:
                    openByNumber[numberKey] = entryIndex
                case .continue:
                    if openByNumber[numberKey] == nil {
                        openByNumber[numberKey] = entryIndex
                    }
                case .stop:
                    if let start = openByNumber.removeValue(forKey: numberKey),
                       start != entryIndex {
                        let key = SpanKey(number: tuplet.number, start: min(start, entryIndex), end: max(start, entryIndex))
                        if !seen.contains(key) {
                            seen.insert(key)
                            spans.append(
                                VoiceTupletSpan(number: tuplet.number, startEntryIndex: key.start, endEntryIndex: key.end)
                            )
                        }
                    }
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
            return staffSortValue(lhs.number) < staffSortValue(rhs.number)
        }
    }

    private func staffSortValue(_ value: Int?) -> Int {
        value ?? Int.min
    }
}
