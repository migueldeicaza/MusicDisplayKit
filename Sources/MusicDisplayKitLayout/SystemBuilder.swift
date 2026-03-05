import Foundation

/// Replaces the greedy `buildColumnRanges` approach with a cost-function-based
/// algorithm inspired by Knuth-Plass line breaking. Produces more balanced
/// system fills and respects XML break hints.
public struct SystemBuilder: Sendable {
    public init() {}

    /// Breaks measures into systems using a dynamic programming approach.
    ///
    /// - Parameters:
    ///   - columnWidths: Width of each measure column.
    ///   - usableWidth: Available horizontal space per system.
    ///   - measureGap: Gap between consecutive measures.
    ///   - breakHints: Per-measure flags from MusicXML (`new-system`/`new-page`).
    ///   - rules: Engraving rules for cost-function tuning.
    /// - Returns: Array of ranges indicating which columns belong to each system,
    ///   along with stretch factors for justified layout.
    public func buildSystems(
        columnWidths: [Double],
        usableWidth: Double,
        measureGap: Double,
        breakHints: [Bool] = [],
        rules: EngravingRules = .default
    ) -> [SystemBreak] {
        let n = columnWidths.count
        guard n > 0 else { return [] }

        // dp[i] = best cost to break measures 0..<i
        var dp = Array(repeating: Double.infinity, count: n + 1)
        var parent = Array(repeating: -1, count: n + 1)
        dp[0] = 0

        let lookback = min(n, 50) // limit DP lookback for performance

        for j in 1...n {
            let rangeEnd = max(0, j - lookback)
            var lineWidth = 0.0

            for i in stride(from: j - 1, through: rangeEnd, by: -1) {
                let colWidth = columnWidths[i]
                lineWidth += colWidth
                if i < j - 1 {
                    lineWidth += measureGap
                }

                // Enforce forced breaks from XML hints.
                if i > 0, i < breakHints.count, breakHints[i] {
                    // Must break here — any line not starting here is invalid.
                    if dp[i] + cost(lineWidth: lineWidth, usableWidth: usableWidth,
                                    measureCount: j - i, totalMeasures: n,
                                    isLast: j == n, hasBreakHint: true, rules: rules)
                        < dp[j] {
                        dp[j] = dp[i] + cost(lineWidth: lineWidth, usableWidth: usableWidth,
                                              measureCount: j - i, totalMeasures: n,
                                              isLast: j == n, hasBreakHint: true, rules: rules)
                        parent[j] = i
                    }
                    break // Can't extend past a forced break
                }

                // Skip if line is too wide (unless it's a single measure that's inherently wide).
                if lineWidth > usableWidth && j - i > 1 {
                    break
                }

                let c = cost(
                    lineWidth: lineWidth,
                    usableWidth: usableWidth,
                    measureCount: j - i,
                    totalMeasures: n,
                    isLast: j == n,
                    hasBreakHint: false,
                    rules: rules
                )

                if dp[i] + c < dp[j] {
                    dp[j] = dp[i] + c
                    parent[j] = i
                }
            }
        }

        // Trace back the optimal breaks.
        var breaks: [Range<Int>] = []
        var pos = n
        while pos > 0 {
            let start = parent[pos]
            breaks.append(start..<pos)
            pos = start
        }
        breaks.reverse()

        // Compute stretch factors.
        return breaks.map { range in
            let naturalWidth = totalWidth(columnWidths: columnWidths, range: range, measureGap: measureGap)
            let stretchFactor = usableWidth > 0 ? naturalWidth / usableWidth : 1.0
            return SystemBreak(measureRange: range, stretchFactor: stretchFactor)
        }
    }

    /// Greedy fallback matching the existing `buildColumnRanges` behavior.
    public func buildColumnRangesGreedy(
        columnWidths: [Double],
        usableWidth: Double,
        measureGap: Double,
        breakHints: [Bool] = []
    ) -> [Range<Int>] {
        guard !columnWidths.isEmpty else { return [] }

        var ranges: [Range<Int>] = []
        var rangeStart = 0
        var accumulatedWidth = columnWidths[0]

        for index in 1..<columnWidths.count {
            let forceBreak = index < breakHints.count && breakHints[index]
            let proposedWidth = accumulatedWidth + measureGap + columnWidths[index]
            if forceBreak || proposedWidth > usableWidth {
                ranges.append(rangeStart..<index)
                rangeStart = index
                accumulatedWidth = columnWidths[index]
            } else {
                accumulatedWidth = proposedWidth
            }
        }

        ranges.append(rangeStart..<columnWidths.count)
        return ranges
    }

    // MARK: - Private

    private func cost(
        lineWidth: Double,
        usableWidth: Double,
        measureCount: Int,
        totalMeasures: Int,
        isLast: Bool,
        hasBreakHint: Bool,
        rules: EngravingRules
    ) -> Double {
        let fillRatio = usableWidth > 0 ? lineWidth / usableWidth : 1.0
        var penalty = 0.0

        // Penalize underfilled lines (except last line).
        if !isLast && fillRatio < rules.systemFillThreshold {
            let deficit = rules.systemFillThreshold - fillRatio
            penalty += deficit * deficit * 1000
        }

        // Penalize overfilled lines.
        if fillRatio > 1.0 {
            let excess = fillRatio - 1.0
            penalty += excess * excess * 5000
        }

        // Penalize orphan measures (single measure on last line, unless it's the only line).
        if isLast && measureCount == 1 && totalMeasures > 1 {
            penalty += rules.orphanMeasurePenalty
        }

        // Reward break-hint alignment.
        if hasBreakHint {
            penalty -= rules.breakHintReward
        }

        // Base badness: squared deviation from ideal fill.
        let deviation = 1.0 - fillRatio
        penalty += deviation * deviation * 100

        return penalty
    }

    private func totalWidth(columnWidths: [Double], range: Range<Int>, measureGap: Double) -> Double {
        var width = 0.0
        for i in range {
            width += columnWidths[i]
            if i > range.lowerBound {
                width += measureGap
            }
        }
        return width
    }
}

/// Result of system-breaking with a stretch factor for justified layout.
public struct SystemBreak: Equatable, Sendable {
    /// Range of column indices belonging to this system.
    public let measureRange: Range<Int>
    /// Ratio of natural width to usable width (< 1 means system needs stretching).
    public let stretchFactor: Double

    public init(measureRange: Range<Int>, stretchFactor: Double) {
        self.measureRange = measureRange
        self.stretchFactor = stretchFactor
    }
}
