import Foundation
import MusicDisplayKitModel

public protocol MusicXMLDataFetching {
    func data(from url: URL) throws -> Data
}

public struct FoundationMusicXMLDataFetcher: MusicXMLDataFetching, Sendable {
    public init() {}

    public func data(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
}

public enum MusicXMLSource: Sendable {
    case xmlString(String)
    case data(Data, pathExtension: String? = nil)
    case fileURL(URL)
    case url(URL, pathExtensionHint: String? = nil)
}

public struct MusicXMLLoaderOptions: Sendable {
    public var allowsFileURLs: Bool
    public var allowsRemoteURLs: Bool
    public var allowedRemoteSchemes: Set<String>

    public init(
        allowsFileURLs: Bool = true,
        allowsRemoteURLs: Bool = true,
        allowedRemoteSchemes: Set<String> = ["http", "https"]
    ) {
        self.allowsFileURLs = allowsFileURLs
        self.allowsRemoteURLs = allowsRemoteURLs
        self.allowedRemoteSchemes = Set(allowedRemoteSchemes.map { $0.lowercased() })
    }
}

public enum MusicXMLLoaderError: Error, Equatable, CustomStringConvertible, Sendable {
    case unsupportedURLScheme(String?)
    case undecodableInputData
    case fileURLAccessDisabled
    case remoteURLAccessDisabled

    public var description: String {
        switch self {
        case .unsupportedURLScheme(let scheme):
            return "Unsupported URL scheme: \(scheme ?? "<nil>")."
        case .undecodableInputData:
            return "Input bytes could not be decoded by the configured parser."
        case .fileURLAccessDisabled:
            return "File URL loading is disabled by loader options."
        case .remoteURLAccessDisabled:
            return "Remote URL loading is disabled by loader options."
        }
    }
}

public struct MusicXMLLoader {
    private let parser: ScoreParser
    private let options: MusicXMLLoaderOptions
    private let dataFetcher: any MusicXMLDataFetching

    public init(
        parser: ScoreParser = MusicXMLParser(),
        options: MusicXMLLoaderOptions = MusicXMLLoaderOptions(),
        dataFetcher: any MusicXMLDataFetching = FoundationMusicXMLDataFetcher()
    ) {
        self.parser = parser
        self.options = options
        self.dataFetcher = dataFetcher
    }

    public func loadScore(from source: MusicXMLSource) throws -> Score {
        switch source {
        case .xmlString(let xml):
            return try parser.parse(xml: xml)

        case .data(let data, let pathExtension):
            return try parseData(data, pathExtension: pathExtension)

        case .fileURL(let fileURL):
            guard options.allowsFileURLs else {
                throw MusicXMLLoaderError.fileURLAccessDisabled
            }
            if let dataParser = parser as? ScoreDataParser {
                return try dataParser.parse(fileURL: fileURL)
            }
            let data = try dataFetcher.data(from: fileURL)
            return try parseData(data, pathExtension: fileURL.pathExtension)

        case .url(let url, let hint):
            let scheme = url.scheme?.lowercased()
            if let scheme, scheme != "file", !options.allowedRemoteSchemes.contains(scheme) {
                throw MusicXMLLoaderError.unsupportedURLScheme(scheme)
            }
            guard scheme != nil else {
                throw MusicXMLLoaderError.unsupportedURLScheme(nil)
            }

            if url.isFileURL {
                guard options.allowsFileURLs else {
                    throw MusicXMLLoaderError.fileURLAccessDisabled
                }
                if let dataParser = parser as? ScoreDataParser {
                    return try dataParser.parse(fileURL: url)
                }
                let data = try dataFetcher.data(from: url)
                return try parseData(data, pathExtension: hint ?? url.pathExtension)
            }

            guard options.allowsRemoteURLs else {
                throw MusicXMLLoaderError.remoteURLAccessDisabled
            }
            let data = try dataFetcher.data(from: url)
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
