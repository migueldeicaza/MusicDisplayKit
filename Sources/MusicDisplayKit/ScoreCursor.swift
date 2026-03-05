import MusicDisplayKitCore
import MusicDisplayKitLayout
import MusicDisplayKitModel

/// A cursor that tracks a position within a score and provides navigation.
public struct ScoreCursor: Sendable, Equatable {
    public var partIndex: Int
    public var measureIndex: Int
    public var voiceIndex: Int
    public var noteIndex: Int

    public init(partIndex: Int = 0, measureIndex: Int = 0, voiceIndex: Int = 0, noteIndex: Int = 0) {
        self.partIndex = partIndex
        self.measureIndex = measureIndex
        self.voiceIndex = voiceIndex
        self.noteIndex = noteIndex
    }

    /// Advances the cursor to the next note event.
    /// Returns `true` if the cursor was successfully advanced, `false` if at end.
    @discardableResult
    public mutating func advance(in score: Score) -> Bool {
        guard partIndex < score.parts.count else { return false }
        let part = score.parts[partIndex]
        guard measureIndex < part.measures.count else { return false }

        let measure = part.measures[measureIndex]
        let voiceNotes = notesInVoice(measure: measure)

        // Try to advance within the current voice.
        if noteIndex + 1 < voiceNotes.count {
            noteIndex += 1
            return true
        }

        // Try the next voice in this measure.
        let voices = availableVoices(in: measure)
        if let currentVoicePos = voices.firstIndex(of: voiceIndex), currentVoicePos + 1 < voices.count {
            voiceIndex = voices[currentVoicePos + 1]
            noteIndex = 0
            return true
        }

        // Move to the next measure.
        if measureIndex + 1 < part.measures.count {
            measureIndex += 1
            voiceIndex = availableVoices(in: part.measures[measureIndex]).first ?? 0
            noteIndex = 0
            return true
        }

        return false
    }

    /// Retreats the cursor to the previous note event.
    /// Returns `true` if the cursor was successfully retreated, `false` if at start.
    @discardableResult
    public mutating func retreat(in score: Score) -> Bool {
        guard partIndex < score.parts.count else { return false }
        let part = score.parts[partIndex]

        // Try to retreat within the current voice.
        if noteIndex > 0 {
            noteIndex -= 1
            return true
        }

        // Try the previous voice in this measure.
        guard measureIndex < part.measures.count else { return false }
        let measure = part.measures[measureIndex]
        let voices = availableVoices(in: measure)
        if let currentVoicePos = voices.firstIndex(of: voiceIndex), currentVoicePos > 0 {
            voiceIndex = voices[currentVoicePos - 1]
            let prevVoiceNotes = measure.noteEvents.filter { $0.voice == voiceIndex + 1 }
            noteIndex = max(0, prevVoiceNotes.count - 1)
            return true
        }

        // Move to the previous measure.
        if measureIndex > 0 {
            measureIndex -= 1
            let prevMeasure = part.measures[measureIndex]
            let prevVoices = availableVoices(in: prevMeasure)
            voiceIndex = prevVoices.last ?? 0
            let prevNotes = prevMeasure.noteEvents.filter { $0.voice == voiceIndex + 1 }
            noteIndex = max(0, prevNotes.count - 1)
            return true
        }

        return false
    }

    /// Returns the note events at the current cursor position.
    public func currentNotes(in score: Score) -> [NoteEvent] {
        guard partIndex < score.parts.count else { return [] }
        let part = score.parts[partIndex]
        guard measureIndex < part.measures.count else { return [] }

        let voiceNotes = notesInVoice(measure: part.measures[measureIndex])
        guard noteIndex < voiceNotes.count else { return [] }

        let targetNote = voiceNotes[noteIndex]
        // Return all notes at the same onset (chord).
        return voiceNotes.filter { $0.onsetDivisions == targetNote.onsetDivisions }
    }

    /// Returns the graphical position for the current cursor location.
    public func graphicalPosition(in graphicalScore: GraphicalScore) -> MDKPoint? {
        for system in graphicalScore.systems {
            for measure in system.measures {
                guard measure.partIndex == partIndex,
                      measure.measureIndex == measureIndex else { continue }
                for entry in measure.staffEntries {
                    guard entry.voice == voiceIndex + 1 else { continue }
                    for note in entry.notes where note.sourceNoteIndex == noteIndex {
                        return note.position
                    }
                }
            }
        }
        return nil
    }

    /// Returns the bounding box at the current cursor position.
    public func boundingBox(in graphicalScore: GraphicalScore) -> MDKBoundingBox? {
        for system in graphicalScore.systems {
            for measure in system.measures {
                guard measure.partIndex == partIndex,
                      measure.measureIndex == measureIndex else { continue }
                for entry in measure.staffEntries {
                    guard entry.voice == voiceIndex + 1 else { continue }
                    for note in entry.notes where note.sourceNoteIndex == noteIndex {
                        return note.boundingBox
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Private

    private func notesInVoice(measure: Measure) -> [NoteEvent] {
        measure.noteEvents
            .filter { $0.voice == voiceIndex + 1 }
            .sorted { $0.onsetDivisions < $1.onsetDivisions }
    }

    private func availableVoices(in measure: Measure) -> [Int] {
        Array(Set(measure.noteEvents.map { $0.voice - 1 })).sorted()
    }
}
