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
        let root = formatPitch(step: harmony.rootStep, alter: harmony.rootAlter)
            ?? formatNumeralRoot(root: harmony.numeralRoot, alter: harmony.numeralAlter)
        guard let root else {
            return nil
        }

        let kindSuffix = formatKind(kind: harmony.kind, explicitText: harmony.kindText)
        let degreesSuffix = formatDegrees(harmony.degrees)

        var text = root + kindSuffix + degreesSuffix

        if let bass = formatPitch(step: harmony.bassStep, alter: harmony.bassAlter) {
            text += "/\(bass)"
        }

        return text
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

        let normalized = kind?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch normalized {
        case "", "major":
            return ""
        case "minor":
            return "m"
        case "major-seventh":
            return "maj7"
        case "minor-seventh":
            return "m7"
        case "dominant":
            return "7"
        case "augmented":
            return "+"
        case "diminished":
            return "dim"
        case "half-diminished":
            return "m7b5"
        default:
            return normalized.isEmpty ? "" : "(\(normalized))"
        }
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
