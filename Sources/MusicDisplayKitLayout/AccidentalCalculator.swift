import Foundation
import MusicDisplayKitCore
import MusicDisplayKitModel

/// Calculates accidental placement (X offsets) to avoid collisions in chords
/// and manages courtesy accidentals based on key signature context.
public struct AccidentalCalculator: Sendable {
    public init() {}

    /// Assigns `accidentalXOffset` to each `GraphicalNote` within a staff entry
    /// when multiple accidentals would collide.
    ///
    /// Algorithm: sort notes top-to-bottom by pitch, assign accidentals
    /// right-to-left. If an accidental overlaps a previously placed accidental
    /// or notehead, shift it left by `accidentalWidth`.
    public func calculate(_ score: GraphicalScore, rules: EngravingRules = .default) {
        let accidentalWidth = 10.0
        let padding = rules.accidentalPadding

        for system in score.systems {
            for measure in system.measures {
                for entry in measure.staffEntries {
                    let accidentalNotes = entry.notes.filter {
                        $0.sourceNoteEvent.accidental != nil
                    }
                    guard accidentalNotes.count > 1 else { continue }

                    // Sort by pitch descending (top to bottom in staff space).
                    let sorted = accidentalNotes.sorted { a, b in
                        let pitchA = pitchOrdinal(a.sourceNoteEvent.pitch)
                        let pitchB = pitchOrdinal(b.sourceNoteEvent.pitch)
                        return pitchA > pitchB
                    }

                    var occupiedColumns: [(y: Double, xOffset: Double)] = []

                    for note in sorted {
                        let noteY = note.position.y
                        var xOffset = 0.0

                        // Check against already-placed accidentals.
                        for occupied in occupiedColumns {
                            let verticalDistance = abs(noteY - occupied.y)
                            if verticalDistance < accidentalWidth
                                && abs(xOffset - occupied.xOffset) < accidentalWidth + padding {
                                xOffset = occupied.xOffset - accidentalWidth - padding
                            }
                        }

                        note.accidentalXOffset = xOffset
                        occupiedColumns.append((y: noteY, xOffset: xOffset))
                    }
                }
            }
        }
    }

    /// Marks courtesy accidentals: when a pitch previously altered within the
    /// measure returns to its key-signature value, restate the accidental.
    public func markCourtesyAccidentals(
        _ score: GraphicalScore,
        keySignature: KeySignature
    ) {
        // Track which pitches have been altered in the current measure.
        for system in score.systems {
            for measure in system.measures {
                var alteredPitches: [String: Double] = [:]
                let keySigAlterations = keySignatureAlterations(keySignature)

                for entry in measure.staffEntries {
                    for note in entry.notes {
                        guard let pitch = note.sourceNoteEvent.pitch else { continue }
                        let pitchKey = "\(pitch.step)\(pitch.octave)"
                        let keySigAlter = keySigAlterations[pitch.step] ?? 0

                        if let previousAlter = alteredPitches[pitchKey],
                           previousAlter != pitch.alter,
                           pitch.alter == keySigAlter,
                           note.sourceNoteEvent.accidental == nil {
                            // This pitch was previously altered and now returns
                            // to key-signature state — mark courtesy accidental.
                            note.sourceNoteEvent.accidental = accidentalForAlter(keySigAlter)
                        }

                        alteredPitches[pitchKey] = pitch.alter
                    }
                }
            }
        }
    }

    private func pitchOrdinal(_ pitch: PitchValue?) -> Int {
        guard let p = pitch else { return 0 }
        let stepValues: [String: Int] = ["C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6]
        return (p.octave * 7) + (stepValues[p.step] ?? 0)
    }

    private func keySignatureAlterations(_ keySig: KeySignature) -> [String: Double] {
        let sharpOrder = ["F", "C", "G", "D", "A", "E", "B"]
        let flatOrder = ["B", "E", "A", "D", "G", "C", "F"]
        var alterations: [String: Double] = [:]

        if keySig.fifths > 0 {
            for i in 0..<min(keySig.fifths, sharpOrder.count) {
                alterations[sharpOrder[i]] = 1
            }
        } else if keySig.fifths < 0 {
            for i in 0..<min(abs(keySig.fifths), flatOrder.count) {
                alterations[flatOrder[i]] = -1
            }
        }

        return alterations
    }

    private func accidentalForAlter(_ alter: Double) -> AccidentalValue {
        switch alter {
        case 1: return .sharp
        case -1: return .flat
        case 2: return .doubleSharp
        case -2: return .doubleFlat
        default: return .natural
        }
    }
}
