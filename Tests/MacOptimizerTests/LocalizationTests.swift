import Foundation
import XCTest
@testable import MacOptimizer

final class LocalizationTests: XCTestCase {
    private let tables = ["common", "dashboard", "cleanup", "ai", "services"]

    func testEveryTableHasMatchingEnglishAndTurkishValues() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/MacOptimizer/Resources")

        for table in tables {
            let english = try entries(in: resources, language: "en", table: table)
            let turkish = try entries(in: resources, language: "tr", table: table)
            XCTAssertEqual(Set(english.keys), Set(turkish.keys), "Key mismatch in \(table)")
            for key in english.keys {
                let en = try XCTUnwrap(english[key])
                let tr = try XCTUnwrap(turkish[key])
                XCTAssertFalse(en.values.isEmpty || en.values.contains(""), "Empty English value for \(key)")
                XCTAssertFalse(tr.values.isEmpty || tr.values.contains(""), "Empty Turkish value for \(key)")
                XCTAssertEqual(en.specifiers, tr.specifiers, "Format specifier mismatch for \(key)")
            }
        }
    }

    func testModuleBundleHasEnglishAndTurkishLocalizations() {
        XCTAssertTrue(Bundle.module.localizations.contains("en"))
        XCTAssertTrue(Bundle.module.localizations.contains("tr"))
    }

    func testCommonKeyResolvesInBothLanguages() {
        XCTAssertEqual(L10n.string("Dashboard", language: "en"), "Dashboard")
        XCTAssertEqual(L10n.string("Dashboard", language: "tr"), "Genel Bakış")
    }

    func testLookupUsesPreferredAppleLanguage() {
        let prior = UserDefaults.standard.object(forKey: "AppleLanguages")
        UserDefaults.standard.set(["tr"], forKey: "AppleLanguages")
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: "AppleLanguages") }
            else { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
        }
        XCTAssertEqual(L10n.string("Dashboard"), "Genel Bakış")
    }

    private struct Entry {
        var values: [String]
        var specifiers: [String]
    }

    private func entries(in root: URL, language: String, table: String) throws -> [String: Entry] {
        let directory = root.appendingPathComponent("\(language).lproj")
        var result: [String: Entry] = [:]
        let stringsURL = directory.appendingPathComponent("\(table).strings")
        XCTAssertTrue(FileManager.default.fileExists(atPath: stringsURL.path), "Missing \(stringsURL.path)")
        for ext in ["strings", "stringsdict"] {
            let url = directory.appendingPathComponent("\(table).\(ext)")
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let data = try Data(contentsOf: url)
            let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dictionary = object as? [String: Any] else {
                XCTFail("Invalid \(url.lastPathComponent)")
                continue
            }
            for (key, value) in dictionary {
                let strings = stringValues(value)
                let specifiers = strings.flatMap(formatSpecifiers)
                var entry = result[key] ?? Entry(values: [], specifiers: [])
                entry.values += strings
                entry.specifiers += specifiers
                result[key] = entry
            }
        }
        return result
    }

    private func stringValues(_ value: Any) -> [String] {
        if let string = value as? String { return [string] }
        if let dictionary = value as? [String: Any] {
            return dictionary.filter { !$0.key.hasPrefix("NSString") }.values.flatMap(stringValues)
        }
        if let array = value as? [Any] { return array.flatMap(stringValues) }
        return []
    }

    private func formatSpecifiers(in value: String) -> [String] {
        let pattern = #"%(?:[0-9]+\$)?[-+#0 ]*(?:[0-9]+|\*)?(?:\.(?:[0-9]+|\*))?(?:hh|h|ll|l|L|z|t|j)?[@diuoxXfFeEgGaAcCsSp]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: range).compactMap { Range($0.range, in: value).map { String(value[$0]) } }.sorted()
    }
}
