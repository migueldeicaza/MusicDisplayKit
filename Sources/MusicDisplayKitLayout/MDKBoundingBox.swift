import MusicDisplayKitCore

/// Axis-aligned bounding box used by the layout and collision-avoidance subsystems.
/// Lives in the Layout module so it carries no VexFoundation dependency.
public struct MDKBoundingBox: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double = 0, y: Double = 0, width: Double = 0, height: Double = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Expands this box to enclose `other`.
    public mutating func mergeWith(_ other: MDKBoundingBox) {
        let minX = min(x, other.x)
        let minY = min(y, other.y)
        let maxX = max(x + width, other.x + other.width)
        let maxY = max(y + height, other.y + other.height)
        x = minX
        y = minY
        width = maxX - minX
        height = maxY - minY
    }

    /// Returns a new box that encloses both `self` and `other`.
    public func merged(with other: MDKBoundingBox) -> MDKBoundingBox {
        var copy = self
        copy.mergeWith(other)
        return copy
    }

    /// Returns `true` if `point` lies inside this box (inclusive).
    public func contains(point: MDKPoint) -> Bool {
        point.x >= x && point.x <= x + width
            && point.y >= y && point.y <= y + height
    }

    /// Returns `true` if this box intersects `other`.
    public func overlaps(_ other: MDKBoundingBox) -> Bool {
        x < other.x + other.width && x + width > other.x
            && y < other.y + other.height && y + height > other.y
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
    public var origin: MDKPoint { MDKPoint(x: x, y: y) }
}
