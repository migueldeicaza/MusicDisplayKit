import Foundation
import MusicDisplayKitLayout
import MusicDisplayKitModel
import MusicDisplayKitMusicXML
import MusicDisplayKitVexAdapter

public enum MusicDisplayEngineError: Error {
    case noScoreLoaded
    case undecodableInputData
}

public final class MusicDisplayEngine {
    private let parser: ScoreParser
    private let layoutEngine: ScoreLayoutEngine
    private let renderer: ScoreRenderer

    private var loadedScore: Score?

    public init(
        parser: ScoreParser = MusicXMLParser(),
        layoutEngine: ScoreLayoutEngine = MusicLayoutEngine(),
        renderer: ScoreRenderer = VexFoundationRenderer()
    ) {
        self.parser = parser
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
        let sheetReader = MusicSheetReader(parser: parser)
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
}
