import Foundation
import MusicDisplayKitCore
import MusicDisplayKitModel

/// Orchestrates multi-pass layout calculations by calling sub-calculators
/// in the correct order. This is the central coordinator for the graphical
/// model population, note positioning, collision avoidance, and element placement.
public struct ScoreCalculator: Sendable {

    private let skylineCalculator = SkylineCalculator()
    private let accidentalCalculator = AccidentalCalculator()
    private let expressionPositioner = ExpressionPositioner()
    private let lyricPositioner = LyricPositioner()
    private let chordSymbolPositioner = ChordSymbolPositioner()

    public init() {}

    /// Runs the full calculation pipeline on a graphical score.
    ///
    /// Call sequence:
    /// 1. Populate graphical model from score + layout data
    /// 2. Apply note positions (from VexFoundation post-format)
    /// 3. Calculate accidental placement
    /// 4. Initialize skyline/bottomline from note bounding boxes
    /// 5. Position expressions/dynamics via skyline
    /// 6. Position lyrics via bottomline
    /// 7. Position chord symbols via skyline
    public func calculate(
        graphicalScore: GraphicalScore,
        score: Score,
        rules: EngravingRules = .default,
        notePositions: [NotePositionKey: NotePositionData] = [:]
    ) {
        // Step 2: Apply note positions from VexFoundation.
        applyNotePositions(graphicalScore, positions: notePositions)

        // Step 3: Accidental collision avoidance.
        accidentalCalculator.calculate(graphicalScore, rules: rules)

        // Steps 4-7: Skyline-based element positioning.
        for system in graphicalScore.systems {
            let startX = system.frame.x
            let endX = system.frame.maxX
            let staffTopY = system.frame.y
            let staffBottomY = system.frame.maxY

            let skyline = skylineCalculator.makeSkylineProfile(
                startX: startX,
                endX: endX,
                staffTopY: staffTopY,
                resolution: rules.skylineResolution
            )
            let bottomline = skylineCalculator.makeBottomlineProfile(
                startX: startX,
                endX: endX,
                staffBottomY: staffBottomY,
                resolution: rules.skylineResolution
            )

            // Insert note bounding boxes.
            let noteBoxes = system.measures.flatMap { measure in
                measure.staffEntries.flatMap { entry in
                    entry.notes.map(\.boundingBox)
                }
            }
            skylineCalculator.insertNoteBoundingBoxes(noteBoxes, skyline: skyline, bottomline: bottomline)

            system.skylineProfile = skyline
            system.bottomlineProfile = bottomline
        }

        // Step 5: Position expressions/dynamics.
        expressionPositioner.positionExpressions(graphicalScore, score: score, rules: rules)

        // Step 6: Position lyrics.
        lyricPositioner.positionLyrics(graphicalScore, score: score, rules: rules)

        // Step 7: Position chord symbols.
        chordSymbolPositioner.positionChordSymbols(graphicalScore, score: score, rules: rules)
    }

    /// Populates a `GraphicalScore` from layout data without note positions.
    public func populateGraphicalModel(
        score: Score,
        laidOutScore: LaidOutScore
    ) -> GraphicalScore {
        let graphicalScore = GraphicalScore()

        // Group measures by system index.
        var measuresBySystem: [Int: [LaidOutMeasure]] = [:]
        for measure in laidOutScore.measures {
            measuresBySystem[measure.systemIndex, default: []].append(measure)
        }

        // Build graphical systems from laid-out systems.
        // Group LaidOutSystems by systemIndex to create one GraphicalSystem per row.
        var systemsByRow: [Int: [LaidOutSystem]] = [:]
        for system in laidOutScore.systems {
            systemsByRow[system.systemIndex, default: []].append(system)
        }

        // Each unique systemIndex in LaidOutSystem maps to one GraphicalSystem.
        let uniqueSystemIndices = Set(laidOutScore.systems.map(\.systemIndex)).sorted()
        for systemIndex in uniqueSystemIndices {
            guard let systems = systemsByRow[systemIndex],
                  let firstSystem = systems.first else { continue }

            // Merge frames across parts for this row.
            var frame = MDKBoundingBox(
                x: firstSystem.frame.x,
                y: firstSystem.frame.y,
                width: firstSystem.frame.width,
                height: firstSystem.frame.height
            )
            for sys in systems.dropFirst() {
                let sysBox = MDKBoundingBox(
                    x: sys.frame.x, y: sys.frame.y,
                    width: sys.frame.width, height: sys.frame.height
                )
                frame.mergeWith(sysBox)
            }

            let gSystem = GraphicalSystem(
                systemIndex: systemIndex,
                pageIndex: firstSystem.pageIndex,
                frame: frame
            )

            // Add measures.
            let measuresInSystem = measuresBySystem[systemIndex] ?? []
            for lm in measuresInSystem {
                let gMeasure = GraphicalMeasure(
                    partIndex: lm.partIndex,
                    measureIndex: lm.measureIndexInPart,
                    frame: MDKBoundingBox(
                        x: lm.frame.x, y: lm.frame.y,
                        width: lm.frame.width, height: lm.frame.height
                    )
                )

                // Populate staff entries from source score.
                if lm.partIndex < score.parts.count,
                   lm.measureIndexInPart < score.parts[lm.partIndex].measures.count {
                    let sourceMeasure = score.parts[lm.partIndex].measures[lm.measureIndexInPart]
                    let entries = buildStaffEntries(from: sourceMeasure, noteIndexBase: 0)
                    gMeasure.staffEntries = entries
                }

                gSystem.measures.append(gMeasure)
            }

            graphicalScore.systems.append(gSystem)
        }

        return graphicalScore
    }

    // MARK: - Private

    private func applyNotePositions(
        _ graphicalScore: GraphicalScore,
        positions: [NotePositionKey: NotePositionData]
    ) {
        for system in graphicalScore.systems {
            for measure in system.measures {
                for entry in measure.staffEntries {
                    for note in entry.notes {
                        let key = NotePositionKey(
                            partIndex: measure.partIndex,
                            measureIndex: measure.measureIndex,
                            noteIndex: note.sourceNoteIndex
                        )
                        if let posData = positions[key] {
                            note.position = posData.position
                            note.boundingBox = posData.boundingBox
                            entry.absoluteX = posData.position.x
                        }
                    }
                }
            }
        }
    }

    private func buildStaffEntries(
        from measure: Measure,
        noteIndexBase: Int
    ) -> [GraphicalStaffEntry] {
        // Group notes by (voice, onsetDivisions).
        var grouped: [Int: [Int: [Int]]] = [:] // voice -> onset -> [noteIndex]
        for (i, note) in measure.noteEvents.enumerated() {
            grouped[note.voice, default: [:]][note.onsetDivisions, default: []].append(i)
        }

        var entries: [GraphicalStaffEntry] = []
        for voice in grouped.keys.sorted() {
            let onsets = grouped[voice] ?? [:]
            for onset in onsets.keys.sorted() {
                let noteIndices = onsets[onset] ?? []
                let entry = GraphicalStaffEntry(onsetDivisions: onset, voice: voice)
                for noteIndex in noteIndices {
                    let noteEvent = measure.noteEvents[noteIndex]
                    let gNote = GraphicalNote(
                        sourceNoteEvent: noteEvent,
                        sourceNoteIndex: noteIndexBase + noteIndex
                    )
                    entry.notes.append(gNote)
                }
                entries.append(entry)
            }
        }

        return entries
    }
}

/// Key for looking up note positions extracted from VexFoundation post-format.
public struct NotePositionKey: Hashable, Sendable {
    public let partIndex: Int
    public let measureIndex: Int
    public let noteIndex: Int

    public init(partIndex: Int, measureIndex: Int, noteIndex: Int) {
        self.partIndex = partIndex
        self.measureIndex = measureIndex
        self.noteIndex = noteIndex
    }
}

/// Position and bounding box data for a single note.
public struct NotePositionData: Sendable {
    public let position: MDKPoint
    public let boundingBox: MDKBoundingBox

    public init(position: MDKPoint, boundingBox: MDKBoundingBox) {
        self.position = position
        self.boundingBox = boundingBox
    }
}
