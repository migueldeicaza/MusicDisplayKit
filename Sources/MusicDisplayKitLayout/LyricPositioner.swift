import Foundation
import MusicDisplayKitCore
import MusicDisplayKitModel

/// Positions lyrics below the staff using the bottomline profile.
/// Lyrics are grouped by verse number, with verse 1 closest to the staff
/// and subsequent verses stacked below.
public struct LyricPositioner: Sendable {
    public init() {}

    /// Positions all lyrics in the graphical score.
    public func positionLyrics(
        _ graphicalScore: GraphicalScore,
        score: Score,
        rules: EngravingRules = .default
    ) {
        let skylineCalculator = SkylineCalculator()

        for system in graphicalScore.systems {
            guard let bottomline = system.bottomlineProfile else { continue }

            // Collect all verse numbers across this system's measures.
            var verseNumbers: Set<Int> = []
            for measure in system.measures {
                guard measure.partIndex < score.parts.count,
                      measure.measureIndex < score.parts[measure.partIndex].measures.count
                else { continue }

                let sourceMeasure = score.parts[measure.partIndex].measures[measure.measureIndex]
                for note in sourceMeasure.noteEvents {
                    for lyric in note.lyrics {
                        verseNumbers.insert(lyric.number)
                    }
                }
            }

            let sortedVerses = verseNumbers.sorted()

            // Position each verse line.
            for (verseIndex, _) in sortedVerses.enumerated() {
                let verseOffsetY = Double(verseIndex) * rules.lyricVerseSpacing

                // For each measure, place lyrics at the bottomline + verse offset.
                for measure in system.measures {
                    guard measure.partIndex < score.parts.count,
                          measure.measureIndex < score.parts[measure.partIndex].measures.count
                    else { continue }

                    for entry in measure.staffEntries {
                        for note in entry.notes {
                            for lyric in note.sourceNoteEvent.lyrics {
                                guard lyric.text != nil else { continue }

                                let estimatedWidth = Double(lyric.text?.count ?? 3) * rules.lyricFontSize * 0.6
                                let x = entry.absoluteX > 0 ? entry.absoluteX : measure.frame.x

                                let box = MDKBoundingBox(
                                    x: x - estimatedWidth / 2,
                                    y: 0,
                                    width: estimatedWidth,
                                    height: rules.lyricFontSize
                                )

                                let baseY = skylineCalculator.placeBelowStaff(
                                    box: box,
                                    bottomline: bottomline,
                                    padding: rules.belowStaffPadding
                                )
                                _ = baseY + verseOffsetY // Final Y position
                            }
                        }
                    }
                }
            }
        }
    }
}
