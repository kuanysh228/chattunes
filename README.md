# ChatTunes

[![CI](https://github.com/kuanysh228/chattunes/actions/workflows/ci.yml/badge.svg)](https://github.com/kuanysh228/chattunes/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)
![Linux](https://img.shields.io/badge/Linux-supported-success)
![Android](https://img.shields.io/badge/Android-not%20built%20yet-lightgrey)

A serverless music player that uses **your own Telegram chat as the library**.
Every device is its own server: it downloads, caches, tracks your listening and recommends music.

Drop a track into the chat and it shows up on all your devices. No accounts, no subscriptions,
no third-party servers: just your bot and your chat.

> **Status:** early (v0.1). Linux only so far. The core Bot API flow (index sync, download) is
> verified against the real API; see the [TODO](TODO.md) for what is still unchecked and what is next.

## Features

| | |
|---|---|
| **Library** | Search, sort (newest, title, artist, most played), favorites filter |
| **Playlists & favorites** | Create, rename, drag to reorder. Synced across devices |
| **Player** | Draggable queue, shuffle, repeat (off / all / one), play next, mini player |
| **Prefetch** | The next 1-5 queue items download ahead of time, so skipping never waits |
| **Offline** | Keep favorites and chosen playlists on the device; cache is capped with LRU eviction |
| **Stats** | Listening time, plays, day streak, skip rate, charts by day and hour, top tracks and artists |
| **Recommendations** | Daily mix, "Haven't heard in a while", "New from artists you love", autoplay |
| **Themes** | A theme is one JSON file: colors, shapes, and the **layout** itself. Move the player to the top or a side panel, reorder tabs, pick the controls. Edit the file and the app restyles live |

<p>
  <img src="docs/screenshots/theme-chattunes-dark-phone.png" width="23%" alt="Library, dark theme">
  <img src="docs/screenshots/tab-foryou.png" width="23%" alt="For you: recommendations">
  <img src="docs/screenshots/tab-stats.png" width="23%" alt="Statistics">
  <img src="docs/screenshots/theme-sunset-phone.png" width="23%" alt="Sunset theme: player on top">
</p>

<sub>Screenshots are rendered from sample data by `flutter test test_visual`.</sub>

## Make it yours

The whole look is data. Themes can recolor the app and also **rearrange it**: here the player sits at
the top, there it is a panel on the right of a desktop layout.

```json
{
  "format": 1,
  "name": "Ocean",
  "colors": { "seed": "#0288D1" },
  "shape": { "radius": 20, "coverRadius": 0.5 },
  "layout": { "shell": { "column": ["header", "player", "content", "navigation"] } }
}
```

Drop the file in the themes folder (Settings, Theme shows where) and save: the app updates instantly.
Share a theme by sending the JSON or by opening a pull request.

- [docs/THEMING.md](docs/THEMING.md): the full theme format and examples
- [docs/UI.md](docs/UI.md): how the UI code is organized, for changing more than a theme can
- [themes/](themes): the bundled themes, which double as examples

![Terminal theme on desktop: rail left, player panel right](docs/screenshots/theme-terminal-desktop.png)

## How it works

```mermaid
flowchart LR
    subgraph device [Your device]
        UI[UI] --> P[Player: queue, prefetch]
        P --> C[(Audio cache, LRU)]
        P --> S[Listening log]
        S --> R[Recommender]
        UI --> L[Library]
    end
    L <-->|pinned JSON index| TG[(Your Telegram chat)]
    C <-->|getFile| TG
    UI -->|sendAudio| TG
```

- **Storage** is the audio messages in your chat. The bot downloads them through the Bot API.
- **Sync** works through a single JSON document pinned in the chat. It holds the library, favorites,
  playlists and removals. The app edits that message in place, so groups do not fill up with
  "pinned a message" service posts.
- **Conflicts** resolve without a server: the latest edit of each item wins, and a removed track
  stays removed until it is uploaded again.
- **Stats and recommendations** live on the device only. Your listening history never leaves it.

### How recommendations work

No audio features and no network, just your history: plays, skips and favorites.

- a listen loses half of its weight every 30 days;
- artists and tracks you play rise, tracks you keep skipping sink;
- time of day matters, and so does what usually plays *after* the current track;
- anything played in the last hours is pushed down for a while;
- one artist cannot fill the whole mix;
- with little history, it falls back to the newest tracks in your library.

## Quick start

1. Create a bot with [@BotFather](https://t.me/BotFather) and copy its token.
2. Create a channel or group and add the bot as an **administrator**
   (post, pin and delete messages).
3. Start the app, paste the token and the chat id (`@username` or `-100...`).
4. Add tracks with the **+** button, or just post audio into the chat.

## Building

Requires [Flutter](https://docs.flutter.dev/get-started/install) (stable).

```bash
flutter pub get
flutter run -d linux           # run
flutter build linux --release  # build
```

Linux needs `clang`, `cmake`, `ninja`, `gtk3` and `mpv` (playback goes through libmpv):

```bash
# Arch
sudo pacman -S clang cmake ninja gtk3 mpv
```

## Tests

```bash
flutter analyze
flutter test                # unit and layout tests
flutter test test_visual    # screenshots of every theme, in build/screenshots/
```

Tests cover cross-device merging, stats, recommendations, the cache, the Bot API client (against a
local fake server that mirrors the real behavior), the theme format, and where the UI puts things
for different layouts.

## Project layout

| Path | Contents |
|---|---|
| `lib/telegram_api.dart` | Bot API client: upload, download, polling, index |
| `lib/sync_data.dart` | Synced data model and merge rules |
| `lib/library_store.dart` | Library, favorites, playlists, sync loop |
| `lib/player_service.dart` | Queue, playback, prefetch, offline, listening log |
| `lib/recommender.dart` | Recommendations |
| `lib/stats.dart` | Listening log and aggregates |
| `lib/cache_manager.dart` | Least-recently-used cache eviction |
| `lib/ui/theme/` | Theme format, design tokens, theme loading |
| `lib/ui/components/` | Reusable UI building blocks |
| `lib/ui/screens/` | Screens |
| `themes/` | Bundled themes and examples |
| `docs/` | Theming and UI guides, theme JSON schema, screenshots |
| `test/` | Tests, including the fake Bot API and layout tests |
| `test_visual/` | Renders screens and themes to images, no device needed |

> The project used to be called TeleMusic. The Dart package name (`telemusic`), the app id and the
> index file name (`telemusic_library.json`) are unchanged on purpose, so existing settings and
> libraries already stored in a chat keep working.

## Limitations

- **Files over 20 MB cannot be downloaded.** That is a Bot API limit; such tracks are flagged with an error.
- If you post tracks into the chat by hand, open the app at least once a day: Telegram keeps
  unprocessed updates for 24 hours. Tracks uploaded through the app are not affected.
- The bot token is stored on the device in app settings, **unencrypted**.
  Use a dedicated bot for the player.
- Stats are not synced, so recommendations differ per device.
- A listen cut short by closing the app is not recorded.
- The UI is currently in Russian only.

## Related projects

- [abn3li/TeleMusic](https://github.com/abn3li/TeleMusic): a native Android app (Kotlin, TDLib)
  that also turns a Telegram channel into a music library, with a much larger feature set.
  ChatTunes differs in using a bot token instead of a user session, running on desktop, and
  keeping everything on-device.

## License

[MIT](LICENSE) © 2026 Kuanysh. Do whatever you want with it, just keep the copyright notice.
