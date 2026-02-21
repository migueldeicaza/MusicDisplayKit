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
        var number: Int
    }

    private struct NotePosition {
        var measureIndex: Int
        var measureNumber: Int
        var noteIndex: Int
        var onsetDivisions: Int
    }

    private struct OpenSlur {
        var key: SlurKey
        var rawNumber: Int?
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
                        let key = SlurKey(
                            voice: note.voice,
                            staff: note.staff,
                            number: normalizedSlurNumber(marker.number)
                        )
                        switch marker.type {
                        case .start:
                            if let existing = openByKey.removeValue(forKey: key) {
                                output.append(
                                    buildEvent(
                                        partIndex: partIndex,
                                        partID: part.id,
                                        openSlur: existing,
                                        endPosition: existing.start,
                                        endNumber: nil,
                                        endPlacement: marker.placement,
                                        isOpenEnded: true
                                    )
                                )
                            }
                            openByKey[key] = OpenSlur(
                                key: key,
                                rawNumber: marker.number,
                                start: notePosition,
                                placement: marker.placement
                            )

                        case .stop:
                            let resolvedKey = resolveStopKey(
                                requestedKey: key,
                                requestedRawNumber: marker.number,
                                openByKey: openByKey
                            )
                            guard let resolvedKey,
                                  let open = openByKey.removeValue(forKey: resolvedKey) else {
                                continue
                            }
                            output.append(
                                buildEvent(
                                    partIndex: partIndex,
                                    partID: part.id,
                                    openSlur: open,
                                    endPosition: notePosition,
                                    endNumber: marker.number,
                                    endPlacement: marker.placement,
                                    isOpenEnded: false
                                )
                            )

                        case .`continue`:
                            let resolvedKey = resolveStopKey(
                                requestedKey: key,
                                requestedRawNumber: marker.number,
                                openByKey: openByKey
                            )
                            if let resolvedKey,
                               let open = openByKey.removeValue(forKey: resolvedKey) {
                                output.append(
                                    buildEvent(
                                        partIndex: partIndex,
                                        partID: part.id,
                                        openSlur: open,
                                        endPosition: notePosition,
                                        endNumber: marker.number,
                                        endPlacement: marker.placement,
                                        isOpenEnded: false
                                    )
                                )
                                let continuationRawNumber = marker.number ?? open.rawNumber
                                let continuationKey = SlurKey(
                                    voice: note.voice,
                                    staff: note.staff,
                                    number: normalizedSlurNumber(continuationRawNumber)
                                )
                                openByKey[continuationKey] = OpenSlur(
                                    key: continuationKey,
                                    rawNumber: continuationRawNumber,
                                    start: notePosition,
                                    placement: marker.placement ?? open.placement
                                )
                            } else {
                                openByKey[key] = OpenSlur(
                                    key: key,
                                    rawNumber: marker.number,
                                    start: notePosition,
                                    placement: marker.placement
                                )
                            }

                        case .unknown:
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
                        endNumber: nil,
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
        endNumber: Int?,
        endPlacement: String?,
        isOpenEnded: Bool
    ) -> SlurEvent {
        SlurEvent(
            partIndex: partIndex,
            partID: partID,
            voice: openSlur.key.voice,
            staff: openSlur.key.staff,
            number: openSlur.rawNumber ?? endNumber,
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

    private func resolveStopKey(
        requestedKey: SlurKey,
        requestedRawNumber: Int?,
        openByKey: [SlurKey: OpenSlur]
    ) -> SlurKey? {
        if openByKey[requestedKey] != nil {
            return requestedKey
        }

        // Robustness fallback for malformed input:
        // if stop/continue omits a number and no implicit "1" match exists,
        // close the most recent open slur in the same voice/staff.
        if requestedRawNumber == nil {
            let sameVoiceCandidates = openByKey.filter { candidate in
                candidate.key.voice == requestedKey.voice
            }
            if let match = mostRecentKey(
                from: sameVoiceCandidates,
                preferredStaff: requestedKey.staff
            ) {
                return match
            }
        }

        // Cross-staff fallback: if a numbered slur stop changes staff,
        // allow closing the most recent matching voice+number open slur.
        let candidates = openByKey
            .filter { candidate in
                candidate.key.voice == requestedKey.voice &&
                candidate.key.number == requestedKey.number
            }

        return mostRecentKey(from: candidates, preferredStaff: requestedKey.staff)
    }

    private func mostRecentKey(
        from candidates: [SlurKey: OpenSlur],
        preferredStaff: Int?
    ) -> SlurKey? {
        guard !candidates.isEmpty else {
            return nil
        }
        let preferredCandidates = candidates.filter { candidate in
            candidate.key.staff == preferredStaff
        }
        let prioritized = preferredCandidates.isEmpty ? candidates : preferredCandidates
        return prioritized.max(by: { lhs, rhs in
            if lhs.value.start.measureIndex != rhs.value.start.measureIndex {
                return lhs.value.start.measureIndex < rhs.value.start.measureIndex
            }
            if lhs.value.start.onsetDivisions != rhs.value.start.onsetDivisions {
                return lhs.value.start.onsetDivisions < rhs.value.start.onsetDivisions
            }
            if lhs.value.start.noteIndex != rhs.value.start.noteIndex {
                return lhs.value.start.noteIndex < rhs.value.start.noteIndex
            }
            return staffSortValue(lhs.key.staff) < staffSortValue(rhs.key.staff)
        })?.key
    }

    private func normalizedSlurNumber(_ raw: Int?) -> Int {
        raw ?? 1
    }
}
