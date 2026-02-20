public struct MDKFraction: Equatable, Hashable, Sendable {
    public let numerator: Int
    public let denominator: Int

    public init(_ numerator: Int, _ denominator: Int) {
        precondition(denominator != 0, "MDKFraction denominator cannot be zero")
        let normalizedSign = denominator < 0 ? -1 : 1
        let adjustedNumerator = numerator * normalizedSign
        let adjustedDenominator = abs(denominator)
        let divisor = MDKFraction.gcd(abs(adjustedNumerator), adjustedDenominator)
        self.numerator = adjustedNumerator / divisor
        self.denominator = adjustedDenominator / divisor
    }

    public static func + (lhs: MDKFraction, rhs: MDKFraction) -> MDKFraction {
        let denominatorLCM = lcm(lhs.denominator, rhs.denominator)
        let lhsScale = denominatorLCM / lhs.denominator
        let rhsScale = denominatorLCM / rhs.denominator
        return MDKFraction(
            lhs.numerator * lhsScale + rhs.numerator * rhsScale,
            denominatorLCM
        )
    }

    public static func - (lhs: MDKFraction, rhs: MDKFraction) -> MDKFraction {
        lhs + MDKFraction(-rhs.numerator, rhs.denominator)
    }

    public static func * (lhs: MDKFraction, rhs: MDKFraction) -> MDKFraction {
        MDKFraction(lhs.numerator * rhs.numerator, lhs.denominator * rhs.denominator)
    }

    public static func / (lhs: MDKFraction, rhs: MDKFraction) -> MDKFraction {
        precondition(rhs.numerator != 0, "Cannot divide by zero MDKFraction")
        return MDKFraction(lhs.numerator * rhs.denominator, lhs.denominator * rhs.numerator)
    }

    public var asDouble: Double {
        Double(numerator) / Double(denominator)
    }

    private static func gcd(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return max(1, a)
    }

    private static func lcm(_ lhs: Int, _ rhs: Int) -> Int {
        abs(lhs / gcd(abs(lhs), abs(rhs)) * rhs)
    }
}

public struct MDKPoint: Equatable, Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct NotImplementedError: Error, CustomStringConvertible, Sendable {
    public let feature: String

    public init(_ feature: String) {
        self.feature = feature
    }

    public var description: String {
        "Not implemented: \(feature)"
    }
}
