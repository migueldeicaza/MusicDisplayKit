import Foundation
import MusicDisplayKitCore

/// Calculates and manages skyline/bottomline profiles for collision avoidance.
/// The skyline tracks the highest occupied Y (above staff), the bottomline
/// tracks the lowest occupied Y (below staff).
public struct SkylineCalculator: Sendable {
    public init() {}

    /// Creates a skyline profile (above-staff) initialized from staff top position.
    public func makeSkylineProfile(
        startX: Double,
        endX: Double,
        staffTopY: Double,
        resolution: Double = 2
    ) -> SkylineProfile {
        let count = max(1, Int(ceil((endX - startX) / resolution)))
        return SkylineProfile(
            startX: startX,
            resolution: resolution,
            count: count,
            initialValue: staffTopY,
            isSkyline: true
        )
    }

    /// Creates a bottomline profile (below-staff) initialized from staff bottom position.
    public func makeBottomlineProfile(
        startX: Double,
        endX: Double,
        staffBottomY: Double,
        resolution: Double = 2
    ) -> SkylineProfile {
        let count = max(1, Int(ceil((endX - startX) / resolution)))
        return SkylineProfile(
            startX: startX,
            resolution: resolution,
            count: count,
            initialValue: staffBottomY,
            isSkyline: false
        )
    }

    /// Inserts note bounding boxes into the skyline and bottomline profiles.
    public func insertNoteBoundingBoxes(
        _ boxes: [MDKBoundingBox],
        skyline: SkylineProfile,
        bottomline: SkylineProfile
    ) {
        skyline.insertBoundingBoxes(boxes)
        bottomline.insertBoundingBoxes(boxes)
    }

    /// Places an above-staff element using the skyline, returns the Y position.
    /// After placement, the element's bounding box is inserted into the skyline.
    public func placeAboveStaff(
        box: MDKBoundingBox,
        skyline: SkylineProfile,
        padding: Double = 6
    ) -> Double {
        let currentTop = skyline.querySkyline(xStart: box.x, xEnd: box.maxX)
        let placedY = currentTop - box.height - padding
        var placedBox = box
        placedBox.y = placedY
        skyline.insertBoundingBox(placedBox)
        return placedY
    }

    /// Places a below-staff element using the bottomline, returns the Y position.
    /// After placement, the element's bounding box is inserted into the bottomline.
    public func placeBelowStaff(
        box: MDKBoundingBox,
        bottomline: SkylineProfile,
        padding: Double = 8
    ) -> Double {
        let currentBottom = bottomline.queryBottomline(xStart: box.x, xEnd: box.maxX)
        let placedY = currentBottom + padding
        var placedBox = box
        placedBox.y = placedY
        bottomline.insertBoundingBox(placedBox)
        return placedY
    }
}
