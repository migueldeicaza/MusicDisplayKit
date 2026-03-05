import Foundation
import MusicDisplayKitCore
import MusicDisplayKitModel

/// Positions expression/dynamic markings (e.g., "pp", "ff", crescendo wedges)
/// using the skyline/bottomline collision avoidance system.
///
/// Dynamics are typically placed below the staff. Wedges (hairpins) span
/// a horizontal range and are assigned a uniform Y across their extent.
public struct ExpressionPositioner: Sendable {
    public init() {}

    /// Positions all expression/dynamic markings in the graphical score.
    public func positionExpressions(
        _ graphicalScore: GraphicalScore,
        score: Score,
        rules: EngravingRules = .default
    ) {
        let skylineCalculator = SkylineCalculator()

        for system in graphicalScore.systems {
            guard let bottomline = system.bottomlineProfile else { continue }

            for measure in system.measures {
                guard measure.partIndex < score.parts.count,
                      measure.measureIndex < score.parts[measure.partIndex].measures.count
                else { continue }

                let sourceMeasure = score.parts[measure.partIndex].measures[measure.measureIndex]

                // Position direction-level dynamics.
                for direction in sourceMeasure.directionEvents {
                    guard !direction.dynamics.isEmpty else { continue }

                    let estimatedWidth = Double(direction.dynamics.joined().count) * rules.dynamicFontSize * 0.6
                    let x = estimateXForOnset(
                        direction.onsetDivisions,
                        in: measure
                    )

                    let box = MDKBoundingBox(
                        x: x,
                        y: 0,
                        width: estimatedWidth,
                        height: rules.dynamicFontSize
                    )

                    _ = skylineCalculator.placeBelowStaff(
                        box: box,
                        bottomline: bottomline,
                        padding: rules.belowStaffPadding
                    )
                }

                // Position wedges: uniform Y across the span.
                for direction in sourceMeasure.directionEvents {
                    for wedge in direction.wedges {
                        guard wedge.type == .crescendo || wedge.type == .diminuendo else { continue }

                        let startX = estimateXForOnset(direction.onsetDivisions, in: measure)
                        let endX = startX + 60 // Default span; refined when stop marker is found

                        let box = MDKBoundingBox(
                            x: startX,
                            y: 0,
                            width: endX - startX,
                            height: 10
                        )

                        _ = skylineCalculator.placeBelowStaff(
                            box: box,
                            bottomline: bottomline,
                            padding: rules.belowStaffPadding
                        )
                    }
                }
            }
        }
    }

    private func estimateXForOnset(_ onset: Int, in measure: GraphicalMeasure) -> Double {
        // Linear interpolation within the measure frame.
        guard !measure.staffEntries.isEmpty else { return measure.frame.x }

        let maxOnset = measure.staffEntries.map(\.onsetDivisions).max() ?? 1
        guard maxOnset > 0 else { return measure.frame.x }

        let fraction = Double(onset) / Double(maxOnset)
        return measure.frame.x + fraction * measure.frame.width * 0.9
    }
}
