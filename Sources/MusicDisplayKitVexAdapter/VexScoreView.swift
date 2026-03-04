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

private struct LazySystemGroup: Identifiable, Equatable {
    let systemIndex: Int
    let top: Double
    let height: Double
    var id: Int { systemIndex }
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

private func makeLazySystemGroups(from laidOutScore: LaidOutScore) -> [LazySystemGroup] {
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

    // Reserve explicit vertical bleed so row-local clipping does not cut glyphs
    // that extend above/below staff bounds (clefs, time signatures, stems, etc.).
    let leadingBleed: Double = 28
    let minimumPreviousBottomGap: Double = 16
    let minimumCurrentTopGap: Double = 24
    let trailingBleed: Double = 40
    let minimumRowHeight: Double = 48

    var systemBoundaries: [Double] = []
    if sortedSystemIndices.count > 1 {
        systemBoundaries.reserveCapacity(sortedSystemIndices.count - 1)
        for index in 0..<(sortedSystemIndices.count - 1) {
            let previousSystemIndex = sortedSystemIndices[index]
            let nextSystemIndex = sortedSystemIndices[index + 1]
            guard let previousBounds = verticalBoundsBySystemIndex[previousSystemIndex],
                  let nextBounds = verticalBoundsBySystemIndex[nextSystemIndex] else {
                continue
            }

            let gapStart = previousBounds.maximumY
            let gapEnd = nextBounds.minimumY
            guard gapEnd > gapStart else {
                systemBoundaries.append(gapStart)
                continue
            }

            let gap = gapEnd - gapStart
            let minimumCombinedGap = minimumPreviousBottomGap + minimumCurrentTopGap
            let boundary: Double
            if gap >= minimumCombinedGap {
                boundary = gapEnd - minimumCurrentTopGap
            } else {
                boundary = gapStart + (gap * 0.5)
            }
            systemBoundaries.append(boundary)
        }
    }

    var groups: [LazySystemGroup] = []
    var previousBottom: Double?
    for (offset, systemIndex) in sortedSystemIndices.enumerated() {
        guard let bounds = verticalBoundsBySystemIndex[systemIndex] else { continue }
        let rawTop: Double
        if offset == 0 {
            rawTop = bounds.minimumY - leadingBleed
        } else {
            rawTop = systemBoundaries[offset - 1]
        }

        let rawBottom: Double
        if offset < systemBoundaries.count {
            rawBottom = max(bounds.maximumY + minimumPreviousBottomGap, systemBoundaries[offset])
        } else {
            rawBottom = bounds.maximumY + trailingBleed
        }

        let top: Double
        if let previousBottom {
            top = max(previousBottom, rawTop)
        } else {
            top = rawTop
        }
        let bottom = max(top + minimumRowHeight, max(bounds.maximumY, rawBottom))
        let height = max(minimumRowHeight, bottom - top)
        groups.append(
            LazySystemGroup(
                systemIndex: systemIndex,
                top: top,
                height: height
            )
        )
        previousBottom = bottom
    }
    return groups
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
        let systemGroups = makeLazySystemGroups(from: laidOutScore)
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
            LazyVStack(spacing: 0) {
                ForEach(prepared.systems) { system in
                    systemRow(system, prepared: prepared)
                }
            }
            .frame(width: max(1, prepared.renderPlan.canvasWidth))
        case .failure:
            LayoutFailureView()
        }
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
