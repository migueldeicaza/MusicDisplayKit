import MusicDisplayKitModel

public struct LyricWordEvent: Equatable, Sendable {
    public var partIndex: Int
    public var partID: String
    public var lyricNumber: Int
    public var voice: Int
    public var staff: Int?
    public var startMeasureIndex: Int
    public var startMeasureNumber: Int
    public var startNoteIndex: Int
    public var endMeasureIndex: Int
    public var endMeasureNumber: Int
    public var endNoteIndex: Int
    public var text: String?
    public var hasExtension: Bool
    public var usesHyphen: Bool
    public var spansMultipleMeasures: Bool

    public init(
        partIndex: Int,
        partID: String,
        lyricNumber: Int,
        voice: Int,
        staff: Int?,
        startMeasureIndex: Int,
        startMeasureNumber: Int,
        startNoteIndex: Int,
        endMeasureIndex: Int,
        endMeasureNumber: Int,
        endNoteIndex: Int,
        text: String?,
        hasExtension: Bool,
        usesHyphen: Bool,
        spansMultipleMeasures: Bool
    ) {
        self.partIndex = partIndex
        self.partID = partID
        self.lyricNumber = lyricNumber
        self.voice = voice
        self.staff = staff
        self.startMeasureIndex = startMeasureIndex
        self.startMeasureNumber = startMeasureNumber
        self.startNoteIndex = startNoteIndex
        self.endMeasureIndex = endMeasureIndex
        self.endMeasureNumber = endMeasureNumber
        self.endNoteIndex = endNoteIndex
        self.text = text
        self.hasExtension = hasExtension
        self.usesHyphen = usesHyphen
        self.spansMultipleMeasures = spansMultipleMeasures
    }
}

public struct LyricsGenerator: Sendable {
    private struct WordKey: Hashable {
        var number: Int
        var voice: Int
        var staff: Int?
    }

    private struct Position {
        var measureIndex: Int
        var measureNumber: Int
        var noteIndex: Int
    }

    private struct WordBuilder {
        var start: Position
        var end: Position
        var text: String?
        var hasExtension: Bool
        var usesHyphen: Bool

        mutating func appendText(_ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return
            }
            if let existing = text {
                text = existing + value
            } else {
                text = value
            }
        }
    }

    public init() {}

    public func generate(from score: Score) -> [LyricWordEvent] {
        var output: [LyricWordEvent] = []

        for (partIndex, part) in score.parts.enumerated() {
            var openByKey: [WordKey: WordBuilder] = [:]

            for (measureIndex, measure) in part.measures.enumerated() {
                for noteIndex in measure.noteEvents.indices {
                    let note = measure.noteEvents[noteIndex]
                    let position = Position(
                        measureIndex: measureIndex,
                        measureNumber: measure.number,
                        noteIndex: noteIndex
                    )

                    for lyric in note.lyrics {
                        let number = max(lyric.number, 1)
                        let key = WordKey(number: number, voice: note.voice, staff: note.staff)
                        let syllabic = lyric.syllabic?.lowercased()
                        let text = lyric.text

                        switch syllabic {
                        case "begin":
                            if let existing = openByKey.removeValue(forKey: key) {
                                output.append(
                                    buildEvent(
                                        partIndex: partIndex,
                                        partID: part.id,
                                        key: key,
                                        builder: existing
                                    )
                                )
                            }
                            var builder = WordBuilder(
                                start: position,
                                end: position,
                                text: nil,
                                hasExtension: lyric.extend,
                                usesHyphen: true
                            )
                            builder.appendText(text)
                            openByKey[key] = builder

                        case "middle":
                            var builder = openByKey[key] ?? WordBuilder(
                                start: position,
                                end: position,
                                text: nil,
                                hasExtension: false,
                                usesHyphen: true
                            )
                            builder.end = position
                            builder.appendText(text)
                            builder.hasExtension = builder.hasExtension || lyric.extend
                            builder.usesHyphen = true
                            openByKey[key] = builder

                        case "end":
                            var builder = openByKey[key] ?? WordBuilder(
                                start: position,
                                end: position,
                                text: nil,
                                hasExtension: false,
                                usesHyphen: false
                            )
                            builder.end = position
                            builder.appendText(text)
                            builder.hasExtension = builder.hasExtension || lyric.extend
                            output.append(
                                buildEvent(
                                    partIndex: partIndex,
                                    partID: part.id,
                                    key: key,
                                    builder: builder
                                )
                            )
                            openByKey.removeValue(forKey: key)

                        default:
                            if let existing = openByKey.removeValue(forKey: key) {
                                output.append(
                                    buildEvent(
                                        partIndex: partIndex,
                                        partID: part.id,
                                        key: key,
                                        builder: existing
                                    )
                                )
                            }
                            if text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || lyric.extend {
                                var builder = WordBuilder(
                                    start: position,
                                    end: position,
                                    text: nil,
                                    hasExtension: lyric.extend,
                                    usesHyphen: false
                                )
                                builder.appendText(text)
                                output.append(
                                    buildEvent(
                                        partIndex: partIndex,
                                        partID: part.id,
                                        key: key,
                                        builder: builder
                                    )
                                )
                            }
                        }
                    }
                }
            }

            for (key, builder) in openByKey {
                output.append(
                    buildEvent(
                        partIndex: partIndex,
                        partID: part.id,
                        key: key,
                        builder: builder
                    )
                )
            }
        }

        return output.sorted { lhs, rhs in
            if lhs.partIndex != rhs.partIndex {
                return lhs.partIndex < rhs.partIndex
            }
            if lhs.startMeasureIndex != rhs.startMeasureIndex {
                return lhs.startMeasureIndex < rhs.startMeasureIndex
            }
            if lhs.startNoteIndex != rhs.startNoteIndex {
                return lhs.startNoteIndex < rhs.startNoteIndex
            }
            if lhs.lyricNumber != rhs.lyricNumber {
                return lhs.lyricNumber < rhs.lyricNumber
            }
            return lhs.voice < rhs.voice
        }
    }

    private func buildEvent(
        partIndex: Int,
        partID: String,
        key: WordKey,
        builder: WordBuilder
    ) -> LyricWordEvent {
        LyricWordEvent(
            partIndex: partIndex,
            partID: partID,
            lyricNumber: key.number,
            voice: key.voice,
            staff: key.staff,
            startMeasureIndex: builder.start.measureIndex,
            startMeasureNumber: builder.start.measureNumber,
            startNoteIndex: builder.start.noteIndex,
            endMeasureIndex: builder.end.measureIndex,
            endMeasureNumber: builder.end.measureNumber,
            endNoteIndex: builder.end.noteIndex,
            text: builder.text,
            hasExtension: builder.hasExtension,
            usesHyphen: builder.usesHyphen,
            spansMultipleMeasures: builder.start.measureIndex != builder.end.measureIndex
        )
    }
}
