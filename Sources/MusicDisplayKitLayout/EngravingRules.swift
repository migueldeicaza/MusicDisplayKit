import MusicDisplayKitCore

/// Structured configuration for engraving/spacing constants used by layout sub-calculators.
/// Replaces hard-coded values scattered across the rendering pipeline.
public struct EngravingRules: Equatable, Sendable {

    // MARK: - Note Spacing

    /// Multiplier applied to duration-based note spacing (1.0 = default).
    public var noteSpacingMultiplier: Double

    /// Minimum horizontal distance between adjacent note columns (points).
    public var minNoteDistance: Double

    /// Minimum distance from a note to the left barline (points).
    public var minNoteToBarlineDistance: Double

    // MARK: - Accidentals

    /// Horizontal padding between accidentals when stacking (points).
    public var accidentalPadding: Double

    /// If true, show courtesy accidentals for re-stated pitches.
    public var showCourtesyAccidentals: Bool

    // MARK: - Collision Avoidance

    /// Vertical padding between elements placed via skyline/bottomline (points).
    public var collisionPadding: Double

    /// Vertical padding above staff for above-staff elements (dynamics, chord symbols).
    public var aboveStaffPadding: Double

    /// Vertical padding below staff for below-staff elements (lyrics).
    public var belowStaffPadding: Double

    /// Resolution of skyline/bottomline sampling (points per sample).
    public var skylineResolution: Double

    // MARK: - Lyrics

    /// Vertical spacing between lyric verse lines (points).
    public var lyricVerseSpacing: Double

    /// Default font size for lyrics (points).
    public var lyricFontSize: Double

    // MARK: - Chord Symbols

    /// Default font size for chord symbols (points).
    public var chordSymbolFontSize: Double

    // MARK: - Dynamics / Expressions

    /// Default font size for dynamic markings (points).
    public var dynamicFontSize: Double

    // MARK: - System Layout

    /// Penalty for lines shorter than this fraction of the usable width (0.0–1.0).
    public var systemFillThreshold: Double

    /// Penalty weight for orphan measures (single measure on last system).
    public var orphanMeasurePenalty: Double

    /// Reward weight for breaking at XML-hinted positions.
    public var breakHintReward: Double

    // MARK: - Visibility

    /// Show tempo markings.
    public var showTempoMarks: Bool

    /// Show rehearsal marks.
    public var showRehearsalMarks: Bool

    /// Show measure numbers.
    public var showMeasureNumbers: Bool

    /// Show part names.
    public var showPartNames: Bool

    // MARK: - Init

    public init(
        noteSpacingMultiplier: Double = 1.0,
        minNoteDistance: Double = 8,
        minNoteToBarlineDistance: Double = 6,
        accidentalPadding: Double = 3,
        showCourtesyAccidentals: Bool = false,
        collisionPadding: Double = 4,
        aboveStaffPadding: Double = 6,
        belowStaffPadding: Double = 8,
        skylineResolution: Double = 2,
        lyricVerseSpacing: Double = 14,
        lyricFontSize: Double = 11,
        chordSymbolFontSize: Double = 12,
        dynamicFontSize: Double = 12,
        systemFillThreshold: Double = 0.6,
        orphanMeasurePenalty: Double = 50,
        breakHintReward: Double = 20,
        showTempoMarks: Bool = true,
        showRehearsalMarks: Bool = true,
        showMeasureNumbers: Bool = true,
        showPartNames: Bool = true
    ) {
        self.noteSpacingMultiplier = noteSpacingMultiplier
        self.minNoteDistance = minNoteDistance
        self.minNoteToBarlineDistance = minNoteToBarlineDistance
        self.accidentalPadding = accidentalPadding
        self.showCourtesyAccidentals = showCourtesyAccidentals
        self.collisionPadding = collisionPadding
        self.aboveStaffPadding = aboveStaffPadding
        self.belowStaffPadding = belowStaffPadding
        self.skylineResolution = skylineResolution
        self.lyricVerseSpacing = lyricVerseSpacing
        self.lyricFontSize = lyricFontSize
        self.chordSymbolFontSize = chordSymbolFontSize
        self.dynamicFontSize = dynamicFontSize
        self.systemFillThreshold = systemFillThreshold
        self.orphanMeasurePenalty = orphanMeasurePenalty
        self.breakHintReward = breakHintReward
        self.showTempoMarks = showTempoMarks
        self.showRehearsalMarks = showRehearsalMarks
        self.showMeasureNumbers = showMeasureNumbers
        self.showPartNames = showPartNames
    }

    /// Default engraving rules.
    public static var `default`: EngravingRules { EngravingRules() }
}
