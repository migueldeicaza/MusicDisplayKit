import MusicDisplayKitLayout
import MusicDisplayKitModel

#if canImport(SwiftUI)
import SwiftUI
import Observation
import VexFoundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
public struct VexSwiftUICanvasContextProvider: VexRenderContextProvider {
    public let context: SwiftUICanvasContext

    public init(context: SwiftUICanvasContext) {
        self.context = context
    }

    public func makeContext(width: Double, height: Double, target: RenderTarget) -> RenderContext {
        _ = context.resize(width, height)
        return context
    }
}

private struct ScoreLayoutInput: Equatable {
    let score: Score
    let layoutOptions: LayoutOptions
}

private struct ScoreRenderInput: Equatable {
    let laidOutScoreRevision: UInt64
    let target: RenderTarget
}

private struct LazyLaidOutScoreInput: Equatable {
    let laidOutScoreRevision: UInt64
    let target: RenderTarget
}

private struct PreparedScoreRender {
    let renderPlan: VexRenderPlan
}

public struct LazySystemGroup: Identifiable, Equatable {
    public let systemIndex: Int
    public let top: Double
    public let height: Double
    public var id: Int { systemIndex }
}

/// Preference key that reports per-system vertical offsets mapping layout-engine
/// coordinates to the rendered coordinates used by ``MusicDisplayLazyScoreView``.
/// Add the offset to a layout `frame.y` to obtain the actual Y in the rendered output.
@available(iOS 17.0, macOS 14.0, *)
public struct LazyScoreSystemYOffsetsKey: PreferenceKey {
    nonisolated(unsafe) public static var defaultValue: [Int: Double] = [:]
    public static func reduce(value: inout [Int: Double], nextValue: () -> [Int: Double]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct PreparedLazySystemRender: Identifiable {
    let group: LazySystemGroup
    let renderPlan: VexRenderPlan
    var id: Int { group.systemIndex }
}

private struct PreparedLazyScoreRender {
    let renderPlan: VexRenderPlan
    let systems: [PreparedLazySystemRender]
    let availableSystemIndexRange: ClosedRange<Int>?
    let measureRangeBySystem: [Int: Range<Int>]
}

struct LazySystemVerticalBleed: Sendable {
    var top: Double
    var bottom: Double

    static let `default` = LazySystemVerticalBleed(top: 0, bottom: 26)
}

/// Estimates additional bleed needed for notes that extend far above/below
/// the staff via ledger lines. Returns (top, bottom) bleed in pixels.
func estimateLedgerLineBleed(
    keyTokens: [String],
    clef: String?
) -> (top: Double, bottom: Double) {
    // Compute the VexFoundation line number for each note and estimate how far
    // it extends beyond the 5-line staff (lines 1–5).
    //
    // Line formula:  line = (octave * 7 - 28 + noteIndex) / 2 + clefShift
    // Rendered Y:    noteY = staveY + (5 - line) * spacing   (spacing ≈ 10)
    //
    // Notes above the staff have line > 5 → extend upward (top bleed).
    // Notes below the staff have line < 1 → extend downward (bottom bleed).
    var topBleed: Double = 0
    var bottomBleed: Double = 0

    let clefShift: Double
    switch clef {
    case "bass":   clefShift = 6
    case "alto":   clefShift = 3
    case "tenor":  clefShift = 4
    default:       clefShift = 0   // treble and others
    }

    let noteIndices: [Character: Int] = [
        "c": 0, "C": 0, "d": 1, "D": 1, "e": 2, "E": 2, "f": 3, "F": 3,
        "g": 4, "G": 4, "a": 5, "A": 5, "b": 6, "B": 6,
    ]

    for token in keyTokens {
        // Token format: "STEP/OCTAVE" e.g. "c/6", "f#/2"
        let parts = token.split(separator: "/")
        guard parts.count >= 2, let octave = Int(parts[1]) else { continue }
        guard let firstChar = parts[0].first, let noteIdx = noteIndices[firstChar] else { continue }

        let line = Double(octave * 7 - 28 + noteIdx) / 2.0 + clefShift

        if line > 5 {
            // Note is above the staff — needs ledger lines and stem clearance.
            let linesAbove = line - 5
            let px = linesAbove * 10 + 30  // 10px per line unit + stem/padding
            topBleed = max(topBleed, px)
        } else if line < 1 {
            // Note is below the staff — needs ledger lines and stem clearance.
            let linesBelow = 1 - line
            let px = linesBelow * 10 + 20  // 10px per line unit + stem/padding
            bottomBleed = max(bottomBleed, px)
        }
    }

    return (top: topBleed, bottom: bottomBleed)
}

/// Tracks which element categories are present per system,
/// so the bleed can be computed cumulatively (stacking) rather than via `max`.
struct SystemPresence {
    // Below-staff
    var hasDynamicsBelow: Bool = false
    var hasWedgesBelow: Bool = false
    var hasPedals: Bool = false
    var maxLyricVerses: Int = 0
    var hasOctaveShiftBelow: Bool = false
    var hasDirectionTextBelow: Bool = false
    // Above-staff (these stack: rehearsal, tempo, direction text)
    var hasRehearsalAbove: Bool = false
    var hasTempoAbove: Bool = false
    var hasDirectionTextAbove: Bool = false
    var hasOctaveShiftAbove: Bool = false
}

func makeLazySystemVerticalBleed(from renderPlan: VexRenderPlan) -> [Int: LazySystemVerticalBleed] {
    var bleedBySystemIndex: [Int: LazySystemVerticalBleed] = [:]
    var presenceBySystemIndex: [Int: SystemPresence] = [:]

    func updateBleed(
        for systemIndex: Int,
        _ body: (inout LazySystemVerticalBleed) -> Void
    ) {
        var bleed = bleedBySystemIndex[systemIndex] ?? .default
        body(&bleed)
        bleedBySystemIndex[systemIndex] = bleed
    }

    func updatePresence(
        for systemIndex: Int,
        _ body: (inout SystemPresence) -> Void
    ) {
        var presence = presenceBySystemIndex[systemIndex] ?? SystemPresence()
        body(&presence)
        presenceBySystemIndex[systemIndex] = presence
    }

    // Seed systems from stave plans so gaps with sparse notation still get defaults.
    for stave in renderPlan.staves {
        updateBleed(for: stave.systemIndex) { bleed in
            if stave.startMeasureNumber != nil {
                bleed.top = max(bleed.top, 18)
            }
            if stave.initialClef != nil {
                bleed.top = max(bleed.top, 24)
            }
            if stave.initialTimeSignature != nil {
                bleed.top = max(bleed.top, 24)
            }
            if stave.initialKeySignature != nil {
                bleed.top = max(bleed.top, 20)
            }
        }
    }

    for note in renderPlan.notes {
        updateBleed(for: note.systemIndex) { bleed in
            switch note.stemDirection {
            case .some(.down):
                bleed.bottom = max(bleed.bottom, 30)
            case .some(.up):
                break
            case .some(.none), .some(.double):
                bleed.bottom = max(bleed.bottom, 28)
            case nil:
                bleed.bottom = max(bleed.bottom, 28)
            }

            if !note.dynamics.isEmpty {
                updatePresence(for: note.systemIndex) { $0.hasDynamicsBelow = true }
            }

            if !note.graceNotes.isEmpty {
                bleed.top = max(bleed.top, 10)
                bleed.bottom = max(bleed.bottom, 34)
            }

            // Estimate extra bleed for notes with many ledger lines.
            // Key tokens are like "C/6", "F/2", etc. Parse the octave to
            // estimate how far outside the staff the note extends.
            if !note.isRest {
                let ledgerBleed = estimateLedgerLineBleed(keyTokens: note.keyTokens, clef: note.clef)
                bleed.top = max(bleed.top, ledgerBleed.top)
                bleed.bottom = max(bleed.bottom, ledgerBleed.bottom)
            }
        }
    }

    for articulation in renderPlan.articulations {
        updateBleed(for: articulation.systemIndex) { bleed in
            switch articulation.position {
            case .above:
                bleed.top = max(bleed.top, 20)
            case .below:
                bleed.bottom = max(bleed.bottom, 36)
            case nil:
                bleed.bottom = max(bleed.bottom, 32)
            }
        }
    }

    for fingering in renderPlan.fingerings {
        updateBleed(for: fingering.systemIndex) { bleed in
            switch fingering.position {
            case .above:
                bleed.top = max(bleed.top, 22)
            case .below:
                bleed.bottom = max(bleed.bottom, 38)
            case .left, .right, nil:
                break
            }
        }
    }

    for stringNumber in renderPlan.stringNumbers {
        updateBleed(for: stringNumber.systemIndex) { bleed in
            switch stringNumber.position {
            case .above:
                bleed.top = max(bleed.top, 22)
            case .below:
                bleed.bottom = max(bleed.bottom, 38)
            case .left, .right, nil:
                break
            }
        }
    }

    for tuplet in renderPlan.tuplets {
        updateBleed(for: tuplet.systemIndex) { bleed in
            switch tuplet.location {
            case .top:
                bleed.top = max(bleed.top, 24)
            case .bottom:
                bleed.bottom = max(bleed.bottom, 34)
            case nil:
                bleed.top = max(bleed.top, 20)
            }
        }
    }

    // Count max lyric verses per system instead of a flat bleed.
    var versesBySystem: [Int: Set<Int>] = [:]
    for lyric in renderPlan.lyrics {
        versesBySystem[lyric.systemIndex, default: []].insert(lyric.verse)
    }
    for lyricConnector in renderPlan.lyricConnectors {
        if lyricConnector.startSystemIndex == lyricConnector.endSystemIndex {
            versesBySystem[lyricConnector.startSystemIndex, default: []].insert(lyricConnector.verse)
        }
    }
    for (systemIndex, verses) in versesBySystem {
        updatePresence(for: systemIndex) { $0.maxLyricVerses = max($0.maxLyricVerses, verses.count) }
    }

    for chordSymbol in renderPlan.chordSymbols {
        updateBleed(for: chordSymbol.systemIndex) { bleed in
            switch chordSymbol.placement {
            case .above:
                bleed.top = max(bleed.top, 28)
            case .below:
                bleed.bottom = max(bleed.bottom, 40)
            }
        }
    }

    for directionText in renderPlan.directionTexts {
        switch directionText.placement {
        case .above:
            updatePresence(for: directionText.systemIndex) { $0.hasDirectionTextAbove = true }
        case .below:
            updatePresence(for: directionText.systemIndex) { $0.hasDirectionTextBelow = true }
        case nil:
            updatePresence(for: directionText.systemIndex) { $0.hasDirectionTextAbove = true }
        }
    }

    for tempo in renderPlan.tempoMarks {
        updatePresence(for: tempo.systemIndex) { $0.hasTempoAbove = true }
    }

    for repetition in renderPlan.roadmapRepetitions {
        updatePresence(for: repetition.systemIndex) { $0.hasRehearsalAbove = true }
    }

    for wedge in renderPlan.directionWedges {
        switch wedge.placement {
        case .above:
            updateBleed(for: wedge.systemIndex) { bleed in
                bleed.top = max(bleed.top, 26)
            }
        case .below:
            updatePresence(for: wedge.systemIndex) { $0.hasWedgesBelow = true }
        case nil:
            updatePresence(for: wedge.systemIndex) { $0.hasWedgesBelow = true }
        }
    }

    for octaveShift in renderPlan.octaveShiftSpanners {
        switch octaveShift.position {
        case .top:
            updatePresence(for: octaveShift.systemIndex) { $0.hasOctaveShiftAbove = true }
        case .bottom:
            updatePresence(for: octaveShift.systemIndex) { $0.hasOctaveShiftBelow = true }
        }
    }

    for pedal in renderPlan.pedalMarkings {
        updatePresence(for: pedal.systemIndex) { $0.hasPedals = true }
    }

    // Compute cumulative bleed from stacking categories.
    let allSystemIndices = Set(bleedBySystemIndex.keys).union(presenceBySystemIndex.keys)
    for systemIndex in allSystemIndices {
        let presence = presenceBySystemIndex[systemIndex] ?? SystemPresence()

        // Above-staff stacking: these elements stack above notes/articulations.
        var aboveStackedBleed: Double = 0
        if presence.hasDirectionTextAbove { aboveStackedBleed += 20 }
        if presence.hasTempoAbove { aboveStackedBleed += 24 }
        if presence.hasRehearsalAbove { aboveStackedBleed += 24 }
        if presence.hasOctaveShiftAbove { aboveStackedBleed += 24 }

        // Below-staff stacking: these elements stack below the staff.
        // Use max with base bleed (from note ledger lines/stems) since the
        // stacked elements and note extensions overlap in Y space.
        var belowStackedBleed: Double = 0
        if presence.hasDynamicsBelow || presence.hasDirectionTextBelow {
            belowStackedBleed += 20
        }
        if presence.hasWedgesBelow {
            belowStackedBleed += 20
        }
        if presence.hasOctaveShiftBelow {
            belowStackedBleed += 20
        }
        if presence.hasPedals {
            belowStackedBleed += 30
        }
        if presence.maxLyricVerses > 0 {
            belowStackedBleed += Double(presence.maxLyricVerses) * 16
        }

        updateBleed(for: systemIndex) { bleed in
            // Above-staff: annotations (rehearsal, tempo, text, 8va) render above
            // notes with ledger lines, so ADD stacking on top of the ledger bleed.
            bleed.top = bleed.top + aboveStackedBleed
            // Below-staff: stacking elements (dynamics, wedges, pedals, lyrics) are
            // positioned at fixed offsets from the staff bottom and overlap with
            // ledger lines. Use the greater of the two extents.
            bleed.bottom = max(bleed.bottom, belowStackedBleed)
        }
    }

    return bleedBySystemIndex
}

func makeLazySystemGroups(
    from laidOutScore: LaidOutScore,
    bleedBySystemIndex: [Int: LazySystemVerticalBleed]
) -> [LazySystemGroup] {
    var verticalBoundsBySystemIndex: [Int: (minimumY: Double, maximumY: Double)] = [:]
    for system in laidOutScore.systems {
        let minimumY = system.frame.y
        let maximumY = system.frame.y + system.frame.height
        if let existing = verticalBoundsBySystemIndex[system.systemIndex] {
            verticalBoundsBySystemIndex[system.systemIndex] = (
                minimumY: min(existing.minimumY, minimumY),
                maximumY: max(existing.maximumY, maximumY)
            )
        } else {
            verticalBoundsBySystemIndex[system.systemIndex] = (
                minimumY: minimumY,
                maximumY: maximumY
            )
        }
    }

    let sortedSystemIndices = verticalBoundsBySystemIndex.keys.sorted()
    guard !sortedSystemIndices.isEmpty else { return [] }

    // Use generous leading bleed only when the score has title/metadata that
    // renders above the first system. Otherwise use a modest margin.
    let hasMetadata = !laidOutScore.score.title.isEmpty
        || laidOutScore.score.composer != nil
        || laidOutScore.score.lyricist != nil
    let leadingBleed: Double = hasMetadata ? 72 : 34
    let trailingBleed: Double = 80
    let minimumRowHeight: Double = 48

    var groups: [LazySystemGroup] = []
    groups.reserveCapacity(sortedSystemIndices.count)
    for (offset, systemIndex) in sortedSystemIndices.enumerated() {
        guard let bounds = verticalBoundsBySystemIndex[systemIndex] else { continue }
        let bleed = bleedBySystemIndex[systemIndex] ?? .default
        let topBleed = offset == 0 ? max(leadingBleed, bleed.top) : bleed.top
        let isLast = offset == sortedSystemIndices.count - 1
        let bottomBleed = isLast ? max(trailingBleed, bleed.bottom) : bleed.bottom

        // First system: allow negative top so title/metadata above the staff
        // becomes visible (yOffset shifts content into the canvas).
        // Other systems: clamp to 0 since they don't need extra above-canvas space.
        let top = offset == 0
            ? bounds.minimumY - topBleed
            : max(0, bounds.minimumY - topBleed)
        let rawBottom = bounds.maximumY + bottomBleed
        let bottom = max(top + minimumRowHeight, max(bounds.maximumY, rawBottom))
        let height = max(minimumRowHeight, bottom - top)
        groups.append(
            LazySystemGroup(
                systemIndex: systemIndex,
                top: top,
                height: height
            )
        )
    }
    return groups
}

@MainActor
private enum LazyRowDiagnostics {
    private static var lastLoggedRenderRevision: UInt64?

    static func emitIfEnabled(
        laidOutScore: LaidOutScore,
        groups: [LazySystemGroup],
        canvasHeight: Double,
        bleedBySystemIndex: [Int: LazySystemVerticalBleed]
    ) {
//        guard ProcessInfo.processInfo.environment["MDK_LAZY_ROW_DIAGNOSTICS"] == "1" else {
//            return
//        }
        guard lastLoggedRenderRevision != laidOutScore.renderRevision else {
            return
        }
        lastLoggedRenderRevision = laidOutScore.renderRevision

        var sourceBoundsBySystem: [Int: (minimumY: Double, maximumY: Double)] = [:]
        for system in laidOutScore.systems {
            let minimumY = system.frame.y
            let maximumY = system.frame.y + system.frame.height
            if let existing = sourceBoundsBySystem[system.systemIndex] {
                sourceBoundsBySystem[system.systemIndex] = (
                    minimumY: min(existing.minimumY, minimumY),
                    maximumY: max(existing.maximumY, maximumY)
                )
            } else {
                sourceBoundsBySystem[system.systemIndex] = (
                    minimumY: minimumY,
                    maximumY: maximumY
                )
            }
        }

        let sortedGroups = groups.sorted { $0.systemIndex < $1.systemIndex }
        guard let firstGroup = sortedGroups.first, let lastGroup = sortedGroups.last else {
            print("[MDK lazy rows] no groups")
            return
        }

        let firstTop = firstGroup.top
        let lastBottom = lastGroup.top + lastGroup.height
        let spanHeight = lastBottom - firstTop
        let stackedHeight = sortedGroups.reduce(0) { partial, group in
            partial + group.height
        }

        print(
            "[MDK lazy rows] revision=\(laidOutScore.renderRevision) systems=\(sortedGroups.count) " +
            "canvasHeight=\(Int(canvasHeight)) spanHeight=\(Int(spanHeight)) stackedHeight=\(Int(stackedHeight))"
        )

        for (offset, group) in sortedGroups.enumerated() {
            guard let sourceBounds = sourceBoundsBySystem[group.systemIndex] else { continue }
            let bottom = group.top + group.height
            let topHeadroom = sourceBounds.minimumY - group.top
            let bottomHeadroom = bottom - sourceBounds.maximumY
            let bleed = bleedBySystemIndex[group.systemIndex] ?? .default
            let sourceGap: Double
            let requestedGap: Double
            let overflowPastSourceGap: Double
            if offset == 0 {
                sourceGap = 0
                requestedGap = 0
                overflowPastSourceGap = 0
            } else {
                let previous = sortedGroups[offset - 1]
                let previousSourceBounds = sourceBoundsBySystem[previous.systemIndex]
                let previousBleed = bleedBySystemIndex[previous.systemIndex] ?? .default
                if let previousSourceBounds {
                    sourceGap = sourceBounds.minimumY - previousSourceBounds.maximumY
                } else {
                    sourceGap = 0
                }
                requestedGap = previousBleed.bottom + bleed.top
                overflowPastSourceGap = requestedGap - sourceGap
            }
            print(
                "[MDK lazy rows] system=\(group.systemIndex) " +
                "source=(\(Int(sourceBounds.minimumY))...\(Int(sourceBounds.maximumY))) " +
                "slice=(\(Int(group.top))...\(Int(bottom))) " +
                "headroomTop=\(Int(topHeadroom)) headroomBottom=\(Int(bottomHeadroom)) " +
                "requestedTop=\(Int(bleed.top)) requestedBottom=\(Int(bleed.bottom)) " +
                "sourceGapFromPrevious=\(Int(sourceGap)) " +
                "requestedGapFromPrevious=\(Int(requestedGap)) " +
                "overflowFromPrevious=\(Int(overflowPastSourceGap))"
            )
        }
    }
}

private func makePreparedLazySystems(
    from renderPlan: VexRenderPlan,
    systemGroups: [LazySystemGroup]
) -> [PreparedLazySystemRender] {
    systemGroups.map { group in
        PreparedLazySystemRender(
            group: group,
            renderPlan: renderPlan.systemSlice(for: group)
        )
    }
}

private func makeSystemIndexRange(from systems: [PreparedLazySystemRender]) -> ClosedRange<Int>? {
    guard let first = systems.first else { return nil }
    var minimum = first.group.systemIndex
    var maximum = first.group.systemIndex
    for system in systems.dropFirst() {
        minimum = min(minimum, system.group.systemIndex)
        maximum = max(maximum, system.group.systemIndex)
    }
    return minimum...maximum
}

private func makeMeasureRangeBySystem(from renderPlan: VexRenderPlan) -> [Int: Range<Int>] {
    var boundsBySystem: [Int: (minimum: Int, maximum: Int)] = [:]
    for measure in renderPlan.measures {
        let systemIndex = measure.systemIndex
        if let bounds = boundsBySystem[systemIndex] {
            boundsBySystem[systemIndex] = (
                minimum: min(bounds.minimum, measure.measureIndexInPart),
                maximum: max(bounds.maximum, measure.measureIndexInPart)
            )
        } else {
            boundsBySystem[systemIndex] = (
                minimum: measure.measureIndexInPart,
                maximum: measure.measureIndexInPart
            )
        }
    }

    return boundsBySystem.mapValues { bounds in
        bounds.minimum..<(bounds.maximum + 1)
    }
}

enum LazyMeasureWindowing {
    static func clamp(
        _ range: Range<Int>?,
        totalMeasures: Int
    ) -> Range<Int>? {
        guard totalMeasures > 0, let range else { return nil }
        let lower = max(0, min(totalMeasures - 1, range.lowerBound))
        let upper = max(lower + 1, min(totalMeasures, range.upperBound))
        return lower..<upper
    }

    static func initialRange(
        totalMeasures: Int,
        preferredRange: Range<Int>?,
        windowLength: Int
    ) -> Range<Int>? {
        guard totalMeasures > 0 else { return nil }
        if let preferredRange {
            return clamp(preferredRange, totalMeasures: totalMeasures)
        }
        return 0..<min(totalMeasures, max(1, windowLength))
    }

    static func expandedRangeIfNeeded(
        currentRange: Range<Int>,
        visibleRange: Range<Int>?,
        totalMeasures: Int,
        windowLength: Int,
        threshold: Int
    ) -> Range<Int>? {
        guard totalMeasures > 0 else { return nil }
        guard let visibleRange else { return nil }
        guard currentRange.upperBound < totalMeasures else { return nil }
        guard visibleRange.upperBound >= currentRange.upperBound - max(1, threshold) else {
            return nil
        }

        let expandedUpperBound = min(totalMeasures, currentRange.upperBound + max(1, windowLength))
        guard expandedUpperBound > currentRange.upperBound else { return nil }
        return currentRange.lowerBound..<expandedUpperBound
    }
}

enum LazySystemVisibility {
    static func recordVisibleSystem(
        currentHighestVisibleSystemIndex: Int?,
        appearedSystemIndex: Int
    ) -> Int {
        max(currentHighestVisibleSystemIndex ?? appearedSystemIndex, appearedSystemIndex)
    }

    static func clampedHighestVisibleSystemIndex(
        currentHighestVisibleSystemIndex: Int?,
        availableSystemRange: ClosedRange<Int>?
    ) -> Int? {
        guard let availableSystemRange else { return nil }
        let seed = currentHighestVisibleSystemIndex ?? availableSystemRange.lowerBound
        return min(
            availableSystemRange.upperBound,
            max(availableSystemRange.lowerBound, seed)
        )
    }
}

@MainActor
@Observable
private final class LazyVisibleSystemTracker {
    private(set) var highestVisibleSystemIndex: Int?

    func recordVisibleSystem(_ systemIndex: Int) -> Bool {
        let nextHighest = LazySystemVisibility.recordVisibleSystem(
            currentHighestVisibleSystemIndex: highestVisibleSystemIndex,
            appearedSystemIndex: systemIndex
        )
        guard nextHighest != highestVisibleSystemIndex else {
            return false
        }
        highestVisibleSystemIndex = nextHighest
        return true
    }

    func clamp(to availableSystemRange: ClosedRange<Int>?) {
        highestVisibleSystemIndex = LazySystemVisibility.clampedHighestVisibleSystemIndex(
            currentHighestVisibleSystemIndex: highestVisibleSystemIndex,
            availableSystemRange: availableSystemRange
        )
    }
}

@MainActor
@Observable
private final class ScoreLayoutCache {
    private var cachedInput: ScoreLayoutInput?
    private var cachedResult: Result<LaidOutScore, Error>?

    func resolve(score: Score, layoutOptions: LayoutOptions) -> Result<LaidOutScore, Error> {
        let input = ScoreLayoutInput(score: score, layoutOptions: layoutOptions)
        if let cachedInput, cachedInput == input, let cachedResult {
            return cachedResult
        }

        let result = Result {
            try MusicLayoutEngine().layout(score: score, options: layoutOptions)
        }
        cachedInput = input
        cachedResult = result
        return result
    }
}

@MainActor
@Observable
private final class ScoreRenderCache {
    private var cachedInput: ScoreRenderInput?
    private var cachedRender: PreparedScoreRender?

    func resolve(laidOutScore: LaidOutScore, target: RenderTarget) -> PreparedScoreRender {
        let input = ScoreRenderInput(
            laidOutScoreRevision: laidOutScore.renderRevision,
            target: target
        )
        if let cachedInput, cachedInput == input, let cachedRender {
            return cachedRender
        }

        let renderer = VexFoundationRenderer()
        let renderPlan = renderer.makeRenderPlan(from: laidOutScore, target: target)
        let prepared = PreparedScoreRender(renderPlan: renderPlan)
        cachedInput = input
        cachedRender = prepared
        return prepared
    }
}

@MainActor
@Observable
private final class LazyLaidOutScoreRenderCache {
    private var cachedInput: LazyLaidOutScoreInput?
    private var cachedPrepared: PreparedLazyScoreRender?

    func resolve(laidOutScore: LaidOutScore, target: RenderTarget) -> PreparedLazyScoreRender {
        let input = LazyLaidOutScoreInput(
            laidOutScoreRevision: laidOutScore.renderRevision,
            target: target
        )
        if let cachedInput, cachedInput == input, let cachedPrepared {
            return cachedPrepared
        }

        let renderer = VexFoundationRenderer()
        let renderPlan = renderer.makeRenderPlan(from: laidOutScore, target: target)
        let bleedBySystemIndex = makeLazySystemVerticalBleed(from: renderPlan)
        let systemGroups = makeLazySystemGroups(
            from: laidOutScore,
            bleedBySystemIndex: bleedBySystemIndex
        )
        LazyRowDiagnostics.emitIfEnabled(
            laidOutScore: laidOutScore,
            groups: systemGroups,
            canvasHeight: renderPlan.canvasHeight,
            bleedBySystemIndex: bleedBySystemIndex
        )
        let systems = makePreparedLazySystems(from: renderPlan, systemGroups: systemGroups)
        let prepared = PreparedLazyScoreRender(
            renderPlan: renderPlan,
            systems: systems,
            availableSystemIndexRange: makeSystemIndexRange(from: systems),
            measureRangeBySystem: makeMeasureRangeBySystem(from: renderPlan)
        )
        cachedInput = input
        cachedPrepared = prepared
        return prepared
    }
}

private extension LayoutRect {
    func offsetting(y delta: Double) -> LayoutRect {
        LayoutRect(x: x, y: y + delta, width: width, height: height)
    }
}

private extension VexStavePlan {
    func offsetting(y delta: Double) -> VexStavePlan {
        VexStavePlan(
            systemIndex: systemIndex,
            partIndex: partIndex,
            pageIndex: pageIndex,
            frame: frame.offsetting(y: delta),
            startMeasureNumber: startMeasureNumber,
            initialClef: initialClef,
            initialClefAnnotation: initialClefAnnotation,
            initialKeySignature: initialKeySignature,
            initialTimeSignature: initialTimeSignature,
            multipleRestCount: multipleRestCount,
            beginBarline: beginBarline,
            endBarline: endBarline
        )
    }
}

private extension VexMeasurePlan {
    func offsetting(y delta: Double) -> VexMeasurePlan {
        VexMeasurePlan(
            measureIndex: measureIndex,
            partIndex: partIndex,
            measureIndexInPart: measureIndexInPart,
            measureNumber: measureNumber,
            systemIndex: systemIndex,
            pageIndex: pageIndex,
            frame: frame.offsetting(y: delta)
        )
    }
}

private extension VexNotePlan {
    func offsetting(y delta: Double) -> VexNotePlan {
        VexNotePlan(
            systemIndex: systemIndex,
            partIndex: partIndex,
            measureIndexInPart: measureIndexInPart,
            measureNumber: measureNumber,
            pageIndex: pageIndex,
            measureFrame: measureFrame.offsetting(y: delta),
            isFirstMeasureInSystem: isFirstMeasureInSystem,
            voice: voice,
            staff: staff,
            clef: clef,
            entryIndexInVoice: entryIndexInVoice,
            onsetDivisions: onsetDivisions,
            durationDivisions: durationDivisions,
            divisions: divisions,
            timeSignatureBeats: timeSignatureBeats,
            timeSignatureBeatType: timeSignatureBeatType,
            isRest: isRest,
            keyTokens: keyTokens,
            sourceOrder: sourceOrder,
            noteType: noteType,
            dotCount: dotCount,
            accidental: accidental,
            stemDirection: stemDirection,
            ornaments: ornaments,
            fermatas: fermatas,
            arpeggiate: arpeggiate,
            tremolo: tremolo,
            dynamics: dynamics,
            glissandos: glissandos,
            isCue: isCue,
            noteheadType: noteheadType,
            color: color,
            graceNotes: graceNotes,
            crossStaffTarget: crossStaffTarget
        )
    }
}

private extension VexPartGroupConnectorPlan {
    func offsetting(y delta: Double) -> VexPartGroupConnectorPlan {
        VexPartGroupConnectorPlan(
            sourceGroupIndex: sourceGroupIndex,
            pageIndex: pageIndex,
            startSystemIndex: startSystemIndex,
            endSystemIndex: endSystemIndex,
            startPartIndex: startPartIndex,
            endPartIndex: endPartIndex,
            kind: kind,
            renderOrder: renderOrder,
            style: style,
            label: label,
            frame: frame.offsetting(y: delta)
        )
    }
}

private extension VexBarlineConnectorPlan {
    func offsetting(y delta: Double) -> VexBarlineConnectorPlan {
        VexBarlineConnectorPlan(
            sourceGroupIndex: sourceGroupIndex,
            pageIndex: pageIndex,
            startSystemIndex: startSystemIndex,
            endSystemIndex: endSystemIndex,
            startPartIndex: startPartIndex,
            endPartIndex: endPartIndex,
            kind: kind,
            frame: frame.offsetting(y: delta)
        )
    }
}

private extension VexRenderPlan {
    func systemSlice(for group: LazySystemGroup) -> VexRenderPlan {
        let systemIndex = group.systemIndex
        let includeMetadata = systemIndex == 0
        let yOffset = -group.top

        return VexRenderPlan(
            canvasWidth: canvasWidth,
            canvasHeight: max(1, group.height),
            pageCount: 1,
            autoBeam: autoBeam,
            title: includeMetadata ? title : nil,
            composer: includeMetadata ? composer : nil,
            lyricist: includeMetadata ? lyricist : nil,
            partNames: partNames,
            partAbbreviations: partAbbreviations,
            staves: staves
                .filter { $0.systemIndex == systemIndex }
                .map { $0.offsetting(y: yOffset) },
            measures: measures
                .filter { $0.systemIndex == systemIndex }
                .map { $0.offsetting(y: yOffset) },
            measureBoundaries: measureBoundaries
                .filter { $0.systemIndex == systemIndex },
            notes: notes
                .filter { $0.systemIndex == systemIndex }
                .map { $0.offsetting(y: yOffset) },
            inlineClefChanges: inlineClefChanges
                .filter { $0.systemIndex == systemIndex },
            beams: beams
                .filter { $0.systemIndex == systemIndex },
            tuplets: tuplets
                .filter { $0.systemIndex == systemIndex },
            ties: ties
                .filter { $0.systemIndex == systemIndex },
            slurs: slurs
                .filter { $0.systemIndex == systemIndex },
            articulations: articulations
                .filter { $0.systemIndex == systemIndex },
            fingerings: fingerings
                .filter { $0.systemIndex == systemIndex },
            stringNumbers: stringNumbers
                .filter { $0.systemIndex == systemIndex },
            tabPositions: tabPositions
                .filter { $0.systemIndex == systemIndex },
            lyrics: lyrics
                .filter { $0.systemIndex == systemIndex },
            chordSymbols: chordSymbols
                .filter { $0.systemIndex == systemIndex },
            directionTexts: directionTexts
                .filter { $0.systemIndex == systemIndex },
            tempoMarks: tempoMarks
                .filter { $0.systemIndex == systemIndex },
            roadmapRepetitions: roadmapRepetitions
                .filter { $0.systemIndex == systemIndex },
            directionWedges: directionWedges
                .filter { $0.systemIndex == systemIndex },
            octaveShiftSpanners: octaveShiftSpanners
                .filter { $0.systemIndex == systemIndex },
            pedalMarkings: pedalMarkings
                .filter { $0.systemIndex == systemIndex },
            lyricConnectors: lyricConnectors
                .filter { $0.startSystemIndex == systemIndex && $0.endSystemIndex == systemIndex },
            partGroupConnectors: partGroupConnectors
                .filter { $0.startSystemIndex == systemIndex && $0.endSystemIndex == systemIndex }
                .map { $0.offsetting(y: yOffset) },
            barlineConnectors: barlineConnectors
                .filter { $0.startSystemIndex == systemIndex && $0.endSystemIndex == systemIndex }
                .map { $0.offsetting(y: yOffset) }
        )
    }
}

private func drawExecution(_ execution: VexFactoryExecution, on context: RenderContext) throws {
    _ = execution.factory.setContext(context)
    try execution.factory.draw()
    for wedge in execution.directionWedges {
        _ = wedge.setContext(context)
        try wedge.draw()
    }
}

private struct LayoutFailureView: View {
    var body: some View {
        Text("MusicDisplay layout failed")
            .font(.caption.monospaced())
            .foregroundStyle(.red)
            .padding(8)
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct VexScoreView: View {
    private let laidOutScore: LaidOutScore
    private let target: RenderTarget
    @State private var renderCache = ScoreRenderCache()

    public init(laidOutScore: LaidOutScore, target: RenderTarget = .view(identifier: "music-display-view")) {
        self.laidOutScore = laidOutScore
        self.target = target
    }

    public init(laidOutScore: LaidOutScore, targetIdentifier: String) {
        self.init(laidOutScore: laidOutScore, target: .view(identifier: targetIdentifier))
    }

    public var body: some View {
        let prepared = renderCache.resolve(laidOutScore: laidOutScore, target: target)

        return VexCanvas(
            width: max(1, prepared.renderPlan.canvasWidth),
            height: max(1, prepared.renderPlan.canvasHeight)
        ) { context in
            context.clear()
            do {
                // Factory.draw() resets the factory queue, so executions are single-use.
                let execution = VexFoundationRenderer().executeRenderPlan(prepared.renderPlan)
                try drawExecution(execution, on: context)
            } catch {
                context.setFillStyle("#B00020")
                context.setFont("Menlo", 12, "normal", "normal")
                context.fillText("MusicDisplay render failed: \(error)", 12, 20)
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct MusicDisplayScoreView: View {
    private let score: Score
    private let layoutOptions: LayoutOptions
    private let target: RenderTarget
    /// When true, the view re-layouts when its width changes (auto-resize).
    private let autoResize: Bool
    @State private var layoutCache = ScoreLayoutCache()
    @State private var debouncedPageWidth: Double?
    @State private var pendingWidthCommitTask: Task<Void, Never>?

    public init(
        score: Score,
        layoutOptions: LayoutOptions = LayoutOptions(),
        target: RenderTarget = .view(identifier: "music-display-view"),
        autoResize: Bool = false
    ) {
        self.score = score
        self.layoutOptions = layoutOptions
        self.target = target
        self.autoResize = autoResize
    }

    public init(
        score: Score,
        layoutOptions: LayoutOptions = LayoutOptions(),
        targetIdentifier: String,
        autoResize: Bool = false
    ) {
        self.init(score: score, layoutOptions: layoutOptions, target: .view(identifier: targetIdentifier), autoResize: autoResize)
    }

    public var body: some View {
        if autoResize {
            GeometryReader { geometry in
                let measuredWidth = max(200, geometry.size.width)
                let pageWidth = debouncedPageWidth ?? measuredWidth
                content(for: layoutOptionsWithPageWidth(pageWidth))
                    .onAppear {
                        if debouncedPageWidth == nil {
                            debouncedPageWidth = measuredWidth
                        }
                        scheduleWidthCommit(measuredWidth)
                    }
                    .onChange(of: measuredWidth) { _, newWidth in
                        scheduleWidthCommit(newWidth)
                    }
                    .onDisappear {
                        pendingWidthCommitTask?.cancel()
                        pendingWidthCommitTask = nil
                    }
            }
        } else {
            content(for: layoutOptions)
        }
    }

    private func layoutOptionsWithPageWidth(_ pageWidth: Double) -> LayoutOptions {
        var options = layoutOptions
        options.pageWidth = max(200, pageWidth)
        return options
    }

    private func scheduleWidthCommit(_ pageWidth: Double) {
        let clampedWidth = max(200, pageWidth)
        pendingWidthCommitTask?.cancel()
        pendingWidthCommitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            if debouncedPageWidth != clampedWidth {
                debouncedPageWidth = clampedWidth
            }
        }
    }

    @ViewBuilder
    private func content(for options: LayoutOptions) -> some View {
        switch layoutCache.resolve(score: score, layoutOptions: options) {
        case .success(let laidOutScore):
            VexScoreView(laidOutScore: laidOutScore, target: target)
        case .failure:
            LayoutFailureView()
        }
    }
}

/// A scrollable score view that can follow a cursor position.
@available(iOS 17.0, macOS 14.0, *)
public struct MusicDisplayScrollableScoreView: View {
    private let score: Score
    private let layoutOptions: LayoutOptions
    private let target: RenderTarget
    private let cursorMeasureIndex: Int?
    @State private var layoutCache = ScoreLayoutCache()

    public init(
        score: Score,
        layoutOptions: LayoutOptions = LayoutOptions(),
        target: RenderTarget = .view(identifier: "music-display-view"),
        cursorMeasureIndex: Int? = nil
    ) {
        self.score = score
        self.layoutOptions = layoutOptions
        self.target = target
        self.cursorMeasureIndex = cursorMeasureIndex
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                switch layoutCache.resolve(score: score, layoutOptions: layoutOptions) {
                case .success(let laidOutScore):
                    VexScoreView(laidOutScore: laidOutScore, target: target)
                        .id("score-content")
                case .failure:
                    LayoutFailureView()
                }
            }
            .onChange(of: cursorMeasureIndex) { _, _ in
                withAnimation {
                    proxy.scrollTo("score-content", anchor: .center)
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("MusicDisplayScoreView", traits: .sizeThatFitsLayout) {
    MusicDisplayScoreView(
        score: Score(
            title: "Preview",
            parts: [
                Part(
                    id: "P1",
                    name: "Piano",
                    measures: [
                        Measure(
                            number: 1,
                            divisions: 4,
                            attributes: MeasureAttributes(
                                key: KeySignature(fifths: 0, mode: "major"),
                                time: TimeSignature(beats: 4, beatType: 4),
                                clefs: [ClefSetting(sign: "G", line: 2)]
                            ),
                            noteEvents: [
                                NoteEvent(
                                    kind: .pitched,
                                    pitch: PitchValue(step: "C", octave: 4),
                                    onsetDivisions: 0,
                                    durationDivisions: 4,
                                    voice: 1
                                ),
                                NoteEvent(
                                    kind: .pitched,
                                    pitch: PitchValue(step: "E", octave: 4),
                                    onsetDivisions: 4,
                                    durationDivisions: 4,
                                    voice: 1
                                ),
                                NoteEvent(
                                    kind: .pitched,
                                    pitch: PitchValue(step: "G", octave: 4),
                                    onsetDivisions: 8,
                                    durationDivisions: 4,
                                    voice: 1
                                ),
                                NoteEvent(
                                    kind: .pitched,
                                    pitch: PitchValue(step: "C", octave: 5),
                                    onsetDivisions: 12,
                                    durationDivisions: 4,
                                    voice: 1
                                ),
                            ]
                        ),
                    ]
                ),
            ]
        ),
        layoutOptions: LayoutOptions(pageWidth: 520, pageMargin: 20, systemSpacing: 16)
    )
}

/// A lazy score view that renders each system row as a separate canvas (8.3).
/// Only visible systems (plus buffer) are materialised, reducing memory and
/// initial render time for long scores.
@available(iOS 17.0, macOS 14.0, *)
public struct MusicDisplayLazyScoreView: View {
    private enum Source {
        case score(score: Score, layoutOptions: LayoutOptions)
        case laidOutScore(LaidOutScore)
    }

    private let source: Source
    private let target: RenderTarget
    private let embedInScrollView: Bool
    private let renderBufferSystems: Int
    @State private var lazyMeasureRangeOverride: Range<Int>?
    @State private var visibleSystemTracker = LazyVisibleSystemTracker()
    @State private var layoutCache = ScoreLayoutCache()
    @State private var lazyLaidOutRenderCache = LazyLaidOutScoreRenderCache()

    public init(
        score: Score,
        layoutOptions: LayoutOptions = LayoutOptions(),
        target: RenderTarget = .view(identifier: "music-display-view"),
        embedInScrollView: Bool = true,
        renderBufferSystems: Int = 2
    ) {
        self.source = .score(score: score, layoutOptions: layoutOptions)
        self.target = target
        self.embedInScrollView = embedInScrollView
        self.renderBufferSystems = max(0, renderBufferSystems)
    }

    public init(
        score: Score,
        layoutOptions: LayoutOptions = LayoutOptions(),
        targetIdentifier: String,
        embedInScrollView: Bool = true,
        renderBufferSystems: Int = 2
    ) {
        self.init(
            score: score,
            layoutOptions: layoutOptions,
            target: .view(identifier: targetIdentifier),
            embedInScrollView: embedInScrollView,
            renderBufferSystems: renderBufferSystems
        )
    }

    public init(
        laidOutScore: LaidOutScore,
        target: RenderTarget = .view(identifier: "music-display-view"),
        embedInScrollView: Bool = true,
        renderBufferSystems: Int = 2
    ) {
        self.source = .laidOutScore(laidOutScore)
        self.target = target
        self.embedInScrollView = embedInScrollView
        self.renderBufferSystems = max(0, renderBufferSystems)
    }

    public init(
        laidOutScore: LaidOutScore,
        targetIdentifier: String,
        embedInScrollView: Bool = true,
        renderBufferSystems: Int = 2
    ) {
        self.init(
            laidOutScore: laidOutScore,
            target: .view(identifier: targetIdentifier),
            embedInScrollView: embedInScrollView,
            renderBufferSystems: renderBufferSystems
        )
    }

    @ViewBuilder
    public var body: some View {
        switch source {
        case .score(let score, let layoutOptions):
            let effectiveLayoutOptions = layoutOptionsForScoreSource(
                score: score,
                baseOptions: layoutOptions
            )
            switch layoutCache.resolve(score: score, layoutOptions: effectiveLayoutOptions) {
            case .success(let laidOutScore):
                let prepared = lazyLaidOutRenderCache.resolve(
                    laidOutScore: laidOutScore,
                    target: target
                )
                content(preparedResult: .success(prepared))
                    .onAppear {
                        initializeLazyMeasureRangeIfNeeded(
                            score: score,
                            baseOptions: layoutOptions
                        )
                        clampHighestVisibleSystemIndex(prepared: prepared)
                        maybeExpandLazyMeasureWindow(
                            score: score,
                            baseOptions: layoutOptions,
                            prepared: prepared
                        )
                    }
            case .failure(let error):
                content(preparedResult: .failure(error))
            }
        case .laidOutScore(let laidOutScore):
            let prepared = lazyLaidOutRenderCache.resolve(
                laidOutScore: laidOutScore,
                target: target
            )
            content(preparedResult: .success(prepared))
        }
    }

    @ViewBuilder
    private func content(preparedResult: Result<PreparedLazyScoreRender, Error>) -> some View {
        if embedInScrollView {
            ScrollView {
                systemRows(preparedResult: preparedResult)
            }
        } else {
            systemRows(preparedResult: preparedResult)
        }
    }

    @ViewBuilder
    private func systemRows(preparedResult: Result<PreparedLazyScoreRender, Error>) -> some View {
        switch preparedResult {
        case .success(let prepared):
            let offsets = Self.computeSystemYOffsets(from: prepared.systems.map(\.group))
            LazyVStack(spacing: 0) {
                ForEach(prepared.systems) { system in
                    systemRow(system, prepared: prepared)
                }
            }
            .frame(width: max(1, prepared.renderPlan.canvasWidth))
            .preference(key: LazyScoreSystemYOffsetsKey.self, value: offsets)
        case .failure:
            LayoutFailureView()
        }
    }

    private static func computeSystemYOffsets(from groups: [LazySystemGroup]) -> [Int: Double] {
        let sorted = groups.sorted { $0.systemIndex < $1.systemIndex }
        var offsets: [Int: Double] = [:]
        var cumulativeY: Double = 0
        for group in sorted {
            offsets[group.systemIndex] = cumulativeY - group.top
            cumulativeY += group.height
        }
        return offsets
    }

    @ViewBuilder
    private func systemRow(
        _ system: PreparedLazySystemRender,
        prepared: PreparedLazyScoreRender
    ) -> some View {
        let group = system.group
        let row = VexCanvas(
            width: max(1, prepared.renderPlan.canvasWidth),
            height: max(1, group.height)
        ) { context in
            context.clear()
            do {
                // Factory.draw() resets the factory queue, so executions are single-use.
                let execution = VexFoundationRenderer().executeRenderPlan(system.renderPlan)
                try drawExecution(execution, on: context)
            } catch {
                context.setFillStyle("#B00020")
                context.setFont("Menlo", 12, "normal", "normal")
                context.fillText("MusicDisplay render failed: \(error)", 12, 20)
            }
        }
        .frame(
            width: max(1, prepared.renderPlan.canvasWidth),
            height: max(1, group.height)
        )
        .clipped()
        .id("system-\(group.systemIndex)")

        switch source {
        case .score(let score, let layoutOptions):
            row.onAppear {
                let didAdvanceVisibleRange = visibleSystemTracker.recordVisibleSystem(group.systemIndex)
                if didAdvanceVisibleRange {
                    maybeExpandLazyMeasureWindow(
                        score: score,
                        baseOptions: layoutOptions,
                        prepared: prepared
                    )
                }
            }
        case .laidOutScore:
            row
        }
    }

    private var lazyMeasureWindowLength: Int {
        max(8, 24 + (renderBufferSystems * 8))
    }

    private var lazyMeasureExpansionThreshold: Int {
        max(2, lazyMeasureWindowLength / 4)
    }

    private func totalMeasureCount(in score: Score) -> Int {
        score.parts.map { $0.measures.count }.max() ?? 0
    }

    private func clampedMeasureRange(
        _ range: Range<Int>?,
        totalMeasures: Int
    ) -> Range<Int>? {
        LazyMeasureWindowing.clamp(range, totalMeasures: totalMeasures)
    }

    private func initialMeasureRange(
        for score: Score,
        baseOptions: LayoutOptions
    ) -> Range<Int>? {
        let total = totalMeasureCount(in: score)
        return LazyMeasureWindowing.initialRange(
            totalMeasures: total,
            preferredRange: baseOptions.measureRange,
            windowLength: lazyMeasureWindowLength
        )
    }

    private func layoutOptionsForScoreSource(
        score: Score,
        baseOptions: LayoutOptions
    ) -> LayoutOptions {
        guard baseOptions.measureRange == nil else {
            return baseOptions
        }
        let total = totalMeasureCount(in: score)
        guard total > 0 else {
            return baseOptions
        }
        let activeRange = clampedMeasureRange(
            lazyMeasureRangeOverride ?? initialMeasureRange(for: score, baseOptions: baseOptions),
            totalMeasures: total
        )
        guard let activeRange else {
            return baseOptions
        }
        var options = baseOptions
        options.measureRange = activeRange
        return options
    }

    private func initializeLazyMeasureRangeIfNeeded(
        score: Score,
        baseOptions: LayoutOptions
    ) {
        guard baseOptions.measureRange == nil else {
            lazyMeasureRangeOverride = nil
            return
        }
        let total = totalMeasureCount(in: score)
        guard total > 0 else {
            lazyMeasureRangeOverride = nil
            return
        }
        if let current = clampedMeasureRange(lazyMeasureRangeOverride, totalMeasures: total) {
            lazyMeasureRangeOverride = current
        } else {
            lazyMeasureRangeOverride = initialMeasureRange(for: score, baseOptions: baseOptions)
        }
    }

    private func clampHighestVisibleSystemIndex(prepared: PreparedLazyScoreRender) {
        visibleSystemTracker.clamp(to: prepared.availableSystemIndexRange)
    }

    private func visibleMeasureRange(for prepared: PreparedLazyScoreRender) -> Range<Int>? {
        guard let visibleSystemIndex = visibleSystemTracker.highestVisibleSystemIndex else { return nil }
        guard let availableSystemRange = prepared.availableSystemIndexRange else { return nil }
        let clampedVisibleSystemIndex = min(
            availableSystemRange.upperBound,
            max(availableSystemRange.lowerBound, visibleSystemIndex)
        )
        let lowerSystemIndex = max(
            availableSystemRange.lowerBound,
            clampedVisibleSystemIndex - renderBufferSystems
        )
        var minimumMeasureIndex = Int.max
        var maximumMeasureUpperBound = Int.min
        for systemIndex in lowerSystemIndex...clampedVisibleSystemIndex {
            guard let range = prepared.measureRangeBySystem[systemIndex] else { continue }
            minimumMeasureIndex = min(minimumMeasureIndex, range.lowerBound)
            maximumMeasureUpperBound = max(maximumMeasureUpperBound, range.upperBound)
        }
        guard minimumMeasureIndex != Int.max, maximumMeasureUpperBound > minimumMeasureIndex else {
            return nil
        }
        return minimumMeasureIndex..<maximumMeasureUpperBound
    }

    private func maybeExpandLazyMeasureWindow(
        score: Score,
        baseOptions: LayoutOptions,
        prepared: PreparedLazyScoreRender
    ) {
        guard baseOptions.measureRange == nil else { return }
        clampHighestVisibleSystemIndex(prepared: prepared)
        let total = totalMeasureCount(in: score)
        guard total > 0 else { return }
        guard let visibleRange = visibleMeasureRange(for: prepared) else { return }

        let currentRange = clampedMeasureRange(
            lazyMeasureRangeOverride ?? initialMeasureRange(for: score, baseOptions: baseOptions),
            totalMeasures: total
        ) ?? (0..<min(total, lazyMeasureWindowLength))
        if let expandedRange = LazyMeasureWindowing.expandedRangeIfNeeded(
            currentRange: currentRange,
            visibleRange: visibleRange,
            totalMeasures: total,
            windowLength: lazyMeasureWindowLength,
            threshold: lazyMeasureExpansionThreshold
        ) {
            lazyMeasureRangeOverride = expandedRange
        }
    }
}

public enum VexImageExportError: Error {
    case imageSnapshotUnavailable
    case pngEncodingFailed
    case unsupportedPlatform
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
public protocol PNGScoreRenderer {
    func renderPNGData(
        from laidOutScore: LaidOutScore,
        target: RenderTarget,
        scale: Double
    ) throws -> Data
}

@available(iOS 17.0, macOS 14.0, *)
extension VexFoundationRenderer: PNGScoreRenderer {
    @MainActor
    public func renderPNGData(
        from laidOutScore: LaidOutScore,
        target: RenderTarget = .view(identifier: "music-display-image-export"),
        scale: Double = 2.0
    ) throws -> Data {
        let renderPlan = makeRenderPlan(from: laidOutScore, target: target)
        let content = VexScoreView(laidOutScore: laidOutScore, target: target)
            .frame(width: max(1, renderPlan.canvasWidth), height: max(1, renderPlan.canvasHeight))
            .background(Color.white)
        let renderer = ImageRenderer(content: content)
        renderer.scale = max(1, scale)

        #if canImport(UIKit)
        guard let image = renderer.uiImage else {
            throw VexImageExportError.imageSnapshotUnavailable
        }
        guard let data = image.pngData() else {
            throw VexImageExportError.pngEncodingFailed
        }
        return data
        #elseif canImport(AppKit)
        guard let image = renderer.nsImage else {
            throw VexImageExportError.imageSnapshotUnavailable
        }
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw VexImageExportError.pngEncodingFailed
        }
        return pngData
        #else
        throw VexImageExportError.unsupportedPlatform
        #endif
    }
}
#endif
