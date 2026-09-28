import Foundation
import XCTest
@testable import MacOptimizer

final class LocalizationTests: XCTestCase {
    func testEveryCatalogHasEnglishAndTurkishValues() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MacOptimizer/Resources")
        let catalogs = try FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xcstrings" }
        XCTAssertEqual(Set(catalogs.map { $0.deletingPathExtension().lastPathComponent }), Set(L10n.Table.allCases.map(\.rawValue)))

        for catalog in catalogs {
            let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any])
            let strings = try XCTUnwrap(root["strings"] as? [String: Any])
            for (key, rawEntry) in strings {
                let entry = try XCTUnwrap(rawEntry as? [String: Any], "Invalid entry \(key) in \(catalog.lastPathComponent)")
                let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], "Missing localizations for \(key)")
                for language in ["en", "tr"] {
                    let localization = try XCTUnwrap(localizations[language] as? [String: Any], "Missing \(language) value for \(key)")
                    let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any], "Missing \(language) string unit for \(key)")
                    XCTAssertFalse((unit["value"] as? String ?? "").isEmpty, "Empty \(language) value for \(key)")
                }
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
}

private extension L10n.Table {
    static var allCases: [Self] { [.common, .dashboard, .cleanup, .ai, .services] }
}
