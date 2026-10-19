# TODO

Living list of what ChatTunes has and what we want to build. Checked items are done.

## Done

**Core**
- [x] Bot API client: upload, download (streamed, no half-written files), polling, admin check
- [x] Library synced through a pinned JSON index, edited in place (no "pinned a message" spam in groups)
- [x] Unchanged index is not downloaded again on every poll
- [x] Cross-device merge (latest edit wins, removals, re-upload revives)
- [x] Groups and supergroups as well as channels
- [x] Tested end to end with two simulated devices on one fake chat, and once against a real bot
      (`test_real/`, restores the chat afterwards)

**Player**
- [x] Queue with shuffle, repeat, play next, add to queue, reorder
- [x] Prefetch of the next tracks, LRU cache limit, offline favorites and playlists
- [x] Favorites, playlists (reorder, rename, delete, offline flag)
- [x] Smart playlists: most played this month, recently added, never played, loved the most, often skipped
- [x] **Tags and cover art** read from the audio file on upload (mp3, flac, m4a, ogg...), cover sent to
      Telegram as the thumbnail and downloaded by the other devices
- [x] **Media keys, the desktop player widget and `playerctl`** via MPRIS (Linux), tested on the real session bus

**Stats and recommendations**
- [x] Listening log and stats screen (day/hour charts, streak, top tracks and artists)
- [x] A listen cut short by closing the app or a crash is recovered on the next start
- [x] **Listening history synced between devices**, with a reset that cannot be undone by another device
- [x] Recommender: daily mix, forgotten favorites, new from liked artists, autoplay radio
- [x] **Time-of-day mixes** learned from when you actually listen

**Privacy and polish**
- [x] **Bot token in the system keychain**, with an automatic move from the old plain-text setting and a
      fallback when there is no keychain
- [x] **Localization**: English and Russian, plurals handled, language picker, [guide for adding more](docs/LOCALIZATION.md)
- [x] Theme system: one JSON file for colors, shapes, spacing, type scale, covers **and layout**
- [x] UI split into `lib/ui` (theme, components, screens), JSON schema for themes, [docs](docs)
- [x] `flutter test test_visual`: renders every screen and theme from sample data, no device needed
- [x] CI: analyze + tests

## Next

- [ ] **Android build**: set up the SDK, background playback and notification controls
      (the MPRIS code is Linux-only; Android needs `audio_service` or similar behind the same `MediaTarget`)
- [ ] **Beat the 20 MB limit**: transcode big files on upload, support a self-hosted Bot API server,
      or add an MTProto backend (TDLib) as an alternative
- [ ] **Do not lose posts after 24 h offline**: surface a clear notice, and/or make the app the default upload path
- [ ] **Drag and drop** files onto the window on desktop; per-file upload progress; duplicate detection
- [ ] **Release builds**: Linux tarball / AppImage attached to GitHub releases from CI
- [ ] Windows and macOS media controls (SMTC / Now Playing)

## Soon

Themes and UI:

- [ ] Follow the system light/dark setting with a pair of themes
- [ ] Custom fonts in themes
- [ ] More layout freedom: dock the queue as a panel, move the search field, split statistics into movable cards
- [ ] Share themes through the chat itself, like the library index
- [ ] Visual regression checks in CI from the `test_visual` renders
- [ ] Theme gallery in the app for `themes/community/`

Everything else:

- [ ] **Large libraries**: check index size and list performance around 5k+ tracks
- [ ] Cover art for tracks posted by hand that Telegram sent without a thumbnail
- [ ] Synced lyrics (LRC) when present in tags or an accompanying file
- [ ] More languages
- [ ] Read tags again when a file's tags are edited

## Ideas

- [ ] Sleep timer
- [ ] Gapless playback and crossfade
- [ ] Equalizer
- [ ] "Start radio from this track" in the track menu
- [ ] Mixes by activity ("workout", "focus") if habits show a clear pattern
- [ ] Import from a folder / another Telegram chat
- [ ] Share a library read-only with a friend (token-less invite)
- [ ] Export / import stats and settings
- [ ] Undo for deleting a track

## Known issues

- Tracks migrated from the v1 index have no add date, so they sort as the oldest
- The track context menu always offers "Delete from library", with a confirmation but no undo
- Recommendation reasons are heuristic labels, not exact explanations
- Screens render shadows as dark outlines in `test_visual`; the real app is fine
- The `$schema` link in docs points at the GitHub raw URL, which only works once the repository is public
- mpv prints `lavf: Failed to create file cache` once at startup; playback is unaffected so far, but the cause is not tracked down
- Statistics are rounded to whole seconds when shared between devices
