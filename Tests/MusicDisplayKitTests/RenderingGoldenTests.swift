import Foundation
import Testing

@testable import MusicDisplayKit
import MusicDisplayKitLayout
import MusicDisplayKitModel
import MusicDisplayKitMusicXML
import MusicDisplayKitVexAdapter

#if canImport(SwiftUI) && canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@available(iOS 17.0, macOS 14.0, *)
private struct RGBAImageBuffer {
    let width: Int
    let height: Int
    let bytes: [UInt8]
}

@available(iOS 17.0, macOS 14.0, *)
private struct ImageDiffMetrics {
    let meanChannelAbsDiff: Double
    let maxChannelAbsDiff: Int
    let changedPixelRatio: Double
}

@available(iOS 17.0, macOS 14.0, *)
private enum RenderingGoldenError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text):
            return text
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenSingleVoiceNotes() throws {
    try assertRenderingGolden(
        name: "single-voice-notes",
        xml: goldenSingleVoiceRenderNotesXML,
        layoutOptions: LayoutOptions(pageWidth: 520, pageMargin: 20, systemSpacing: 16),
        target: .image(width: 520, height: 210)
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenDirectionTempo() throws {
    try assertRenderingGolden(
        name: "direction-tempo",
        xml: goldenDirectionTempoRenderXML,
        layoutOptions: LayoutOptions(pageWidth: 520, pageMargin: 20, systemSpacing: 16),
        target: .image(width: 520, height: 220)
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenRoadmapRepetitions() throws {
    try assertRenderingGolden(
        name: "roadmap-repetitions",
        xml: goldenRepeatsAndTempoXML,
        layoutOptions: LayoutOptions(pageWidth: 560, pageMargin: 20, systemSpacing: 16),
        target: .image(width: 560, height: 260)
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenOSMDChordSymbolsFixture() throws {
    try assertRenderingGoldenFixture(
        name: "osmd-chord-symbols",
        fixture: "test_chord_symbol_centering_short_symbols.musicxml",
        layoutOptions: LayoutOptions(pageWidth: 780, pageMargin: 24, systemSpacing: 18),
        target: .image(width: 780, height: 320)
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenOSMDLyricsFixture() throws {
    try assertRenderingGoldenFixture(
        name: "osmd-lyrics-centering",
        fixture: "test_lyrics_centering.musicxml",
        layoutOptions: LayoutOptions(pageWidth: 820, pageMargin: 24, systemSpacing: 18),
        target: .image(width: 820, height: 360)
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenOSMDSlurFixture() throws {
    try assertRenderingGoldenFixture(
        name: "osmd-slur-double",
        fixture: "test_slur_double.musicxml",
        layoutOptions: LayoutOptions(pageWidth: 760, pageMargin: 24, systemSpacing: 18),
        target: .image(width: 760, height: 340)
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenOSMDArticulationFixture() throws {
    try assertRenderingGoldenFixture(
        name: "osmd-articulation-staccato",
        fixture: "test_articulation_staccato_placement_above_explicitly.musicxml",
        layoutOptions: LayoutOptions(pageWidth: 760, pageMargin: 24, systemSpacing: 18),
        target: .image(width: 760, height: 340)
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenOSMDExpressionsFixture() throws {
    try assertRenderingGoldenFixture(
        name: "osmd-expressions",
        fixture: "OSMD_function_test_expressions.musicxml",
        layoutOptions: LayoutOptions(pageWidth: 920, pageMargin: 24, systemSpacing: 18),
        target: .image(width: 920, height: 380)
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenOSMDRoadmapFixture() throws {
    try assertRenderingGoldenFixture(
        name: "osmd-stave-repetitions-coda",
        fixture: "test_staverepetitions_coda_etc.musicxml",
        layoutOptions: LayoutOptions(pageWidth: 920, pageMargin: 24, systemSpacing: 18),
        target: .image(width: 920, height: 420)
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenOSMDMultiPartGroupFixture() throws {
    try assertRenderingGoldenFixture(
        name: "osmd-multipart-group-connectors",
        fixture: "test_wedge_cresc_dim_simultaneous_quartet.musicxml",
        layoutOptions: LayoutOptions(
            pageWidth: 960,
            pageMargin: 24,
            systemSpacing: 20,
            partSpacing: 28
        ),
        target: .view(identifier: "golden-multipart-group")
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func renderingGoldenOSMDPaginationFixture() throws {
    try assertRenderingGoldenFixture(
        name: "osmd-system-page-breaks",
        fixture: "OSMD_Function_Test_System_and_Page_Breaks_4_pages.mxl",
        layoutOptions: LayoutOptions(
            pageWidth: 520,
            pageHeight: 240,
            pageMargin: 20,
            systemSpacing: 16,
            partSpacing: 32
        ),
        target: .view(identifier: "golden-pagination")
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
private func assertRenderingGolden(
    name: String,
    xml: String,
    layoutOptions: LayoutOptions,
    target: RenderTarget,
    scale: Double = 1.0
) throws {
    let score = try MusicXMLParser().parse(xml: xml)
    try assertRenderingGolden(
        name: name,
        score: score,
        layoutOptions: layoutOptions,
        target: target,
        scale: scale
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
private func assertRenderingGoldenFixture(
    name: String,
    fixture: String,
    layoutOptions: LayoutOptions,
    target: RenderTarget,
    scale: Double = 1.0
) throws {
    let fixtureURL = try osmdFixtureURL(named: fixture)
    let score = try MusicXMLParser().parse(fileURL: fixtureURL)
    try assertRenderingGolden(
        name: name,
        score: score,
        layoutOptions: layoutOptions,
        target: target,
        scale: scale
    )
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
private func assertRenderingGolden(
    name: String,
    score: Score,
    layoutOptions: LayoutOptions,
    target: RenderTarget,
    scale: Double = 1.0
) throws {
    let laidOut = try MusicLayoutEngine().layout(score: score, options: layoutOptions)
    let actualPNG = try VexFoundationRenderer().renderPNGData(from: laidOut, target: target, scale: scale)

    let goldenURL = goldenDirectoryURL().appendingPathComponent("\(name).png")
    if updateGoldensEnabled() {
        try FileManager.default.createDirectory(
            at: goldenURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try actualPNG.write(to: goldenURL, options: Data.WritingOptions.atomic)
        return
    }

    guard FileManager.default.fileExists(atPath: goldenURL.path) else {
        throw RenderingGoldenError.message(
            """
            Missing rendering golden '\(name)' at \(goldenURL.path).
            Regenerate with: UPDATE_GOLDENS=1 swift test --filter renderingGolden
            """
        )
    }

    let expectedPNG = try Data(contentsOf: goldenURL)
    let expectedImage = try decodePNG(expectedPNG)
    let actualImage = try decodePNG(actualPNG)

    guard expectedImage.width == actualImage.width, expectedImage.height == actualImage.height else {
        throw RenderingGoldenError.message(
            """
            Golden '\(name)' size mismatch.
            expected=\(expectedImage.width)x\(expectedImage.height) actual=\(actualImage.width)x\(actualImage.height)
            """
        )
    }

    let (metrics, diffImage) = diffImageMetrics(expected: expectedImage, actual: actualImage)
    let tolerance = (
        meanChannelAbsDiff: 2.0,
        maxChannelAbsDiff: 40,
        changedPixelRatio: 0.02
    )
    let withinTolerance =
        metrics.meanChannelAbsDiff <= tolerance.meanChannelAbsDiff &&
        metrics.maxChannelAbsDiff <= tolerance.maxChannelAbsDiff &&
        metrics.changedPixelRatio <= tolerance.changedPixelRatio

    guard withinTolerance else {
        let artifactDir = artifactsDirectoryURL().appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: artifactDir, withIntermediateDirectories: true)
        let actualURL = artifactDir.appendingPathComponent("actual.png")
        let expectedURL = artifactDir.appendingPathComponent("expected.png")
        let diffURL = artifactDir.appendingPathComponent("diff.png")
        try actualPNG.write(to: actualURL, options: Data.WritingOptions.atomic)
        try expectedPNG.write(to: expectedURL, options: Data.WritingOptions.atomic)
        let diffPNG = try encodePNG(diffImage)
        try diffPNG.write(to: diffURL, options: Data.WritingOptions.atomic)

        throw RenderingGoldenError.message(
            """
            Rendering golden '\(name)' mismatch.
            meanChannelAbsDiff=\(metrics.meanChannelAbsDiff) (<= \(tolerance.meanChannelAbsDiff))
            maxChannelAbsDiff=\(metrics.maxChannelAbsDiff) (<= \(tolerance.maxChannelAbsDiff))
            changedPixelRatio=\(metrics.changedPixelRatio) (<= \(tolerance.changedPixelRatio))
            Artifacts: \(artifactDir.path)
            """
        )
    }
}

@available(iOS 17.0, macOS 14.0, *)
private func decodePNG(_ data: Data) throws -> RGBAImageBuffer {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw RenderingGoldenError.message("Failed to decode PNG data.")
    }

    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        | CGImageAlphaInfo.premultipliedLast.rawValue

    let rendered = bytes.withUnsafeMutableBytes { rawBuffer -> Bool in
        guard let context = CGContext(
            data: rawBuffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return false
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard rendered else {
        throw RenderingGoldenError.message("Failed to render decoded PNG into RGBA buffer.")
    }

    return RGBAImageBuffer(width: width, height: height, bytes: bytes)
}

@available(iOS 17.0, macOS 14.0, *)
private func diffImageMetrics(
    expected: RGBAImageBuffer,
    actual: RGBAImageBuffer
) -> (ImageDiffMetrics, RGBAImageBuffer) {
    let count = min(expected.bytes.count, actual.bytes.count)
    let pixelCount = max(1, min(expected.width * expected.height, actual.width * actual.height))

    var totalAbsDiff = 0
    var maxAbsDiff = 0
    var changedPixels = 0
    var diffBytes = [UInt8](repeating: 0, count: expected.bytes.count)
    for index in stride(from: 0, to: count, by: 4) {
        let dr = abs(Int(expected.bytes[index]) - Int(actual.bytes[index]))
        let dg = abs(Int(expected.bytes[index + 1]) - Int(actual.bytes[index + 1]))
        let db = abs(Int(expected.bytes[index + 2]) - Int(actual.bytes[index + 2]))
        let da = abs(Int(expected.bytes[index + 3]) - Int(actual.bytes[index + 3]))

        totalAbsDiff += dr + dg + db + da
        let pixelMax = max(max(dr, dg), max(db, da))
        maxAbsDiff = max(maxAbsDiff, pixelMax)
        if pixelMax > 0 {
            changedPixels += 1
        }

        diffBytes[index] = UInt8(min(255, dr * 4))
        diffBytes[index + 1] = UInt8(min(255, dg * 4))
        diffBytes[index + 2] = UInt8(min(255, db * 4))
        diffBytes[index + 3] = 255
    }

    let metrics = ImageDiffMetrics(
        meanChannelAbsDiff: Double(totalAbsDiff) / Double(pixelCount * 4),
        maxChannelAbsDiff: maxAbsDiff,
        changedPixelRatio: Double(changedPixels) / Double(pixelCount)
    )
    return (
        metrics,
        RGBAImageBuffer(width: expected.width, height: expected.height, bytes: diffBytes)
    )
}

@available(iOS 17.0, macOS 14.0, *)
private func encodePNG(_ image: RGBAImageBuffer) throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        | CGImageAlphaInfo.premultipliedLast.rawValue
    guard let provider = CGDataProvider(data: Data(image.bytes) as CFData),
          let cgImage = CGImage(
              width: image.width,
              height: image.height,
              bitsPerComponent: 8,
              bitsPerPixel: 32,
              bytesPerRow: image.width * 4,
              space: colorSpace,
              bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
              provider: provider,
              decode: nil,
              shouldInterpolate: false,
              intent: .defaultIntent
          ) else {
        throw RenderingGoldenError.message("Failed to build CGImage for PNG encoding.")
    }

    let mutableData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        mutableData,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw RenderingGoldenError.message("Failed to create PNG image destination.")
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw RenderingGoldenError.message("Failed to finalize PNG image destination.")
    }
    return mutableData as Data
}

private func goldenDirectoryURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures", isDirectory: true)
        .appendingPathComponent("Goldens", isDirectory: true)
}

private func osmdFixtureURL(named filename: String) throws -> URL {
    let fileManager = FileManager.default

    let cwdCandidate = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("../opensheetmusicdisplay/test/data/\(filename)")
        .standardizedFileURL
    if fileManager.fileExists(atPath: cwdCandidate.path) {
        return cwdCandidate
    }

    let testFileURL = URL(fileURLWithPath: #filePath, isDirectory: false)
    let packageRootCandidate = testFileURL
        .deletingLastPathComponent() // MusicDisplayKitTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // MusicDisplayKit
        .appendingPathComponent("opensheetmusicdisplay/test/data/\(filename)")
        .standardizedFileURL
    if fileManager.fileExists(atPath: packageRootCandidate.path) {
        return packageRootCandidate
    }

    throw RenderingGoldenError.message("Could not find OSMD fixture: \(filename)")
}

private func artifactsDirectoryURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build", isDirectory: true)
        .appendingPathComponent("golden-artifacts", isDirectory: true)
}

private func updateGoldensEnabled() -> Bool {
    ProcessInfo.processInfo.environment["UPDATE_GOLDENS"] == "1"
}

private let goldenSingleVoiceRenderNotesXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Solo</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <note>
        <rest/>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <note>
        <pitch><step>E</step><alter>1</alter><octave>4</octave></pitch>
        <duration>8</duration>
        <voice>1</voice>
      </note>
      <backup><duration>16</duration></backup>
      <note>
        <pitch><step>G</step><octave>3</octave></pitch>
        <duration>16</duration>
        <voice>2</voice>
      </note>
    </measure>
    <measure number="2">
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>16</duration>
        <voice>1</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let goldenDirectionTempoRenderXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <direction placement="above">
        <direction-type>
          <metronome>
            <beat-unit>quarter</beat-unit>
            <beat-unit-dot/>
            <per-minute>120</per-minute>
          </metronome>
        </direction-type>
      </direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
      <direction placement="above">
        <sound tempo="96"/>
      </direction>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration>
        <voice>1</voice>
      </note>
    </measure>
  </part>
</score-partwise>
"""

private let goldenRepeatsAndTempoXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Instrument</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <barline location="left">
        <repeat direction="forward"/>
      </barline>
      <direction placement="above">
        <sound tempo="96"/>
      </direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
      <barline location="right">
        <ending number="1" type="start"/>
      </barline>
    </measure>
    <measure number="2">
      <direction placement="above">
        <direction-type>
          <metronome>
            <beat-unit>quarter</beat-unit>
            <per-minute>72</per-minute>
          </metronome>
          <segno/>
          <coda/>
          <words>To Coda</words>
          <words>Fine</words>
        </direction-type>
        <sound dacapo="yes" dalsegno="seg1" tocoda="coda1" fine="Fine"/>
      </direction>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
      <barline location="right">
        <repeat direction="backward" times="2"/>
        <ending number="1" type="stop"/>
      </barline>
    </measure>
  </part>
</score-partwise>
"""
#endif
