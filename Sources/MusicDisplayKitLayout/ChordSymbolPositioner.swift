import Foundation
import MusicDisplayKitCore
import MusicDisplayKitModel

/// Positions chord symbols (harmony events) above the staff using the
/// skyline collision avoidance system.
public struct ChordSymbolPositioner: Sendable {
    public init() {}

    /// Positions all chord symbols in the graphical score.
    public func positionChordSymbols(
        _ graphicalScore: GraphicalScore,
        score: Score,
        rules: EngravingRules = .default
    ) {
        let skylineCalculator = SkylineCalculator()

        for system in graphicalScore.systems {
            guard let skyline = system.skylineProfile else { continue }

            for measure in system.measures {
                guard measure.partIndex < score.parts.count,
                      measure.measureIndex < score.parts[measure.partIndex].measures.count
                else { continue }

                let sourceMeasure = score.parts[measure.partIndex].measures[measure.measureIndex]

                for harmony in sourceMeasure.harmonyEvents {
                    let chordText = harmony.rootStep ?? "?"
                    let estimatedWidth = Double(chordText.count + 2) * rules.chordSymbolFontSize * 0.65

                    let x = estimateXForOnset(
                        harmony.onsetDivisions,
                        in: measure
                    )

                    let box = MDKBoundingBox(
                        x: x,
                        y: 0,
                        width: estimatedWidth,
                        height: rules.chordSymbolFontSize
                    )

                    _ = skylineCalculator.placeAboveStaff(
                        box: box,
                        skyline: skyline,
                        padding: rules.aboveStaffPadding
                    )
                }
            }
        }
    }

    private func estimateXForOnset(_ onset: Int, in measure: GraphicalMeasure) -> Double {
        guard !measure.staffEntries.isEmpty else { return measure.frame.x }

        let maxOnset = measure.staffEntries.map(\.onsetDivisions).max() ?? 1
        guard maxOnset > 0 else { return measure.frame.x }

        let fraction = Double(onset) / Double(maxOnset)
        return measure.frame.x + fraction * measure.frame.width * 0.9
    }
}
