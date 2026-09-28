# Localization

Add the English source and Turkish translation to the appropriate `.xcstrings` catalog under
`Sources/MacOptimizer/Resources/`, then add the matching entry to that table in both
`en.lproj/<table>.strings` and `tr.lproj/<table>.strings`. Keep English as the key/source value; use
`Text(l10n: "English text", table: .common)` in SwiftUI or
`L10n.string("English text", table: .common)` for plain strings. For formatted strings, use
`L10n.string("Found %lld items", table: .common, count)` with matching format specifiers in both
languages.

The repository CI uses Xcode 16.4. SwiftPM did not package the Turkish localization from `.xcstrings`
with that toolchain, so the app processes the matching `.strings` resources at runtime. The catalogs
remain the source inventory and the catalog test checks their completeness.

| Table | Area |
| --- | --- |
| `common` | App shell, shared labels, and common UI |
| `dashboard` | Dashboard |
| `cleanup` | Junk cleaner, duplicate finder, app manager, maintenance, and startup |
| `ai` | AI and settings |
| `services` | Service and operation messages |

Use String Catalog plural variations for count-dependent grammar; do not build plurals by joining
translated fragments. Keep interpolation placeholders type-compatible (`%lld` for integer counts,
`%@` for strings) in English and Turkish. Every key needs a non-empty value in both languages.
