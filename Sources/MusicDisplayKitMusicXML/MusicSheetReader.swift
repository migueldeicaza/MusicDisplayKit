import Foundation
import MusicDisplayKitCore
import MusicDisplayKitModel

public protocol AfterScoreReadingModule {
    func process(score: inout Score) throws
}

public protocol MusicSheetReading {
    func read(from source: MusicXMLSource) throws -> Score
    func read(xml: String) throws -> Score
    func read(data: Data, pathExtension: String?) throws -> Score
    func read(fileURL: URL) throws -> Score
    func readWithTraversal(from source: MusicXMLSource) throws -> MusicSheetReadResult
}

public struct MusicSheetReadResult: Equatable, Sendable {
    public var score: Score
    public var instrumentMeasureVisits: [InstrumentMeasureVisit]
    public var voiceMeasures: [VoiceMeasureData]
    public var chordSymbols: [ChordSymbolEvent]
    public var articulationEvents: [ArticulationEvent]
    public var lyricWordEvents: [LyricWordEvent]
    public var expressionEvents: [ExpressionEvent]
    public var slurEvents: [SlurEvent]
    public var tempoTimelineEvents: [TempoTimelineEvent]

    public init(
        score: Score,
        instrumentMeasureVisits: [InstrumentMeasureVisit],
        voiceMeasures: [VoiceMeasureData],
        chordSymbols: [ChordSymbolEvent],
        articulationEvents: [ArticulationEvent],
        lyricWordEvents: [LyricWordEvent],
        expressionEvents: [ExpressionEvent],
        slurEvents: [SlurEvent],
        tempoTimelineEvents: [TempoTimelineEvent]
    ) {
        self.score = score
        self.instrumentMeasureVisits = instrumentMeasureVisits
        self.voiceMeasures = voiceMeasures
        self.chordSymbols = chordSymbols
        self.articulationEvents = articulationEvents
        self.lyricWordEvents = lyricWordEvents
        self.expressionEvents = expressionEvents
        self.slurEvents = slurEvents
        self.tempoTimelineEvents = tempoTimelineEvents
    }
}

public struct MusicSheetReader: MusicSheetReading {
    private let loader: MusicXMLLoader
    private let instrumentReader: InstrumentReader
    private let voiceGenerator: VoiceGenerator
    private let chordSymbolGenerator: ChordSymbolGenerator
    private let articulationGenerator: ArticulationGenerator
    private let lyricsGenerator: LyricsGenerator
    private let expressionGenerator: ExpressionGenerator
    private let slurGenerator: SlurGenerator
    private let tempoTimelineGenerator: TempoTimelineGenerator
    private let afterReadingModules: [any AfterScoreReadingModule]

    public init(
        parser: ScoreParser = MusicXMLParser(),
        instrumentReader: InstrumentReader = InstrumentReader(),
        voiceGenerator: VoiceGenerator = VoiceGenerator(),
        chordSymbolGenerator: ChordSymbolGenerator = ChordSymbolGenerator(),
        articulationGenerator: ArticulationGenerator = ArticulationGenerator(),
        lyricsGenerator: LyricsGenerator = LyricsGenerator(),
        expressionGenerator: ExpressionGenerator = ExpressionGenerator(),
        slurGenerator: SlurGenerator = SlurGenerator(),
        tempoTimelineGenerator: TempoTimelineGenerator = TempoTimelineGenerator(),
        afterReadingModules: [any AfterScoreReadingModule] = []
    ) {
        self.loader = MusicXMLLoader(parser: parser)
        self.instrumentReader = instrumentReader
        self.voiceGenerator = voiceGenerator
        self.chordSymbolGenerator = chordSymbolGenerator
        self.articulationGenerator = articulationGenerator
        self.lyricsGenerator = lyricsGenerator
        self.expressionGenerator = expressionGenerator
        self.slurGenerator = slurGenerator
        self.tempoTimelineGenerator = tempoTimelineGenerator
        self.afterReadingModules = afterReadingModules
    }

    public func read(from source: MusicXMLSource) throws -> Score {
        let result = try readWithTraversal(from: source)
        return result.score
    }

    public func readWithTraversal(from source: MusicXMLSource) throws -> MusicSheetReadResult {
        var score = try loader.loadScore(from: source)
        for module in afterReadingModules {
            try module.process(score: &score)
        }
        let visits = instrumentReader.readMeasureVisits(from: score)
        let voiceMeasures = voiceGenerator.generate(from: score)
        let chordSymbols = chordSymbolGenerator.generate(from: score)
        let articulationEvents = articulationGenerator.generate(from: score)
        let lyricWordEvents = lyricsGenerator.generate(from: score)
        let expressionEvents = expressionGenerator.generate(from: score)
        let slurEvents = slurGenerator.generate(from: score)
        let tempoTimelineEvents = tempoTimelineGenerator.generate(from: score)
        return MusicSheetReadResult(
            score: score,
            instrumentMeasureVisits: visits,
            voiceMeasures: voiceMeasures,
            chordSymbols: chordSymbols,
            articulationEvents: articulationEvents,
            lyricWordEvents: lyricWordEvents,
            expressionEvents: expressionEvents,
            slurEvents: slurEvents,
            tempoTimelineEvents: tempoTimelineEvents
        )
    }

    public func read(xml: String) throws -> Score {
        try read(from: .xmlString(xml))
    }

    public func read(data: Data, pathExtension: String? = nil) throws -> Score {
        try read(from: .data(data, pathExtension: pathExtension))
    }

    public func read(fileURL: URL) throws -> Score {
        try read(from: .fileURL(fileURL))
    }
}
