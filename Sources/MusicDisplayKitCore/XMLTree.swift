import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum XMLTreeParserError: Error, Equatable, CustomStringConvertible, Sendable {
    case emptyInput
    case parseFailure(String)
    case missingRootElement

    public var description: String {
        switch self {
        case .emptyInput:
            return "XML input is empty."
        case .parseFailure(let message):
            return "XML parse failure: \(message)"
        case .missingRootElement:
            return "XML document has no root element."
        }
    }
}

public struct XMLNode: Equatable, Sendable {
    public let name: String
    public let attributes: [String: String]
    public let text: String
    public let children: [XMLNode]

    public init(
        name: String,
        attributes: [String: String] = [:],
        text: String = "",
        children: [XMLNode] = []
    ) {
        self.name = name
        self.attributes = attributes
        self.text = text
        self.children = children
    }

    public var trimmedText: String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    public func attribute(named name: String) -> String? {
        attributes.first(where: { matchesName($0.key, name) })?.value
    }

    public func firstChild(named name: String) -> XMLNode? {
        children.first(where: { matchesName($0.name, name) })
    }

    public func children(named name: String) -> [XMLNode] {
        children.filter { matchesName($0.name, name) }
    }

    public func descendants(named name: String) -> [XMLNode] {
        var result: [XMLNode] = []
        for child in children {
            if matchesName(child.name, name) {
                result.append(child)
            }
            result.append(contentsOf: child.descendants(named: name))
        }
        return result
    }

    public func firstDescendant(path: [String]) -> XMLNode? {
        guard !path.isEmpty else {
            return self
        }
        guard let child = children.first(where: { matchesName($0.name, path[0]) }) else {
            return nil
        }
        return child.firstDescendant(path: Array(path.dropFirst()))
    }
}

public struct XMLTreeParser {
    public init() {}

    public func parse(xml: String) throws -> XMLNode {
        let data = Data(xml.utf8)
        return try parse(data: data)
    }

    public func parse(data: Data) throws -> XMLNode {
        guard !data.isEmpty else {
            throw XMLTreeParserError.emptyInput
        }

        let delegate = XMLTreeDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        let ok = parser.parse()
        if !ok {
            let message = parser.parserError?.localizedDescription ?? "Unknown XML parser error"
            throw XMLTreeParserError.parseFailure(message)
        }
        guard let root = delegate.root else {
            throw XMLTreeParserError.missingRootElement
        }
        return root
    }
}

private final class XMLTreeDelegate: NSObject, XMLParserDelegate {
    private final class Builder {
        let name: String
        let attributes: [String: String]
        var text: String = ""
        var children: [Builder] = []

        init(name: String, attributes: [String: String]) {
            self.name = name
            self.attributes = attributes
        }

        func build() -> XMLNode {
            XMLNode(
                name: name,
                attributes: attributes,
                text: text,
                children: children.map { $0.build() }
            )
        }
    }

    private var stack: [Builder] = []
    private(set) var root: XMLNode?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let builder = Builder(name: elementName, attributes: attributeDict)
        if let parent = stack.last {
            parent.children.append(builder)
        }
        stack.append(builder)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard let completed = stack.popLast() else {
            return
        }
        if stack.isEmpty {
            root = completed.build()
        }
    }
}

private func matchesName(_ lhs: String, _ rhs: String) -> Bool {
    normalizeName(lhs) == normalizeName(rhs)
}

private func normalizeName(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let last = trimmed.split(separator: ":").last {
        return String(last)
    }
    return trimmed
}
