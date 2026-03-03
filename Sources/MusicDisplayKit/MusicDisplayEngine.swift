import Foundation
import MusicDisplayKitLayout
import MusicDisplayKitModel
import MusicDisplayKitMusicXML
import MusicDisplayKitVexAdapter
#if canImport(SwiftUI)
import SwiftUI
#endif

public enum MusicDisplayEngineError: Error {
    case noScoreLoaded
    case undecodableInputData
    case rendererDoesNotSupportImageExport
}

public final class MusicDisplayEngine {
    private let parser: ScoreParser
    private let loaderOptions: MusicXMLLoaderOptions
    private let loaderDataFetcher: any MusicXMLDataFetching
    private let layoutEngine: ScoreLayoutEngine
    private let renderer: ScoreRenderer

    private var loadedScore: Score?

    /// Cursor for navigating through the loaded score.
    public var cursor: ScoreCursor = ScoreCursor()

    /// The graphical model populated after rendering (available for hit testing and cursor).
    public private(set) var graphicalScore: GraphicalScore?

    public init(
        parser: ScoreParser = MusicXMLParser(),
        loaderOptions: MusicXMLLoaderOptions = MusicXMLLoaderOptions(),
        loaderDataFetcher: any MusicXMLDataFetching = FoundationMusicXMLDataFetcher(),
        layoutEngine: ScoreLayoutEngine = MusicLayoutEngine(),
        renderer: ScoreRenderer = VexFoundationRenderer()
    ) {
        self.parser = parser
        self.loaderOptions = loaderOptions
        self.loaderDataFetcher = loaderDataFetcher
        self.layoutEngine = layoutEngine
        self.renderer = renderer
    }

    public func load(xml: String) throws {
        try load(source: .xmlString(xml))
    }

    public func load(data: Data, pathExtension: String? = nil) throws {
        try load(source: .data(data, pathExtension: pathExtension))
    }

    public func load(fileURL: URL) throws {
        try load(source: .fileURL(fileURL))
    }

    public func load(source: MusicXMLSource) throws {
        let sheetReader = MusicSheetReader(
            parser: parser,
            loaderOptions: loaderOptions,
            loaderDataFetcher: loaderDataFetcher
        )
        do {
            loadedScore = try sheetReader.read(from: source)
        } catch MusicXMLLoaderError.undecodableInputData {
            throw MusicDisplayEngineError.undecodableInputData
        }
    }

    public func render(target: RenderTarget, options: LayoutOptions = LayoutOptions()) throws {
        guard let loadedScore else {
            throw MusicDisplayEngineError.noScoreLoaded
        }

        let laidOut = try layoutEngine.layout(score: loadedScore, options: options)
        try renderer.render(laidOut, target: target)
    }

    /// Renders the score to an SVG string.
    public func renderSVG(options: LayoutOptions = LayoutOptions()) throws -> String {
        guard let loadedScore else {
            throw MusicDisplayEngineError.noScoreLoaded
        }
        guard let vexRenderer = renderer as? VexFoundationRenderer else {
            throw MusicDisplayEngineError.rendererDoesNotSupportImageExport
        }
        let laidOut = try layoutEngine.layout(score: loadedScore, options: options)
        return try vexRenderer.renderSVG(laidOut)
    }

    /// Renders the score and builds the graphical model for hit testing / cursor.
    public func renderWithGraphicalModel(
        target: RenderTarget,
        options: LayoutOptions = LayoutOptions()
    ) throws {
        guard let loadedScore else {
            throw MusicDisplayEngineError.noScoreLoaded
        }
        let laidOut = try layoutEngine.layout(score: loadedScore, options: options)
        try renderer.render(laidOut, target: target)

        let calculator = ScoreCalculator()
        graphicalScore = calculator.populateGraphicalModel(score: loadedScore, laidOutScore: laidOut)
    }

    #if canImport(SwiftUI)
    @available(iOS 17.0, macOS 14.0, *)
    @MainActor
    public func renderPNGData(
        target: RenderTarget = .view(identifier: "music-display-image-export"),
        options: LayoutOptions = LayoutOptions(),
        scale: Double = 2.0
    ) throws -> Data {
        guard let loadedScore else {
            throw MusicDisplayEngineError.noScoreLoaded
        }
        guard let imageRenderer = renderer as? any PNGScoreRenderer else {
            throw MusicDisplayEngineError.rendererDoesNotSupportImageExport
        }
        let laidOut = try layoutEngine.layout(score: loadedScore, options: options)
        return try imageRenderer.renderPNGData(from: laidOut, target: target, scale: scale)
    }
    #endif

    #if canImport(CoreGraphics)
    /// Renders the score to PDF data using CoreGraphics.
    public func renderPDF(options: LayoutOptions = LayoutOptions()) throws -> Data {
        guard let loadedScore else {
            throw MusicDisplayEngineError.noScoreLoaded
        }
        guard let vexRenderer = renderer as? VexFoundationRenderer else {
            throw MusicDisplayEngineError.rendererDoesNotSupportImageExport
        }
        let laidOut = try layoutEngine.layout(score: loadedScore, options: options)
        return try VexPDFRenderer.renderPDF(score: laidOut, renderer: vexRenderer)
    }
    #endif
}
