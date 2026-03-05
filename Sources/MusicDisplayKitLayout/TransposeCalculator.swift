import Foundation
import MusicDisplayKitModel

/// Transposes a `Score` by a given number of chromatic and diatonic steps.
/// Updates all pitches, key signatures, and accidentals accordingly.
public struct TransposeCalculator: Sendable {

    public init() {}

    /// Returns a new `Score` with all pitched notes transposed.
    ///
    /// - Parameters:
    ///   - score: The source score.
    ///   - chromaticSteps: Number of semitones to transpose (positive = up, negative = down).
    ///   - diatonicSteps: Number of diatonic scale steps to transpose.
    /// - Returns: A transposed copy of the score.
    public func transpose(
        score: Score,
        chromaticSteps: Int,
        diatonicSteps: Int
    ) -> Score {
        guard chromaticSteps != 0 || diatonicSteps != 0 else { return score }

        var transposed = score

        for partIndex in transposed.parts.indices {
            for measureIndex in transposed.parts[partIndex].measures.indices {
                // Transpose key signature.
                if var attrs = transposed.parts[partIndex].measures[measureIndex].attributes {
                    if let key = attrs.key {
                        attrs.key = transposeKeySignature(key, chromaticSteps: chromaticSteps)
                    }
                    transposed.parts[partIndex].measures[measureIndex].attributes = attrs
                }

                // Transpose note pitches.
                for noteIndex in transposed.parts[partIndex].measures[measureIndex].noteEvents.indices {
                    var note = transposed.parts[partIndex].measures[measureIndex].noteEvents[noteIndex]
                    if note.kind == .pitched, let pitch = note.pitch {
                        note.pitch = transposePitch(
                            pitch,
                            chromaticSteps: chromaticSteps,
                            diatonicSteps: diatonicSteps
                        )
                        note.accidental = accidentalForPitch(note.pitch!)
                    }
                    transposed.parts[partIndex].measures[measureIndex].noteEvents[noteIndex] = note
                }
            }
        }

        return transposed
    }

    // MARK: - Private

    private static let chromaticScale = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private static let diatonicSteps = ["C", "D", "E", "F", "G", "A", "B"]
    private static let stepToChromatic: [String: Int] = [
        "C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11,
    ]

    private func transposePitch(
        _ pitch: PitchValue,
        chromaticSteps: Int,
        diatonicSteps: Int
    ) -> PitchValue {
        // Convert pitch to absolute chromatic number.
        let baseChromaticInOctave = Self.stepToChromatic[pitch.step] ?? 0
        let absoluteChromatic = pitch.octave * 12 + baseChromaticInOctave + Int(pitch.alter)

        // Apply chromatic transposition.
        let newAbsoluteChromatic = absoluteChromatic + chromaticSteps

        // Apply diatonic transposition to determine the new step name.
        let diatonicIndex = Self.diatonicSteps.firstIndex(of: pitch.step).map { Int($0) } ?? 0
        let newDiatonicIndex = ((diatonicIndex + diatonicSteps) % 7 + 7) % 7
        let newStep = Self.diatonicSteps[newDiatonicIndex]

        // Calculate new octave.
        let diatonicOctaveShift = (diatonicIndex + diatonicSteps) >= 0
            ? (diatonicIndex + diatonicSteps) / 7
            : ((diatonicIndex + diatonicSteps) - 6) / 7
        let newOctave = pitch.octave + diatonicOctaveShift

        // Calculate alter (difference between chromatic position and natural step).
        let newStepChromatic = newOctave * 12 + (Self.stepToChromatic[newStep] ?? 0)
        let newAlter = Double(newAbsoluteChromatic - newStepChromatic)

        return PitchValue(step: newStep, alter: newAlter, octave: newOctave)
    }

    private func transposeKeySignature(
        _ key: KeySignature,
        chromaticSteps: Int
    ) -> KeySignature {
        // Each fifth adds 7 semitones; invert to find fifths change.
        // Simplified: chromatic steps mod 12, mapped to circle of fifths.
        let circleOfFifths = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]
        let currentFifthsIndex = circleOfFifths.firstIndex(of: ((key.fifths * 7 % 12) + 12) % 12) ?? 0
        let transposedChromatic = (currentFifthsIndex * 7 + chromaticSteps) % 12
        let normalizedChromatic = (transposedChromatic % 12 + 12) % 12

        // Find the fifths value closest to the transposed chromatic position.
        if let newIndex = circleOfFifths.firstIndex(of: normalizedChromatic) {
            let newFifths = newIndex <= 6 ? newIndex : newIndex - 12
            return KeySignature(fifths: newFifths, mode: key.mode)
        }

        return key
    }

    private func accidentalForPitch(_ pitch: PitchValue) -> AccidentalValue? {
        switch pitch.alter {
        case 1: return .sharp
        case -1: return .flat
        case 2: return .doubleSharp
        case -2: return .doubleFlat
        case 0: return nil
        default: return pitch.alter > 0 ? .sharp : .flat
        }
    }
}
