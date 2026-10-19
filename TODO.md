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

## Next

Things that block calling it a real daily-driver player.

- [ ] **Visual QA of the main UI.** Only the setup screen has been launched; walk every tab with a real library
- [ ] **Verify upload and polling on the real bot** (`sendAudio`, `getUpdates`), not only the fake server
- [ ] **Media keys and MPRIS on Linux** (play/pause/next from keyboard, desktop widgets)
- [ ] **Android build**: set up the SDK, background playback and notification controls
- [ ] **Read real tags** (ID3/Vorbis, embedded cover) on upload instead of guessing from the file name
- [ ] **Covers**: embedded art, or the audio message thumbnail, instead of the generated placeholder
- [ ] **Flush the listening log on exit** so a track cut off by closing the app still counts
- [ ] **Secure token storage** (keychain / libsecret) instead of plain app settings
- [ ] **Localization**: English and Russian (UI is Russian only today)

## Soon

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
