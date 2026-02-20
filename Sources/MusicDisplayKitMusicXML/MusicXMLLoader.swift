import Foundation
import MusicDisplayKitModel

public enum MusicXMLSource: Sendable {
    case xmlString(String)
    case data(Data, pathExtension: String? = nil)
    case fileURL(URL)
    case url(URL, pathExtensionHint: String? = nil)
}

public enum MusicXMLLoaderError: Error, Equatable, CustomStringConvertible, Sendable {
    case unsupportedURLScheme(String?)
    case undecodableInputData

    public var description: String {
        switch self {
        case .unsupportedURLScheme(let scheme):
            return "Unsupported URL scheme: \(scheme ?? "<nil>")."
        case .undecodableInputData:
            return "Input bytes could not be decoded by the configured parser."
        }
    }
}

public struct MusicXMLLoader {
    private let parser: ScoreParser

    public init(parser: ScoreParser = MusicXMLParser()) {
        self.parser = parser
    }

    public func loadScore(from source: MusicXMLSource) throws -> Score {
        switch source {
        case .xmlString(let xml):
            return try parser.parse(xml: xml)

        case .data(let data, let pathExtension):
            return try parseData(data, pathExtension: pathExtension)

        case .fileURL(let fileURL):
            if let dataParser = parser as? ScoreDataParser {
                return try dataParser.parse(fileURL: fileURL)
            }
            let data = try Data(contentsOf: fileURL)
            return try parseData(data, pathExtension: fileURL.pathExtension)

        case .url(let url, let hint):
            let scheme = url.scheme?.lowercased()
            if let scheme, scheme != "http", scheme != "https", scheme != "file" {
                throw MusicXMLLoaderError.unsupportedURLScheme(scheme)
            }

            if url.isFileURL {
                if let dataParser = parser as? ScoreDataParser {
                    return try dataParser.parse(fileURL: url)
                }
                let data = try Data(contentsOf: url)
                return try parseData(data, pathExtension: hint ?? url.pathExtension)
            }

            let data = try Data(contentsOf: url)
            return try parseData(data, pathExtension: hint ?? url.pathExtension)
        }
    }

    private func parseData(_ data: Data, pathExtension: String?) throws -> Score {
        if let dataParser = parser as? ScoreDataParser {
            return try dataParser.parse(data: data, pathExtension: pathExtension)
        }
        guard let xml = String(data: data, encoding: .utf8) else {
            throw MusicXMLLoaderError.undecodableInputData
        }
        return try parser.parse(xml: xml)
    }
}
