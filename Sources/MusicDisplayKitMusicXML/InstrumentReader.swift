import MusicDisplayKitModel

public struct InstrumentMeasureVisit: Equatable, Sendable {
    public var partIndex: Int
    public var partID: String
    public var partName: String?
    public var measureIndex: Int
    public var measureNumber: Int
    public var xmlMeasureNumber: String?
    public var effectiveDivisions: Int?
    public var effectiveAttributes: MeasureAttributes?
    public var measure: Measure

    public init(
        partIndex: Int,
        partID: String,
        partName: String?,
        measureIndex: Int,
        measureNumber: Int,
        xmlMeasureNumber: String?,
        effectiveDivisions: Int?,
        effectiveAttributes: MeasureAttributes?,
        measure: Measure
    ) {
        self.partIndex = partIndex
        self.partID = partID
        self.partName = partName
        self.measureIndex = measureIndex
        self.measureNumber = measureNumber
        self.xmlMeasureNumber = xmlMeasureNumber
        self.effectiveDivisions = effectiveDivisions
        self.effectiveAttributes = effectiveAttributes
        self.measure = measure
    }
}

public struct InstrumentReader: Sendable {
    public init() {}

    public func readMeasureVisits(from score: Score) -> [InstrumentMeasureVisit] {
        var visits: [InstrumentMeasureVisit] = []

        for (partIndex, part) in score.parts.enumerated() {
            var activeDivisions: Int?
            var activeAttributes: MeasureAttributes?

            for (measureIndex, measure) in part.measures.enumerated() {
                if let divisions = measure.divisions {
                    activeDivisions = divisions
                }
                if let attributes = measure.attributes {
                    activeAttributes = attributes
                }

                visits.append(
                    InstrumentMeasureVisit(
                        partIndex: partIndex,
                        partID: part.id,
                        partName: part.name,
                        measureIndex: measureIndex,
                        measureNumber: measure.number,
                        xmlMeasureNumber: measure.xmlNumber,
                        effectiveDivisions: activeDivisions,
                        effectiveAttributes: activeAttributes,
                        measure: measure
                    )
                )
            }
        }

        return visits
    }

    public func traverse(
        score: Score,
        visitor: (InstrumentMeasureVisit) throws -> Void
    ) rethrows {
        for visit in readMeasureVisits(from: score) {
            try visitor(visit)
        }
    }
}
