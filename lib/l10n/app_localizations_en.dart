// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ChatTunes';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Delete';

  @override
  String get open => 'Open';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get rename => 'Rename';

  @override
  String get name => 'Name';

  @override
  String get refresh => 'Refresh';

  @override
  String get tabLibrary => 'Library';

  @override
  String get tabForYou => 'For you';

  @override
  String get tabPlaylists => 'Playlists';

  @override
  String get tabStats => 'Stats';

  @override
  String get syncTooltip => 'Sync';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get repeat => 'Repeat';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get queueTitle => 'Queue';

  @override
  String get nothingPlaying => 'Nothing playing';

  @override
  String get nowPlayingTitle => 'Now playing';

  @override
  String get addToPlaylistTooltip => 'Add to playlist';

  @override
  String get trackActions => 'Actions';

  @override
  String get playNext => 'Play next';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get addToPlaylistMenu => 'Add to playlist…';

  @override
  String get removeFromLibrary => 'Remove from library';

  @override
  String get deleteTrackTitle => 'Delete track?';

  @override
  String deleteTrackBody(String title) {
    return '“$title” will disappear from the library on all devices and from the chat.';
  }

  @override
  String get searchHint => 'Search by title or artist';

  @override
  String get favoritesFilter => 'Favorites';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortTitle => 'By title';

  @override
  String get sortArtist => 'By artist';

  @override
  String get sortMostPlayed => 'Most played';

  @override
  String get libraryEmpty =>
      'Nothing here yet. Add tracks with the + button or post them in the chat.';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get addTracksTooltip => 'Add tracks';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
      zero: 'No tracks',
    );
    return '$_temp0';
  }

  @override
  String get favorites => 'Favorites';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get playlistsEmpty =>
      'No playlists yet. Create one with the + button or add a track via the “Add to playlist…” menu.';

  @override
  String get playlistDeleted => 'Playlist deleted';

  @override
  String get deletePlaylistAction => 'Delete playlist';

  @override
  String get deletePlaylistTitle => 'Delete playlist?';

  @override
  String get deletePlaylistBody => 'The tracks stay in your library.';

  @override
  String get offline => 'Offline';

  @override
  String get removeFromPlaylist => 'Remove from playlist';

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get smartPlaylists => 'Smart playlists';

  @override
  String get forYouEmpty =>
      'Add some music and recommendations will show up here';

  @override
  String get forYouColdStart =>
      'Not much data yet. Listen to a few tracks to the end and recommendations will adapt to you.';

  @override
  String get mixOfTheDay => 'Daily mix';

  @override
  String get forgottenTitle => 'Haven’t heard in a while';

  @override
  String get newFromArtistsTitle => 'New from artists you love';

  @override
  String get timeMixMorning => 'Your morning';

  @override
  String get timeMixDay => 'Your afternoon';

  @override
  String get timeMixEvening => 'Your evening';

  @override
  String get timeMixNight => 'Your night';

  @override
  String get reasonFavoriteArtist => 'favorite artist';

  @override
  String get reasonOftenPlayed => 'you play it often';

  @override
  String get reasonFavorite => 'in your favorites';

  @override
  String get reasonAfterThis => 'often plays after this track';

  @override
  String get reasonTimeOfDay => 'fits this time of day';

  @override
  String get reasonNew => 'new in your library';

  @override
  String get reasonSimilar => 'like what you love';

  @override
  String reasonNotPlayedDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'not played for $days days',
      one: 'not played for $days day',
    );
    return '$_temp0';
  }

  @override
  String reasonNewFromArtist(String artist) {
    return 'new from $artist';
  }

  @override
  String get reasonTimeMix => 'you often play it around now';

  @override
  String get smartTopMonth => 'Most played this month';

  @override
  String get smartRecentlyAdded => 'Recently added';

  @override
  String get smartNeverPlayed => 'Never played';

  @override
  String get smartLoved => 'Loved the most';

  @override
  String get smartSkipped => 'Often skipped';

  @override
  String get statsEmpty => 'Stats will appear after your first listens';

  @override
  String get range7 => '7 days';

  @override
  String get range30 => '30 days';

  @override
  String get rangeAll => 'All time';

  @override
  String get statListened => 'Listened';

  @override
  String get statPlays => 'Plays';

  @override
  String get statStreak => 'Day streak';

  @override
  String get statSkips => 'Skips';

  @override
  String get minutesPerDay => 'Minutes per day';

  @override
  String get minutesPerDay30 => 'Minutes per day (30 days)';

  @override
  String get whenYouListen => 'When you listen';

  @override
  String get topTracks => 'Top tracks';

  @override
  String get topArtists => 'Top artists';

  @override
  String get unitMinutes => 'min';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String playsTimes(int count) {
    return '$count ×';
  }

  @override
  String get connectTitle => 'Connect';

  @override
  String get setupSteps =>
      '1. Create a bot with @BotFather and copy its token.\n2. Create a channel or group and add the bot as an administrator (post, pin and delete messages).\n3. Enter the chat’s @username or its numeric id.';

  @override
  String get botToken => 'Bot token';

  @override
  String get chatField => 'Chat (@name or -100…)';

  @override
  String get connect => 'Connect';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeTitle => 'Theme';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get playbackSection => 'Playback';

  @override
  String get autoplay => 'Autoplay';

  @override
  String get autoplaySub =>
      'When the queue ends, keep playing recommended tracks';

  @override
  String get prefetch => 'Prefetch';

  @override
  String prefetchSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count upcoming tracks ahead',
      one: 'Download 1 upcoming track ahead',
      zero: 'Don’t download ahead',
    );
    return '$_temp0';
  }

  @override
  String get cacheSection => 'Cache';

  @override
  String get cacheLimit => 'Cache limit';

  @override
  String cacheUsage(String limit, int used) {
    return '$limit GB · $used MB used';
  }

  @override
  String get favoritesOffline => 'Keep favorites offline';

  @override
  String get favoritesOfflineSub =>
      'Download them and never evict them from the cache';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get clearCacheSub => 'Offline tracks and the current queue stay';

  @override
  String get dataSection => 'Data';

  @override
  String get resetStats => 'Reset stats';

  @override
  String get resetStatsSub => 'Deletes the listening history on this device';

  @override
  String get resetStatsTitle => 'Reset stats?';

  @override
  String get resetStatsBody => 'Recommendations will start from scratch too.';

  @override
  String get reset => 'Reset';

  @override
  String get disconnect => 'Disconnect chat';

  @override
  String get disconnectSub => 'The library stays in the chat';

  @override
  String get disconnectTitle => 'Disconnect chat?';

  @override
  String get disconnectBody =>
      'The local list will be cleared. Everything stays in the chat.';

  @override
  String get tokenStoredSecurely =>
      'The bot token is kept in the system keychain';

  @override
  String get tokenStoredPlain =>
      'The bot token is kept in app settings, unencrypted (no system keychain found)';

  @override
  String get mediaKeysOn => 'Media keys and the system player widget are on';

  @override
  String get reloadFiles => 'Reload files';

  @override
  String get moreTooltip => 'More';

  @override
  String get importFile => 'Import from file…';

  @override
  String get pasteClipboard => 'Paste from clipboard';

  @override
  String get copyCurrentTheme => 'Copy current theme (JSON)';

  @override
  String get builtInThemes => 'Built-in';

  @override
  String get myThemes => 'My themes';

  @override
  String get noUserThemes =>
      'Nothing here yet. Copy the current theme from the menu (⋮), edit the values in the file in the folder above, and the app updates by itself.';

  @override
  String get clipboardEmpty => 'The clipboard is empty';

  @override
  String get themeCopied => 'Theme JSON copied';

  @override
  String get themeRejected => 'This theme can’t be used';

  @override
  String get themeFolderHint =>
      'Themes folder. Drop a .json file here and it shows up in the list.';

  @override
  String get copyPath => 'Copy path';

  @override
  String get deleteThemeTitle => 'Delete theme?';

  @override
  String deleteThemeBody(String name) {
    return 'The file “$name” will be deleted.';
  }

  @override
  String get statusNoConnection => 'No connection';

  @override
  String statusUploading(int n, int total, String name) {
    return 'Uploading $n/$total: $name';
  }

  @override
  String get statusSyncing => 'Syncing…';

  @override
  String get errorNotAdmin => 'The bot must be an administrator of the chat';

  @override
  String get errorFileUnavailable => 'File unavailable';

  @override
  String get errorFileTooBig =>
      'The file is over 20 MB, the Bot API won’t serve it';

  @override
  String errorDownloadFailed(int code) {
    return 'Download failed ($code)';
  }

  @override
  String get defaultPlaylistName => 'Playlist';
}
