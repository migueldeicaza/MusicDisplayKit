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

@available(iOS 17.0, macOS 14.0, *)
public struct VexScoreView: View {
    private let laidOutScore: LaidOutScore
    private let target: RenderTarget

    public init(laidOutScore: LaidOutScore, target: RenderTarget = .view(identifier: "music-display-view")) {
        self.laidOutScore = laidOutScore
        self.target = target
    }

    public init(laidOutScore: LaidOutScore, targetIdentifier: String) {
        self.init(laidOutScore: laidOutScore, target: .view(identifier: targetIdentifier))
    }

    public var body: some View {
        let renderPlan = VexFoundationRenderer().makeRenderPlan(from: laidOutScore, target: target)

        return VexCanvas(
            width: max(1, renderPlan.canvasWidth),
            height: max(1, renderPlan.canvasHeight)
        ) { context in
            context.clear()
            let renderer = VexFoundationRenderer(
                contextProvider: VexSwiftUICanvasContextProvider(context: context)
            )
            do {
                try renderer.render(laidOutScore, target: target)
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
                    var opts = layoutOptions
                    opts.pageWidth = max(200, geometry.size.width)
                    return opts
                }()
                if let laidOutScore = try? MusicLayoutEngine().layout(score: score, options: adjustedOptions) {
                    VexScoreView(laidOutScore: laidOutScore, target: target)
                } else {
                    Text("MusicDisplay layout failed")
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                        .padding(8)
                }
            }
        } else {
            if let laidOutScore = try? MusicLayoutEngine().layout(score: score, options: layoutOptions) {
                VexScoreView(laidOutScore: laidOutScore, target: target)
            } else {
                Text("MusicDisplay layout failed")
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
                    .padding(8)
            }
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
                if let laidOutScore = try? MusicLayoutEngine().layout(score: score, options: layoutOptions) {
                    VexScoreView(laidOutScore: laidOutScore, target: target)
                        .id("score-content")
                } else {
                    Text("MusicDisplay layout failed")
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                        .padding(8)
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
        ScrollView {
            if let laidOutScore = try? MusicLayoutEngine().layout(score: score, options: layoutOptions) {
                let renderPlan = VexFoundationRenderer().makeRenderPlan(from: laidOutScore, target: target)
                let systemGroups = groupSystemsByRow(renderPlan: renderPlan, laidOutScore: laidOutScore)
                LazyVStack(spacing: 0) {
                    ForEach(systemGroups, id: \.systemIndex) { group in
                        VexScoreView(laidOutScore: laidOutScore, target: target)
                            .frame(
                                width: max(1, renderPlan.canvasWidth),
                                height: max(1, group.height)
                            )
                            .clipped()
                            .id("system-\(group.systemIndex)")
                    }
                }
                .frame(width: max(1, renderPlan.canvasWidth))
            } else {
                Text("MusicDisplay layout failed")
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
                    .padding(8)
            }
        }
    }

    private struct SystemGroup: Identifiable {
        let systemIndex: Int
        let height: Double
        var id: Int { systemIndex }
    }

    private func groupSystemsByRow(renderPlan: VexRenderPlan, laidOutScore: LaidOutScore) -> [SystemGroup] {
        var groups: [Int: Double] = [:]
        for system in laidOutScore.systems {
            let bottom = system.frame.y + system.frame.height
            groups[system.systemIndex] = max(groups[system.systemIndex, default: 0], bottom)
        }
        let sortedIndices = groups.keys.sorted()
        var result: [SystemGroup] = []
        var prevBottom: Double = 0
        for idx in sortedIndices {
            let bottom = groups[idx] ?? 0
            let height = max(40, bottom - prevBottom)
            result.append(SystemGroup(systemIndex: idx, height: height))
            prevBottom = bottom
        }
        return result
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
