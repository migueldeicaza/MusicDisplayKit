import MusicDisplayKitCore
import MusicDisplayKitLayout

/// Hit-testing support for click/tap interaction with rendered scores.
public struct ScoreHitTester: Sendable {
    public init() {}

    /// Returns the `GraphicalNote` at the given point, or `nil` if no note is hit.
    ///
    /// Search order: system Y range → measure X range → note bounding box.
    public func noteAt(point: MDKPoint, in graphicalScore: GraphicalScore) -> GraphicalNote? {
        // Find the system containing this Y coordinate.
        for system in graphicalScore.systems {
            guard system.frame.contains(point: point) else { continue }

            // Search measures within this system.
            for measure in system.measures {
                guard measure.frame.contains(point: point) else { continue }

                // Search notes within this measure.
                for entry in measure.staffEntries {
                    for note in entry.notes {
                        if note.boundingBox.contains(point: point) {
                            return note
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Returns all `GraphicalNote`s whose bounding boxes contain the given point.
    public func notesAt(point: MDKPoint, in graphicalScore: GraphicalScore) -> [GraphicalNote] {
        var results: [GraphicalNote] = []
        for system in graphicalScore.systems {
            guard system.frame.contains(point: point) else { continue }
            for measure in system.measures {
                guard measure.frame.contains(point: point) else { continue }
                for entry in measure.staffEntries {
                    for note in entry.notes {
                        if note.boundingBox.contains(point: point) {
                            results.append(note)
                        }
                    }
                }
            }
        }
        return results
    }

    /// Returns the `GraphicalMeasure` at the given point, or `nil` if none is hit.
    public func measureAt(point: MDKPoint, in graphicalScore: GraphicalScore) -> GraphicalMeasure? {
        for system in graphicalScore.systems {
            guard system.frame.contains(point: point) else { continue }
            for measure in system.measures {
                if measure.frame.contains(point: point) {
                    return measure
                }
            }
        }
        return nil
    }
}
