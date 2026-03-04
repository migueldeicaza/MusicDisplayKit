import MusicDisplayKitLayout
import MusicDisplayKitModel

#if canImport(SwiftUI)
import SwiftUI
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
    let laidOutScore: LaidOutScore
    let target: RenderTarget
}

private struct LazyScoreInput: Equatable {
    let score: Score
    let layoutOptions: LayoutOptions
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

@MainActor
private final class ScoreLayoutCache: ObservableObject {
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
private final class ScoreRenderCache: ObservableObject {
    private var cachedInput: ScoreRenderInput?
    private var cachedRender: PreparedScoreRender?

    func resolve(laidOutScore: LaidOutScore, target: RenderTarget) -> PreparedScoreRender {
        let input = ScoreRenderInput(laidOutScore: laidOutScore, target: target)
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
private final class LazyScoreRenderCache: ObservableObject {
    private var cachedInput: LazyScoreInput?
    private var cachedPreparedResult: Result<PreparedLazyScoreRender, Error>?
    private var cachedSystemPlansBySystemIndex: [Int: VexRenderPlan] = [:]

    func resolve(
        score: Score,
        layoutOptions: LayoutOptions,
        target: RenderTarget
    ) -> Result<PreparedLazyScoreRender, Error> {
        let input = LazyScoreInput(score: score, layoutOptions: layoutOptions, target: target)
        if let cachedInput, cachedInput == input, let cachedPreparedResult {
            return cachedPreparedResult
        }

        let preparedResult = Result {
            let laidOutScore = try MusicLayoutEngine().layout(score: score, options: layoutOptions)
            let renderPlan = VexFoundationRenderer().makeRenderPlan(from: laidOutScore, target: target)
            let systemGroups = makeLazySystemGroups(from: laidOutScore)
            return PreparedLazyScoreRender(
                renderPlan: renderPlan,
                systemGroups: systemGroups
            )
        }

        cachedInput = input
        cachedPreparedResult = preparedResult
        cachedSystemPlansBySystemIndex.removeAll()
        return preparedResult
    }

    func systemRenderPlan(for group: LazySystemGroup, in renderPlan: VexRenderPlan) -> VexRenderPlan {
        if let cached = cachedSystemPlansBySystemIndex[group.systemIndex] {
            return cached
        }

        let slicedPlan = renderPlan.systemSlice(for: group)
        cachedSystemPlansBySystemIndex[group.systemIndex] = slicedPlan
        return slicedPlan
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
    @StateObject private var renderCache = ScoreRenderCache()

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
    @StateObject private var layoutCache = ScoreLayoutCache()

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
                let adjustedOptions: LayoutOptions = {
                    var options = layoutOptions
                    options.pageWidth = max(200, geometry.size.width)
                    return options
                }()
                content(for: adjustedOptions)
            }
        } else {
            content(for: layoutOptions)
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
    @StateObject private var layoutCache = ScoreLayoutCache()

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
    private let score: Score
    private let layoutOptions: LayoutOptions
    private let target: RenderTarget
    @StateObject private var lazyRenderCache = LazyScoreRenderCache()

    public init(
        score: Score,
        layoutOptions: LayoutOptions = LayoutOptions(),
        target: RenderTarget = .view(identifier: "music-display-view")
    ) {
        self.score = score
        self.layoutOptions = layoutOptions
        self.target = target
    }

    public var body: some View {
        let preparedResult = lazyRenderCache.resolve(
            score: score,
            layoutOptions: layoutOptions,
            target: target
        )

        ScrollView {
            switch preparedResult {
            case .success(let prepared):
                LazyVStack(spacing: 0) {
                    ForEach(prepared.systemGroups) { group in
                        let systemRenderPlan = lazyRenderCache.systemRenderPlan(for: group, in: prepared.renderPlan)

                        VexCanvas(
                            width: max(1, prepared.renderPlan.canvasWidth),
                            height: max(1, group.height)
                        ) { context in
                            context.clear()
                            do {
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
                    }
                }
                .frame(width: max(1, prepared.renderPlan.canvasWidth))
            case .failure:
                LayoutFailureView()
            }
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
