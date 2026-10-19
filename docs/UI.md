# UI guide

How the interface is organized, so you can change how ChatTunes looks without touching how it works.

## The idea

All visual code lives in `lib/ui/`. Nothing outside it draws anything, and nothing inside it holds
business logic: it only reads the library, the player and the stats, and calls their methods.

```
lib/ui/
  theme/        design tokens, the theme file format, theme loading
  components/   reusable building blocks
  screens/      screens, assembled from components
  format.dart   text formatting helpers
```

Dependencies point one way: **screens use components, components use tokens, tokens come from the
theme.** The logic layer (`lib/*.dart`) never imports `lib/ui/`; only `main.dart` wires the two together.

## Theme

| File | Job |
|---|---|
| `theme/app_tokens.dart` | `AppTokens`: values Material has no slot for (heart color, radii, spacing, cover look, layout). Read with `context.tokens` |
| `theme/layout_spec.dart` | `LayoutSpec`: the `layout` section, the shell tree and its validation |
| `theme/theme_spec.dart` | `ThemeSpec`: parses and validates a theme file and builds Flutter's `ThemeData` |
| `theme/theme_controller.dart` | Finds built-in and user themes, remembers the choice, reloads on file change |

The file format is described in [THEMING.md](THEMING.md) and in `theme.schema.json`.

## Components

Components come in two kinds.

**Presentational** components draw plain values and know nothing about the player or the library. They
are easy to restyle, preview and test: `TrackRow`, `Cover`, `StatCard`, `BarChart`, `SectionTitle`,
`StatusBanner`, `ThemePreview`.

**Connected** components bind a presentational one (or a few controls) to the app state:
`TrackTile` (a `TrackRow` plus its menu), `PlayerDock`, `PlayerControlsRow`, `SeekBar`.

Screens import one file, `components/components.dart`.

## Rules

1. **No hardcoded colors, radii or paddings.** Take colors from `Theme.of(context).colorScheme` or
   `context.tokens`, and spacing and radii from `context.tokens`. That is what makes a theme able to
   restyle the app.
2. **No hardcoded positions.** Where regions go comes from `tokens.layout`. `HomeShell` has no layout
   of its own.
3. **Layouts must survive being squeezed.** A theme can put a 300 px panel next to your widget. Use
   `Wrap`, `Expanded` and `Flexible` instead of fixed-width rows. The layout tests catch overflow.
4. **Components take data, not services, where they can.** Prefer a presentational component and a thin
   connected wrapper.
5. **No text in widgets.** Use `context.l10n.someKey` and add the string to the `.arb` files, see
   [LOCALIZATION.md](LOCALIZATION.md). A test fails on hardcoded Cyrillic, and the translation tests fail
   if a language is missing a key.

## Recipes

### Add a theme option

Say you want a `cover.border` option.

1. Add the field to `AppTokens` (constructor, `defaults`, `copyWith`, `lerp`).
2. Parse and validate it in `ThemeSpec.fromJson` (or `LayoutSpec.parse` for layout), and write it out in
   `toJson`.
3. Add it to `ThemeSpec.knownKeys` (or `LayoutSpec.knownKeys`) and to `docs/theme.schema.json`. A test
   fails if the two disagree.
4. Use it in the component, through `context.tokens`.
5. Document it in `THEMING.md`, and add a test.

### Add a component

1. Create `components/my_widget.dart`, preferably presentational, reading `context.tokens`.
2. Export it from `components/components.dart`.
3. If it needs state, add a thin connected wrapper beside it.

### Add a layout region or tab

Add the value to the enum in `layout_spec.dart`, handle it in `HomeShell._build` (a region) or
`HomeShell._content` and `tab_info.dart` (a tab), extend the schema, and add a layout test in
`test/ui_layout_test.dart`.

## Working on the UI

```bash
flutter run -d linux          # edit, then hot reload with r
flutter test                  # includes layout tests that check where things end up
flutter test test_visual      # renders screens and every theme to build/screenshots/
```

`test_visual` renders in English; set `SCREENSHOT_LOCALE=ru` for another language. It runs the real screens on sample data (`test/support/sample_app.dart`) with no Telegram
and no audio device, so you can see a change on several themes and screen sizes in seconds. It uses
fonts from the Flutter SDK. Shadows render as dark outlines in this tool, which does not happen in the
app.
