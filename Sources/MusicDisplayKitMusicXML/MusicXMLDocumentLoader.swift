import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import MusicDisplayKitModel
import ZIPFoundation

public protocol ScoreDataParser: ScoreParser {
    func parse(data: Data, pathExtension: String?) throws -> Score
    func parse(fileURL: URL) throws -> Score
}

public extension ScoreDataParser {
    func parse(data: Data) throws -> Score {
        try parse(data: data, pathExtension: nil)
    }

    func parse(fileURL: URL) throws -> Score {
        let data = try Data(contentsOf: fileURL)
        return try parse(data: data, pathExtension: fileURL.pathExtension)
    }
}

public enum MusicXMLDocumentLoaderError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyData
    case invalidMXLArchive
    case missingContainerXML
    case missingContainerRootfile
    case missingRootfileEntry(String)
    case undecodableXMLData

    public var description: String {
        switch self {
        case .emptyData:
            return "Input data is empty."
        case .invalidMXLArchive:
            return "Input data is not a readable MXL archive."
        case .missingContainerXML:
            return "MXL container is missing META-INF/container.xml."
        case .missingContainerRootfile:
            return "MXL container.xml does not declare a rootfile."
        case .missingRootfileEntry(let path):
            return "MXL rootfile entry '\(path)' was not found."
        case .undecodableXMLData:
            return "MusicXML bytes could not be decoded into text."
        }
    }
}

struct MusicXMLDocumentLoader {
    func loadMusicXMLString(from data: Data, pathExtension: String?) throws -> String {
        guard !data.isEmpty else {
            throw MusicXMLDocumentLoaderError.emptyData
        }

        if isMXL(data: data, pathExtension: pathExtension) {
            return try loadMXLRootMusicXMLString(from: data)
        }

        return try decodeXMLString(from: data)
    }

    private func isMXL(data: Data, pathExtension: String?) -> Bool {
        if pathExtension?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "mxl" {
            return true
        }

        guard data.count >= 4 else {
            return false
        }
        let signature = [UInt8](data.prefix(4))
        return signature == [0x50, 0x4B, 0x03, 0x04]
            || signature == [0x50, 0x4B, 0x05, 0x06]
            || signature == [0x50, 0x4B, 0x07, 0x08]
    }

    private func loadMXLRootMusicXMLString(from data: Data) throws -> String {
        let archive: Archive
        do {
            archive = try Archive(data: data, accessMode: .read)
        } catch {
            throw MusicXMLDocumentLoaderError.invalidMXLArchive
        }

        guard let containerEntry = findEntry(
            path: "META-INF/container.xml",
            in: archive
        ) else {
            throw MusicXMLDocumentLoaderError.missingContainerXML
        }

        let containerData = try extractData(for: containerEntry, in: archive)
        let rootfilePath = try parseContainerRootfilePath(from: containerData)
        let normalizedRootfilePath = normalizeArchivePath(rootfilePath)
        guard let rootEntry = findEntry(path: normalizedRootfilePath, in: archive) else {
            throw MusicXMLDocumentLoaderError.missingRootfileEntry(normalizedRootfilePath)
        }

        let xmlData = try extractData(for: rootEntry, in: archive)
        return try decodeXMLString(from: xmlData)
    }

    private func extractData(for entry: Entry, in archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry, consumer: { chunk in
            data.append(chunk)
        })
        return data
    }

    private func findEntry(path: String, in archive: Archive) -> Entry? {
        if let exact = archive[path] {
            return exact
        }
        let normalizedTarget = normalizeArchivePath(path)
        return archive.first { normalizeArchivePath($0.path) == normalizedTarget }
    }

    private func normalizeArchivePath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }

    private func parseContainerRootfilePath(from containerData: Data) throws -> String {
        let delegate = ContainerXMLDelegate()
        let parser = XMLParser(data: containerData)
        parser.delegate = delegate
        guard parser.parse() else {
            throw MusicXMLDocumentLoaderError.missingContainerRootfile
        }

        if let typedRoot = delegate.rootfiles.first(where: {
            ($0.mediaType?.lowercased() ?? "") == "application/vnd.recordare.musicxml+xml"
        })?.fullPath {
            return typedRoot
        }
        if let anyRoot = delegate.rootfiles.first?.fullPath {
            return anyRoot
        }
        throw MusicXMLDocumentLoaderError.missingContainerRootfile
    }

    private func decodeXMLString(from data: Data) throws -> String {
        if let bomDecoded = decodeByBOM(data) {
            return bomDecoded
        }

        if let declared = declaredXMLEncoding(in: data),
           let encoding = stringEncoding(fromXMLName: declared),
           let decoded = String(data: data, encoding: encoding) {
            return decoded
        }

        let fallbackEncodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .ascii,
            .isoLatin1,
            .windowsCP1252,
        ]
        for encoding in fallbackEncodings {
            if let decoded = String(data: data, encoding: encoding) {
                return decoded
            }
        }

        throw MusicXMLDocumentLoaderError.undecodableXMLData
    }

    private func decodeByBOM(_ data: Data) -> String? {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }
        return nil
    }

    private func declaredXMLEncoding(in data: Data) -> String? {
        let probe = Data(data.prefix(256))
        let asciiProbe = String(data: probe, encoding: .ascii)
            ?? String(data: probe, encoding: .isoLatin1)
        guard let asciiProbe else {
            return nil
        }
        guard let range = asciiProbe.range(
            of: #"encoding\s*=\s*['"]([^'"]+)['"]"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }
        let fragment = String(asciiProbe[range])
        guard let valueRange = fragment.range(
            of: #"['"]([^'"]+)['"]"#,
            options: [.regularExpression]
        ) else {
            return nil
        }
        var value = String(fragment[valueRange])
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stringEncoding(fromXMLName value: String) -> String.Encoding? {
        switch value.lowercased() {
        case "utf-8", "utf8":
            return .utf8
        case "utf-16", "utf16":
            return .utf16
        case "utf-16le", "utf16le":
            return .utf16LittleEndian
        case "utf-16be", "utf16be":
            return .utf16BigEndian
        case "us-ascii", "ascii":
            return .ascii
        case "iso-8859-1", "latin1", "iso8859-1":
            return .isoLatin1
        case "windows-1252", "cp1252":
            return .windowsCP1252
        default:
            return nil
        }
    }
}

private final class ContainerXMLDelegate: NSObject, XMLParserDelegate {
    typealias Rootfile = (fullPath: String, mediaType: String?)
    var rootfiles: [Rootfile] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.lowercased() == "rootfile" else {
            return
        }
        guard let fullPath = attributeDict["full-path"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !fullPath.isEmpty else {
            return
        }
        rootfiles.append(
            (
                fullPath: fullPath,
                mediaType: attributeDict["media-type"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }
}
