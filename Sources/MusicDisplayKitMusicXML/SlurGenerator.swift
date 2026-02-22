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
        var sequence: Int
    }

    public init() {}

    public func generate(from score: Score) -> [SlurEvent] {
        var output: [SlurEvent] = []

        for (partIndex, part) in score.parts.enumerated() {
            var openByKey: [SlurKey: [OpenSlur]] = [:]
            var nextOpenSequence: Int = 0

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
                            openByKey[key, default: []].append(OpenSlur(
                                key: key,
                                rawNumber: marker.number,
                                start: notePosition,
                                placement: marker.placement,
                                sequence: nextOpenSequence
                            ))
                            nextOpenSequence += 1

                        case .stop:
                            let resolvedKey = resolveStopKey(
                                requestedKey: key,
                                requestedRawNumber: marker.number,
                                openByKey: openByKey
                            )
                            guard let resolvedKey,
                                  var stack = openByKey[resolvedKey],
                                  let open = stack.popLast() else {
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
                            if stack.isEmpty {
                                openByKey.removeValue(forKey: resolvedKey)
                            } else {
                                openByKey[resolvedKey] = stack
                            }

                        case .`continue`:
                            let resolvedKey = resolveStopKey(
                                requestedKey: key,
                                requestedRawNumber: marker.number,
                                openByKey: openByKey
                            )
                            if let resolvedKey,
                               var stack = openByKey[resolvedKey],
                               let open = stack.popLast() {
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
                                if stack.isEmpty {
                                    openByKey.removeValue(forKey: resolvedKey)
                                } else {
                                    openByKey[resolvedKey] = stack
                                }
                                let continuationRawNumber = marker.number ?? open.rawNumber
                                let continuationKey = SlurKey(
                                    voice: note.voice,
                                    staff: note.staff,
                                    number: normalizedSlurNumber(continuationRawNumber)
                                )
                                openByKey[continuationKey, default: []].append(OpenSlur(
                                    key: continuationKey,
                                    rawNumber: continuationRawNumber,
                                    start: notePosition,
                                    placement: marker.placement ?? open.placement,
                                    sequence: nextOpenSequence
                                ))
                                nextOpenSequence += 1
                            } else {
                                openByKey[key, default: []].append(OpenSlur(
                                    key: key,
                                    rawNumber: marker.number,
                                    start: notePosition,
                                    placement: marker.placement,
                                    sequence: nextOpenSequence
                                ))
                                nextOpenSequence += 1
                            }

                        case .unknown:
                            continue
                        }
                    }
                }
            }

            for open in openByKey.values.flatMap({ $0 }) {
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
        openByKey: [SlurKey: [OpenSlur]]
    ) -> SlurKey? {
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

        // Cross-staff fallback: if a numbered slur stop changes staff,
        // allow closing the most recent matching voice+number open slur.
        let candidates = openByKey
            .filter { candidate in
                candidate.key.voice == requestedKey.voice &&
                candidate.key.number == requestedKey.number &&
                !candidate.value.isEmpty
            }

        return mostRecentKey(from: candidates, preferredStaff: requestedKey.staff)
    }

    private func mostRecentKey(
        from candidates: [SlurKey: [OpenSlur]],
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
            let lhsSequence = lhs.value.last?.sequence ?? Int.min
            let rhsSequence = rhs.value.last?.sequence ?? Int.min
            if lhsSequence != rhsSequence {
                return lhsSequence < rhsSequence
            }
            let lhsStartMeasure = lhs.value.last?.start.measureIndex ?? Int.min
            let rhsStartMeasure = rhs.value.last?.start.measureIndex ?? Int.min
            if lhsStartMeasure != rhsStartMeasure {
                return lhsStartMeasure < rhsStartMeasure
            }
            let lhsStartOnset = lhs.value.last?.start.onsetDivisions ?? Int.min
            let rhsStartOnset = rhs.value.last?.start.onsetDivisions ?? Int.min
            if lhsStartOnset != rhsStartOnset {
                return lhsStartOnset < rhsStartOnset
            }
            let lhsStartNote = lhs.value.last?.start.noteIndex ?? Int.min
            let rhsStartNote = rhs.value.last?.start.noteIndex ?? Int.min
            if lhsStartNote != rhsStartNote {
                return lhsStartNote < rhsStartNote
            }
            return staffSortValue(lhs.key.staff) < staffSortValue(rhs.key.staff)
        })?.key
    }

    private func normalizedSlurNumber(_ raw: Int?) -> Int {
        raw ?? 1
    }
}
