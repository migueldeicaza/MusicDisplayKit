import MusicDisplayKitModel

public struct ChordSymbolEvent: Equatable, Sendable {
    public var partIndex: Int
    public var partID: String
    public var measureIndex: Int
    public var measureNumber: Int
    public var onsetDivisions: Int
    public var staff: Int?
    public var displayText: String
    public var source: HarmonyEvent

    public init(
        partIndex: Int,
        partID: String,
        measureIndex: Int,
        measureNumber: Int,
        onsetDivisions: Int,
        staff: Int?,
        displayText: String,
        source: HarmonyEvent
    ) {
        self.partIndex = partIndex
        self.partID = partID
        self.measureIndex = measureIndex
        self.measureNumber = measureNumber
        self.onsetDivisions = onsetDivisions
        self.staff = staff
        self.displayText = displayText
        self.source = source
    }
}

public struct ChordSymbolGenerator: Sendable {
    public init() {}

    public func generate(from score: Score) -> [ChordSymbolEvent] {
        var output: [ChordSymbolEvent] = []

        for (partIndex, part) in score.parts.enumerated() {
            for (measureIndex, measure) in part.measures.enumerated() {
                for harmony in measure.harmonyEvents {
                    if harmony.printObject == false {
                        continue
                    }
                    guard let display = formatHarmony(harmony) else {
                        continue
                    }
                    output.append(
                        ChordSymbolEvent(
                            partIndex: partIndex,
                            partID: part.id,
                            measureIndex: measureIndex,
                            measureNumber: measure.number,
                            onsetDivisions: harmony.onsetDivisions,
                            staff: harmony.staff,
                            displayText: display,
                            source: harmony
                        )
                    )
                }
            }
        }

        return output
    }

    private func formatHarmony(_ harmony: HarmonyEvent) -> String? {
        if let noChordText = formatNoChord(kind: harmony.kind, explicitText: harmony.kindText) {
            return noChordText
        }

        let root = formatPitch(step: harmony.rootStep, alter: harmony.rootAlter)
            ?? formatNumeralRoot(root: harmony.numeralRoot, alter: harmony.numeralAlter)
        guard let root else {
            return nil
        }

        let kindAndDegrees = resolveKindAndDegrees(
            kind: harmony.kind,
            explicitText: harmony.kindText,
            degrees: harmony.degrees
        )
        let kindSuffix = kindAndDegrees.kindSuffix
        let degreesSuffix = formatDegrees(kindAndDegrees.degrees)

        var text = root + kindSuffix + degreesSuffix

        if let bass = formatPitch(step: harmony.bassStep, alter: harmony.bassAlter) {
            text += "/\(bass)"
        }

        return text
    }

    private func resolveKindAndDegrees(
        kind: String?,
        explicitText: String?,
        degrees: [HarmonyDegree]
    ) -> (kindSuffix: String, degrees: [HarmonyDegree]) {
        if let explicit = explicitText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty {
            return (kindSuffix: explicit, degrees: degrees)
        }

        let normalized = normalizedKind(kind)
        var remainingDegrees = degrees
        var kindSuffix = formatKind(kind: kind, explicitText: nil)

        switch normalized {
        case "suspended-fourth":
            for (degreeValue, alias) in [(7, "7sus4"), (9, "9sus4"), (11, "11sus4"), (13, "13sus4")] {
                if consumeDegree(&remainingDegrees, type: .add, value: degreeValue) {
                    kindSuffix = alias
                }
            }
        case "suspended-second":
            for (degreeValue, alias) in [(7, "7sus2"), (9, "9sus2"), (11, "11sus2"), (13, "13sus2")] {
                if consumeDegree(&remainingDegrees, type: .add, value: degreeValue) {
                    kindSuffix = alias
                }
            }
        case "dominant":
            if hasDegree(remainingDegrees, type: .add, value: 4),
               hasDegree(remainingDegrees, type: .subtract, value: 3) {
                _ = consumeDegree(&remainingDegrees, type: .add, value: 4)
                _ = consumeDegree(&remainingDegrees, type: .subtract, value: 3)
                kindSuffix = "7sus4"
            } else if hasDegree(remainingDegrees, type: .add, value: 2),
                      hasDegree(remainingDegrees, type: .subtract, value: 3) {
                _ = consumeDegree(&remainingDegrees, type: .add, value: 2)
                _ = consumeDegree(&remainingDegrees, type: .subtract, value: 3)
                kindSuffix = "7sus2"
            }
        case "dominant-ninth":
            if hasDegree(remainingDegrees, type: .add, value: 4),
               hasDegree(remainingDegrees, type: .subtract, value: 3) {
                _ = consumeDegree(&remainingDegrees, type: .add, value: 4)
                _ = consumeDegree(&remainingDegrees, type: .subtract, value: 3)
                kindSuffix = "9sus4"
            } else if hasDegree(remainingDegrees, type: .add, value: 2),
                      hasDegree(remainingDegrees, type: .subtract, value: 3) {
                _ = consumeDegree(&remainingDegrees, type: .add, value: 2)
                _ = consumeDegree(&remainingDegrees, type: .subtract, value: 3)
                kindSuffix = "9sus2"
            }
        case "dominant-11th":
            if hasDegree(remainingDegrees, type: .add, value: 4),
               hasDegree(remainingDegrees, type: .subtract, value: 3) {
                _ = consumeDegree(&remainingDegrees, type: .add, value: 4)
                _ = consumeDegree(&remainingDegrees, type: .subtract, value: 3)
                kindSuffix = "11sus4"
            } else if hasDegree(remainingDegrees, type: .add, value: 2),
                      hasDegree(remainingDegrees, type: .subtract, value: 3) {
                _ = consumeDegree(&remainingDegrees, type: .add, value: 2)
                _ = consumeDegree(&remainingDegrees, type: .subtract, value: 3)
                kindSuffix = "11sus2"
            }
        case "dominant-13th":
            if hasDegree(remainingDegrees, type: .add, value: 4),
               hasDegree(remainingDegrees, type: .subtract, value: 3) {
                _ = consumeDegree(&remainingDegrees, type: .add, value: 4)
                _ = consumeDegree(&remainingDegrees, type: .subtract, value: 3)
                kindSuffix = "13sus4"
            } else if hasDegree(remainingDegrees, type: .add, value: 2),
                      hasDegree(remainingDegrees, type: .subtract, value: 3) {
                _ = consumeDegree(&remainingDegrees, type: .add, value: 2)
                _ = consumeDegree(&remainingDegrees, type: .subtract, value: 3)
                kindSuffix = "13sus2"
            }
        default:
            break
        }

        return (kindSuffix: kindSuffix, degrees: remainingDegrees)
    }

    private enum DegreeTypeMatch {
        case add
        case subtract
    }

    private func hasDegree(
        _ degrees: [HarmonyDegree],
        type: DegreeTypeMatch,
        value: Int,
        alter: Int = 0
    ) -> Bool {
        degrees.contains { degree in
            guard degree.value == value,
                  (degree.alter ?? 0) == alter else {
                return false
            }
            return harmonyDegreeTypeMatches(degree.type, match: type)
        }
    }

    @discardableResult
    private func consumeDegree(
        _ degrees: inout [HarmonyDegree],
        type: DegreeTypeMatch,
        value: Int,
        alter: Int = 0
    ) -> Bool {
        guard let index = degrees.firstIndex(where: { degree in
            degree.value == value &&
            (degree.alter ?? 0) == alter &&
            harmonyDegreeTypeMatches(degree.type, match: type)
        }) else {
            return false
        }
        degrees.remove(at: index)
        return true
    }

    private func harmonyDegreeTypeMatches(
        _ degreeType: HarmonyDegreeType?,
        match: DegreeTypeMatch
    ) -> Bool {
        switch (match, degreeType) {
        case (.add, .add):
            return true
        case (.subtract, .subtract):
            return true
        default:
            return false
        }
    }

    private func formatNoChord(kind: String?, explicitText: String?) -> String? {
        guard normalizedKind(kind) == "none" else {
            return nil
        }
        if let explicit = explicitText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty {
            return explicit
        }
        return "N.C."
    }

    private func formatNumeralRoot(root: String?, alter: Int?) -> String? {
        guard let root = root?.trimmingCharacters(in: .whitespacesAndNewlines),
              !root.isEmpty else {
            return nil
        }
        return accidentalString(alter: alter ?? 0) + root
    }

    private func formatPitch(step: String?, alter: Int) -> String? {
        guard let step = step?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !step.isEmpty else {
            return nil
        }
        return step + accidentalString(alter: alter)
    }

    private func accidentalString(alter: Int) -> String {
        guard alter != 0 else {
            return ""
        }
        if alter > 0 {
            return String(repeating: "#", count: alter)
        }
        return String(repeating: "b", count: abs(alter))
    }

    private func formatKind(kind: String?, explicitText: String?) -> String {
        if let explicit = explicitText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty {
            return explicit
        }

        let normalized = normalizedKind(kind)

        switch normalized {
        case "", "major":
            return ""
        case "none":
            return "N.C."
        case "minor":
            return "m"
        case "minor-sixth":
            return "m6"
        case "major-seventh":
            return "maj7"
        case "major-11th":
            return "maj11"
        case "major-13th":
            return "maj13"
        case "major-ninth":
            return "maj9"
        case "major-sixth":
            return "maj6"
        case "major-minor":
            return "m(maj7)"
        case "minor-seventh":
            return "m7"
        case "minor-11th":
            return "m11"
        case "minor-13th":
            return "m13"
        case "minor-ninth":
            return "m9"
        case "dominant":
            return "7"
        case "dominant-11th":
            return "11"
        case "dominant-13th":
            return "13"
        case "dominant-ninth":
            return "9"
        case "augmented":
            return "aug"
        case "augmented-seventh":
            return "aug7"
        case "diminished":
            return "dim"
        case "diminished-seventh":
            return "dim7"
        case "half-diminished":
            return "m7b5"
        case "power":
            return "5"
        case "suspended-second":
            return "sus2"
        case "suspended-fourth":
            return "sus4"
        default:
            return normalized.isEmpty ? "" : "(\(normalized))"
        }
    }

    private func normalizedKind(_ kind: String?) -> String {
        kind?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func formatDegrees(_ degrees: [HarmonyDegree]) -> String {
        let tokens = degrees.compactMap { degree -> String? in
            guard let value = degree.value else {
                return nil
            }
            let accidental = accidentalString(alter: degree.alter ?? 0)
            switch degree.type {
            case .add:
                return "add\(accidental)\(value)"
            case .subtract:
                return "no\(value)"
            case .alter:
                return "\(accidental)\(value)"
            case .unknown(let raw):
                let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? "\(accidental)\(value)" : "\(cleaned)\(accidental)\(value)"
            case .none:
                return "\(accidental)\(value)"
            }
        }

        guard !tokens.isEmpty else {
            return ""
        }

        return "(\(tokens.joined(separator: ",")))"
    }
}
