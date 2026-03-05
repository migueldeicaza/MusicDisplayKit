import Foundation
import MusicDisplayKitCore
import MusicDisplayKitModel

// MARK: - Graphical Score Model
// Reference-type counterparts for score elements, mutated in-place during multi-pass layout.

/// Top-level graphical representation of a rendered score.
public final class GraphicalScore: @unchecked Sendable {
    public var systems: [GraphicalSystem] = []

    public init() {}
}

/// A system (horizontal row of staves on a page).
public final class GraphicalSystem: @unchecked Sendable {
    public var systemIndex: Int
    public var pageIndex: Int
    public var frame: MDKBoundingBox
    public var measures: [GraphicalMeasure] = []
    public var skylineProfile: SkylineProfile?
    public var bottomlineProfile: SkylineProfile?

    public init(systemIndex: Int, pageIndex: Int, frame: MDKBoundingBox) {
        self.systemIndex = systemIndex
        self.pageIndex = pageIndex
        self.frame = frame
    }
}

/// A measure within a system, associated with a specific part.
public final class GraphicalMeasure: @unchecked Sendable {
    public var partIndex: Int
    public var measureIndex: Int
    public var frame: MDKBoundingBox
    public var staffEntries: [GraphicalStaffEntry] = []

    public init(partIndex: Int, measureIndex: Int, frame: MDKBoundingBox) {
        self.partIndex = partIndex
        self.measureIndex = measureIndex
        self.frame = frame
    }
}

/// A vertical column of notes/rests at a single onset position within a measure.
public final class GraphicalStaffEntry: @unchecked Sendable {
    public var onsetDivisions: Int
    public var voice: Int
    public var relativeX: Double
    public var absoluteX: Double
    public var notes: [GraphicalNote] = []

    public init(onsetDivisions: Int, voice: Int, relativeX: Double = 0, absoluteX: Double = 0) {
        self.onsetDivisions = onsetDivisions
        self.voice = voice
        self.relativeX = relativeX
        self.absoluteX = absoluteX
    }
}

/// A single note within a staff entry, linking back to its source `NoteEvent`.
public final class GraphicalNote: @unchecked Sendable {
    public var sourceNoteEvent: NoteEvent
    public var sourceNoteIndex: Int
    public var position: MDKPoint
    public var boundingBox: MDKBoundingBox
    public var accidentalXOffset: Double?

    public init(
        sourceNoteEvent: NoteEvent,
        sourceNoteIndex: Int,
        position: MDKPoint = MDKPoint(),
        boundingBox: MDKBoundingBox = MDKBoundingBox()
    ) {
        self.sourceNoteEvent = sourceNoteEvent
        self.sourceNoteIndex = sourceNoteIndex
        self.position = position
        self.boundingBox = boundingBox
    }
}

// MARK: - Skyline Profile

/// Array-of-Y-values representing the highest (skyline) or lowest (bottomline) occupied
/// vertical position at uniformly-spaced X intervals across a system.
public final class SkylineProfile: @unchecked Sendable {
    /// The X coordinate where sampling starts.
    public let startX: Double
    /// Distance between samples.
    public let resolution: Double
    /// Sampled Y values. For skyline, each entry is the *minimum* Y (topmost in screen coords).
    /// For bottomline, each entry is the *maximum* Y.
    public private(set) var values: [Double]
    /// Whether this is an above-staff (skyline) or below-staff (bottomline) profile.
    public let isSkyline: Bool

    public init(startX: Double, resolution: Double, count: Int, initialValue: Double, isSkyline: Bool) {
        self.startX = startX
        self.resolution = max(0.5, resolution)
        self.values = Array(repeating: initialValue, count: max(1, count))
        self.isSkyline = isSkyline
    }

    /// Marks a bounding box as occupied, updating the profile accordingly.
    public func insertBoundingBox(_ box: MDKBoundingBox) {
        let startIndex = max(0, Int(floor((box.x - startX) / resolution)))
        let endIndex = min(values.count - 1, Int(ceil((box.maxX - startX) / resolution)))
        guard startIndex <= endIndex else { return }

        if isSkyline {
            // Skyline: track minimum Y (topmost, since Y increases downward)
            for i in startIndex...endIndex {
                values[i] = min(values[i], box.y)
            }
        } else {
            // Bottomline: track maximum Y (bottommost)
            for i in startIndex...endIndex {
                values[i] = max(values[i], box.maxY)
            }
        }
    }

    /// Batch-insert multiple bounding boxes in a single sweep (8.1).
    ///
    /// Sorts by X, then sweeps left-to-right so overlapping ranges
    /// share index computation. More efficient than calling `insertBoundingBox`
    /// one-at-a-time when there are many boxes.
    public func insertBoundingBoxes(_ boxes: [MDKBoundingBox]) {
        guard !boxes.isEmpty else { return }
        if boxes.count == 1 {
            insertBoundingBox(boxes[0])
            return
        }

        // Sort by left edge to enable sequential sweep.
        let sorted = boxes.sorted { $0.x < $1.x }

        if isSkyline {
            for box in sorted {
                let si = max(0, Int(floor((box.x - startX) / resolution)))
                let ei = min(values.count - 1, Int(ceil((box.maxX - startX) / resolution)))
                guard si <= ei else { continue }
                let y = box.y
                for i in si...ei {
                    if y < values[i] { values[i] = y }
                }
            }
        } else {
            for box in sorted {
                let si = max(0, Int(floor((box.x - startX) / resolution)))
                let ei = min(values.count - 1, Int(ceil((box.maxX - startX) / resolution)))
                guard si <= ei else { continue }
                let maxY = box.maxY
                for i in si...ei {
                    if maxY > values[i] { values[i] = maxY }
                }
            }
        }
    }

    /// Queries the skyline (minimum occupied Y) in the given X range.
    public func querySkyline(xStart: Double, xEnd: Double) -> Double {
        let startIndex = max(0, Int(floor((xStart - startX) / resolution)))
        let endIndex = min(values.count - 1, Int(ceil((xEnd - startX) / resolution)))
        guard startIndex <= endIndex else { return values.first ?? 0 }

        if isSkyline {
            var minY = Double.infinity
            for i in startIndex...endIndex {
                minY = min(minY, values[i])
            }
            return minY == .infinity ? (values.first ?? 0) : minY
        } else {
            var maxY = -Double.infinity
            for i in startIndex...endIndex {
                maxY = max(maxY, values[i])
            }
            return maxY == -.infinity ? (values.first ?? 0) : maxY
        }
    }

    /// Convenience alias matching the bottomline query pattern.
    public func queryBottomline(xStart: Double, xEnd: Double) -> Double {
        querySkyline(xStart: xStart, xEnd: xEnd)
    }
}
