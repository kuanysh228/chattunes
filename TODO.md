# TODO

Living list of what ChatTunes has and what we want to build. Checked items are done.

## Done (v0.1)

- [x] Bot API client: upload, download (streamed, no half-written files), polling, admin check
- [x] Library synced through a pinned JSON index, edited in place
- [x] Cross-device merge (latest edit wins, removals, re-upload revives)
- [x] Favorites, playlists (reorder, rename, delete, offline flag)
- [x] Queue with shuffle, repeat, play next, add to queue, reorder
- [x] Prefetch of the next tracks, LRU cache limit, offline favorites and playlists
- [x] Listening log and stats screen (day/hour charts, streak, top tracks and artists)
- [x] Recommender: daily mix, forgotten favorites, new from liked artists, autoplay radio
- [x] Groups and supergroups as well as channels
- [x] Tests incl. a fake Bot API server; verified once against the real Bot API
- [x] CI: analyze + tests
- [x] **Theme system**: a theme is one JSON file (colors, shapes, spacing, type scale, covers) and also
      controls the **layout**: shell tree (player top/side, navigation anywhere), tabs, player controls,
      Now Playing arrangement, track rows
- [x] Live reload of theme files, import from file or clipboard, export, error reporting, readability warnings
- [x] UI split into `lib/ui` (theme, components, screens), JSON schema for themes, [docs](docs)
- [x] `flutter test test_visual`: renders every screen and theme from sample data, no device needed

## Next

Things that block calling it a real daily-driver player.

- [ ] **Run the main UI for real.** Layouts are checked in tests and rendered screenshots, but the app has not been driven by hand with a real library
- [ ] **Verify upload and polling on the real bot** (`sendAudio`, `getUpdates`), not only the fake server
- [ ] **Media keys and MPRIS on Linux** (play/pause/next from keyboard, desktop widgets)
- [ ] **Android build**: set up the SDK, background playback and notification controls
- [ ] **Read real tags** (ID3/Vorbis, embedded cover) on upload instead of guessing from the file name
- [ ] **Covers**: embedded art, or the audio message thumbnail, instead of the generated placeholder
- [ ] **Flush the listening log on exit** so a track cut off by closing the app still counts
- [ ] **Secure token storage** (keychain / libsecret) instead of plain app settings
- [ ] **Localization**: English and Russian (UI is Russian only today)

## Soon

Themes and UI:

- [ ] Follow the system light/dark setting with a pair of themes
- [ ] Custom fonts in themes
- [ ] More layout freedom: dock the queue as a panel, move the search field, split statistics into movable cards
- [ ] Share themes through the chat itself, like the library index
- [ ] Visual regression checks in CI from the `test_visual` renders
- [ ] Theme gallery in the app for `themes/community/`

Everything else:

- [ ] **Beat the 20 MB limit**: transcode big files on upload, support a self-hosted Bot API server,
      or add an MTProto backend (TDLib) as an alternative
- [ ] **Sync listening history** between devices so recommendations match everywhere
- [ ] **Do not lose posts after 24 h offline**: surface a clear notice, and/or make the app the default upload path
- [ ] **Drag and drop** files onto the window on desktop; per-file upload progress; duplicate detection
- [ ] **Release builds**: Linux tarball / AppImage attached to GitHub releases from CI
- [ ] **Large libraries**: check index size and list performance around 5k+ tracks
- [ ] Synced lyrics (LRC) when present in tags or an accompanying file

## Ideas

- [ ] Sleep timer
- [ ] Gapless playback and crossfade
- [ ] Equalizer
- [ ] Time-of-day mixes ("morning", "workout") learned from habits
- [ ] "Start radio from this track" in the track menu
- [ ] Smart playlists (most played this month, recently added, never played)
- [ ] Import from a folder / another Telegram chat
- [ ] Windows and macOS builds
- [ ] Share a library read-only with a friend (token-less invite)
- [ ] Export / import stats and settings

## Known issues

- Tracks migrated from the v1 index have no add date, so they sort as the oldest
- The track context menu always offers "Delete from library", with a confirmation but no undo
- Recommendation reasons are heuristic labels, not exact explanations
- Screens render shadows as dark outlines in `test_visual`; the real app is fine
- The `$schema` link in docs points at the GitHub raw URL, which only works once the repository is public
