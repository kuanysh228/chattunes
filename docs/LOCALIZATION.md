# Localization

ChatTunes speaks English and Russian. The language follows the system by default and can be changed in
**Settings, Language**.

## Where the text lives

Every string the user sees is in `lib/l10n/`:

| File | Role |
|---|---|
| `app_en.arb` | The source. English text, plus the type of every placeholder |
| `app_ru.arb` | Russian |
| `app_localizations*.dart` | Generated from the `.arb` files. Do not edit by hand |

Code reads them with `context.l10n.someKey`. No text is written into widgets, and a test fails if Cyrillic
shows up in the Dart code.

## Add a language

1. Copy `lib/l10n/app_en.arb` to `app_<code>.arb`, for example `app_de.arb`, and change `@@locale`.
2. Translate every value. Keep the `{placeholders}` as they are. Delete the `@key` metadata blocks, which
   only the English file needs.
3. Add the language's own name to `languageNames` in `lib/ui/l10n.dart`:

   ```dart
   const languageNames = {
     'en': 'English',
     'ru': 'Русский',
     'de': 'Deutsch',
   };
   ```
4. Run `flutter gen-l10n`, then `flutter test`.

The tests check that your file has every key and no extras, that each message uses the same placeholders as
the English one, that nothing is empty, and that you did not just copy English. That is usually enough to
catch a mistake before review.

### Plurals

Counts use ICU plural syntax, because languages differ in how many forms they have. English needs `one` and
`other`; Russian needs `one`, `few`, `many` and `other`.

```json
"trackCount": "{count, plural, =0{No tracks} =1{1 track} other{{count} tracks}}"
```

Use the plural categories of your language. See the
[CLDR plural rules](https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html).

## Add or change a string

1. Add the key to `app_en.arb`. If it has a placeholder that is not text, declare its type in the `@key`
   block next to it.
2. Add the translation to every other `.arb` file.
3. Run `flutter gen-l10n` and use `context.l10n.yourKey`.

Text that comes from logic rather than from a widget, such as errors and recommendation reasons, is passed
around as data (an enum with parameters) and translated at the edge, in `lib/ui/l10n.dart`. That keeps the
logic layer free of any language.

## What is not translated

Theme files are for authors, so the messages the theme loader prints are English. Text that Telegram itself
returns in an error is shown as Telegram wrote it.
