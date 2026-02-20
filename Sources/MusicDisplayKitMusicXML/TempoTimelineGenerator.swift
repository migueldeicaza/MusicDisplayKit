import MusicDisplayKitCore
import MusicDisplayKitModel

public struct TempoTimelineEvent: Equatable, Sendable {
    public var partIndex: Int
    public var partID: String
    public var measureIndex: Int
    public var measureNumber: Int
    public var onsetDivisions: Int
    public var bpm: Double
    public var source: TempoEventSource
    public var absolutePosition: MDKFraction

    public init(
        partIndex: Int,
        partID: String,
        measureIndex: Int,
        measureNumber: Int,
        onsetDivisions: Int,
        bpm: Double,
        source: TempoEventSource,
        absolutePosition: MDKFraction
    ) {
        self.partIndex = partIndex
        self.partID = partID
        self.measureIndex = measureIndex
        self.measureNumber = measureNumber
        self.onsetDivisions = onsetDivisions
        self.bpm = bpm
        self.source = source
        self.absolutePosition = absolutePosition
    }
}

public struct TempoTimelineGenerator: Sendable {
    public init() {}

    public func generate(from score: Score) -> [TempoTimelineEvent] {
        var output: [TempoTimelineEvent] = []

        for (partIndex, part) in score.parts.enumerated() {
            var cumulativePosition = MDKFraction(0, 1)
            var effectiveDivisions = 4
            var effectiveTimeSignature: TimeSignature?

            for (measureIndex, measure) in part.measures.enumerated() {
                if let divisions = measure.divisions, divisions > 0 {
                    effectiveDivisions = divisions
                }
                if let time = measure.attributes?.time {
                    effectiveTimeSignature = time
                }

                let divisionsPerWholeNote = max(1, effectiveDivisions * 4)
                let events = measure.tempoEvents.sorted(by: compareTempoEvents)
                for event in events {
                    let onset = max(0, event.onsetDivisions)
                    let absolute = cumulativePosition + MDKFraction(onset, divisionsPerWholeNote)
                    output.append(
                        TempoTimelineEvent(
                            partIndex: partIndex,
                            partID: part.id,
                            measureIndex: measureIndex,
                            measureNumber: measure.number,
                            onsetDivisions: onset,
                            bpm: event.bpm,
                            source: event.source,
                            absolutePosition: absolute
                        )
                    )
                }

                let measureDuration = measureDurationWholeNotes(
                    measure: measure,
                    effectiveDivisions: effectiveDivisions,
                    effectiveTimeSignature: effectiveTimeSignature
                )
                cumulativePosition = cumulativePosition + measureDuration
            }
        }

        return output.sorted { lhs, rhs in
            if lhs.partIndex != rhs.partIndex {
                return lhs.partIndex < rhs.partIndex
            }
            if lhs.absolutePosition != rhs.absolutePosition {
                return lhs.absolutePosition.asDouble < rhs.absolutePosition.asDouble
            }
            return tempoSourceRank(lhs.source) < tempoSourceRank(rhs.source)
        }
    }

    private func compareTempoEvents(lhs: TempoEvent, rhs: TempoEvent) -> Bool {
        if lhs.onsetDivisions != rhs.onsetDivisions {
            return lhs.onsetDivisions < rhs.onsetDivisions
        }
        return tempoSourceRank(lhs.source) < tempoSourceRank(rhs.source)
    }

    private func tempoSourceRank(_ source: TempoEventSource) -> Int {
        switch source {
        case .carryForward:
            return 0
        case .sound:
            return 1
        case .metronome:
            return 2
        }
    }

    private func measureDurationWholeNotes(
        measure: Measure,
        effectiveDivisions: Int,
        effectiveTimeSignature: TimeSignature?
    ) -> MDKFraction {
        let divisionsPerWholeNote = max(1, effectiveDivisions * 4)
        var expectedByTimeSignature: MDKFraction?
        if let time = effectiveTimeSignature, time.beats > 0, time.beatType > 0 {
            expectedByTimeSignature = MDKFraction(time.beats, time.beatType)
        }

        var maxNoteEnd = 0
        for note in measure.noteEvents {
            let onset = max(0, note.onsetDivisions)
            let duration = max(0, note.durationDivisions ?? 0)
            maxNoteEnd = max(maxNoteEnd, onset + duration)
        }
        let observedByNotes = maxNoteEnd > 0 ? MDKFraction(maxNoteEnd, divisionsPerWholeNote) : nil

        switch (expectedByTimeSignature, observedByNotes) {
        case let (.some(expected), .some(observed)):
            return expected.asDouble >= observed.asDouble ? expected : observed
        case let (.some(expected), .none):
            return expected
        case let (.none, .some(observed)):
            return observed
        case (.none, .none):
            // Fallback keeps timeline monotonic even for empty/under-specified measures.
            return MDKFraction(1, 4)
        }
    }
}
