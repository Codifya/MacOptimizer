import Foundation

/// Lightweight XML Appcast Parser for Sparkle feeds (standard macOS update distribution)
public final class AppcastParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    public struct AppcastItem {
        public var version: String = ""
        public var shortVersion: String = ""
        public var downloadURL: String = ""
        public var releaseNotesURL: String = ""
        public var pubDate: String = ""
        public var title: String = ""
    }
    
    private var items: [AppcastItem] = []
    private var currentItem: AppcastItem?
    private var currentElement: String = ""
    private var currentText: String = ""
    
    public static func parse(data: Data) -> [AppcastItem] {
        let parser = AppcastParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.items
    }
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""
        
        if elementName == "item" {
            currentItem = AppcastItem()
        }
        
        if elementName == "enclosure" && currentItem != nil {
            if let version = attributeDict["sparkle:version"] ?? attributeDict["version"] {
                currentItem?.version = version
            }
            if let shortVer = attributeDict["sparkle:shortVersionString"] ?? attributeDict["shortVersionString"] {
                currentItem?.shortVersion = shortVer
            }
            if let url = attributeDict["url"] {
                currentItem?.downloadURL = url
            }
        }
        
        if elementName == "sparkle:releaseNotesLink" && currentItem != nil {
            if let url = attributeDict["url"] {
                currentItem?.releaseNotesURL = url
            }
        }
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if elementName == "title" && currentItem != nil {
            currentItem?.title = trimmed
        } else if (elementName == "sparkle:shortVersionString" || elementName == "shortVersionString") && currentItem != nil {
            if currentItem?.shortVersion.isEmpty ?? true {
                currentItem?.shortVersion = trimmed
            }
        } else if (elementName == "sparkle:version" || elementName == "version") && currentItem != nil {
            if currentItem?.version.isEmpty ?? true {
                currentItem?.version = trimmed
            }
        } else if elementName == "pubDate" && currentItem != nil {
            currentItem?.pubDate = trimmed
        } else if elementName == "item" {
            if let item = currentItem {
                items.append(item)
            }
            currentItem = nil
        }
    }
}
