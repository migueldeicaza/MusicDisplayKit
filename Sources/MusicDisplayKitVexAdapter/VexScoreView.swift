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

private struct PreparedLazyScoreRender {
    let renderPlan: VexRenderPlan
    let systemGroups: [LazySystemGroup]
    let systemRenderPlansByIndex: [Int: VexRenderPlan]
}

private func makeLazySystemGroups(from laidOutScore: LaidOutScore) -> [LazySystemGroup] {
    var bottomsBySystemIndex: [Int: Double] = [:]
    for system in laidOutScore.systems {
        let bottom = system.frame.y + system.frame.height
        bottomsBySystemIndex[system.systemIndex] = max(
            bottomsBySystemIndex[system.systemIndex, default: 0],
            bottom
        )
    }

    var groups: [LazySystemGroup] = []
    var previousBottom: Double = 0
    for systemIndex in bottomsBySystemIndex.keys.sorted() {
        let bottom = bottomsBySystemIndex[systemIndex] ?? previousBottom
        let top = previousBottom
        let height = max(40, bottom - top)
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

private func makeLazySystemRenderPlans(
    from renderPlan: VexRenderPlan,
    systemGroups: [LazySystemGroup]
) -> [Int: VexRenderPlan] {
    Dictionary(uniqueKeysWithValues: systemGroups.map { group in
        (group.systemIndex, renderPlan.systemSlice(for: group))
    })
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
        let prepared = PreparedLazyScoreRender(
            renderPlan: renderPlan,
            systemGroups: systemGroups,
            systemRenderPlansByIndex: makeLazySystemRenderPlans(
                from: renderPlan,
                systemGroups: systemGroups
            )
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
                .filter { $0.startSystemIndex == systemIndex && $0.endSystemIndex == systemIndex },
            barlineConnectors: barlineConnectors
                .filter { $0.startSystemIndex == systemIndex && $0.endSystemIndex == systemIndex }
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
                ForEach(prepared.systemGroups) { group in
                    let systemRenderPlan = prepared.systemRenderPlansByIndex[group.systemIndex]
                        ?? prepared.renderPlan.systemSlice(for: group)
                    VexCanvas(
                        width: max(1, prepared.renderPlan.canvasWidth),
                        height: max(1, group.height)
                    ) { context in
                        context.clear()
                        do {
                            // Factory.draw() resets the factory queue, so executions are single-use.
                            let execution = VexFoundationRenderer().executeRenderPlan(systemRenderPlan)
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
                    .onAppear {
                        let didAdvanceVisibleRange = visibleSystemTracker.recordVisibleSystem(group.systemIndex)
                        if didAdvanceVisibleRange,
                           case .score(let score, let layoutOptions) = source {
                            maybeExpandLazyMeasureWindow(
                                score: score,
                                baseOptions: layoutOptions,
                                prepared: prepared
                            )
                        }
                    }
                }
            }
            .frame(width: max(1, prepared.renderPlan.canvasWidth))
        case .failure:
            LayoutFailureView()
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
        guard let minimumSystemIndex = prepared.systemGroups.map(\.systemIndex).min(),
              let maximumSystemIndex = prepared.systemGroups.map(\.systemIndex).max() else {
            visibleSystemTracker.clamp(to: nil)
            return
        }
        visibleSystemTracker.clamp(to: minimumSystemIndex...maximumSystemIndex)
    }

    private func visibleMeasureRange(for renderPlan: VexRenderPlan) -> Range<Int>? {
        guard let visibleSystemIndex = visibleSystemTracker.highestVisibleSystemIndex else { return nil }
        let maximumSystemIndex = renderPlan.measures.map(\.systemIndex).max() ?? visibleSystemIndex
        let clampedVisibleSystemIndex = min(maximumSystemIndex, max(0, visibleSystemIndex))
        let lowerSystemIndex = max(0, clampedVisibleSystemIndex - renderBufferSystems)
        var minimumMeasureIndex = Int.max
        var maximumMeasureIndex = Int.min
        for measurePlan in renderPlan.measures
        where measurePlan.systemIndex >= lowerSystemIndex
            && measurePlan.systemIndex <= clampedVisibleSystemIndex {
            minimumMeasureIndex = min(minimumMeasureIndex, measurePlan.measureIndexInPart)
            maximumMeasureIndex = max(maximumMeasureIndex, measurePlan.measureIndexInPart)
        }
        guard minimumMeasureIndex != Int.max, maximumMeasureIndex >= minimumMeasureIndex else {
            return nil
        }
        return minimumMeasureIndex..<(maximumMeasureIndex + 1)
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
        guard let visibleRange = visibleMeasureRange(for: prepared.renderPlan) else { return }

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
