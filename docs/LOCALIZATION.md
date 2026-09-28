# Localization

Add each key and translation to the area's table in
`Sources/MacOptimizer/Resources/en.lproj/<table>.strings` and
`Sources/MacOptimizer/Resources/tr.lproj/<table>.strings`. Keep English as the key/source value; use
`Text(l10n: "English text", table: .common)` in SwiftUI or
`L10n.string("English text", table: .common)` for plain strings. For formatted strings, use
`L10n.string("Found %lld items", table: .common, count)` with matching format specifiers in both
languages.

Use `.stringsdict` for count-dependent grammar; do not build plurals by joining translated fragments.
Format specifiers must match between languages and the localization test enforces this.

| Table | Area |
| --- | --- |
| `common` | App shell, shared labels, and common UI |
| `dashboard` | Dashboard |
| `cleanup` | Junk cleaner, duplicate finder, app manager, maintenance, and startup |
| `ai` | AI and settings |
| `services` | Service and operation messages |

Keep interpolation placeholders type-compatible (`%lld` for integer counts, `%@` for strings) in
English and Turkish. Every key needs a non-empty value in both languages.
