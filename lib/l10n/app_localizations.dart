import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'ChatTunes'**
  String get appName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @tabLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get tabLibrary;

  /// No description provided for @tabForYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get tabForYou;

  /// No description provided for @tabPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get tabPlaylists;

  /// No description provided for @tabStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get tabStats;

  /// No description provided for @syncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueTitle;

  /// No description provided for @nothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get nothingPlaying;

  /// No description provided for @nowPlayingTitle.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlayingTitle;

  /// No description provided for @addToPlaylistTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylistTooltip;

  /// No description provided for @trackActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get trackActions;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue;

  /// No description provided for @addToPlaylistMenu.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist…'**
  String get addToPlaylistMenu;

  /// No description provided for @removeFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFromLibrary;

  /// No description provided for @deleteTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete track?'**
  String get deleteTrackTitle;

  /// No description provided for @deleteTrackBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will disappear from the library on all devices and from the chat.'**
  String deleteTrackBody(String title);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title or artist'**
  String get searchHint;

  /// No description provided for @favoritesFilter.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesFilter;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTooltip;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewest;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'By title'**
  String get sortTitle;

  /// No description provided for @sortArtist.
  ///
  /// In en, this message translates to:
  /// **'By artist'**
  String get sortArtist;

  /// No description provided for @sortMostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get sortMostPlayed;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Add tracks with the + button or post them in the chat.'**
  String get libraryEmpty;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @addTracksTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add tracks'**
  String get addTracksTooltip;

  /// No description provided for @trackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tracks} =1{1 track} other{{count} tracks}}'**
  String trackCount(int count);

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylist;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @playlistsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet. Create one with the + button or add a track via the “Add to playlist…” menu.'**
  String get playlistsEmpty;

  /// No description provided for @playlistDeleted.
  ///
  /// In en, this message translates to:
  /// **'Playlist deleted'**
  String get playlistDeleted;

  /// No description provided for @deletePlaylistAction.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist'**
  String get deletePlaylistAction;

  /// No description provided for @deletePlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist?'**
  String get deletePlaylistTitle;

  /// No description provided for @deletePlaylistBody.
  ///
  /// In en, this message translates to:
  /// **'The tracks stay in your library.'**
  String get deletePlaylistBody;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get removeFromPlaylist;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @smartPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Smart playlists'**
  String get smartPlaylists;

  /// No description provided for @forYouEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add some music and recommendations will show up here'**
  String get forYouEmpty;

  /// No description provided for @forYouColdStart.
  ///
  /// In en, this message translates to:
  /// **'Not much data yet. Listen to a few tracks to the end and recommendations will adapt to you.'**
  String get forYouColdStart;

  /// No description provided for @mixOfTheDay.
  ///
  /// In en, this message translates to:
  /// **'Daily mix'**
  String get mixOfTheDay;

  /// No description provided for @forgottenTitle.
  ///
  /// In en, this message translates to:
  /// **'Haven’t heard in a while'**
  String get forgottenTitle;

  /// No description provided for @newFromArtistsTitle.
  ///
  /// In en, this message translates to:
  /// **'New from artists you love'**
  String get newFromArtistsTitle;

  /// No description provided for @timeMixMorning.
  ///
  /// In en, this message translates to:
  /// **'Your morning'**
  String get timeMixMorning;

  /// No description provided for @timeMixDay.
  ///
  /// In en, this message translates to:
  /// **'Your afternoon'**
  String get timeMixDay;

  /// No description provided for @timeMixEvening.
  ///
  /// In en, this message translates to:
  /// **'Your evening'**
  String get timeMixEvening;

  /// No description provided for @timeMixNight.
  ///
  /// In en, this message translates to:
  /// **'Your night'**
  String get timeMixNight;

  /// No description provided for @reasonFavoriteArtist.
  ///
  /// In en, this message translates to:
  /// **'favorite artist'**
  String get reasonFavoriteArtist;

  /// No description provided for @reasonOftenPlayed.
  ///
  /// In en, this message translates to:
  /// **'you play it often'**
  String get reasonOftenPlayed;

  /// No description provided for @reasonFavorite.
  ///
  /// In en, this message translates to:
  /// **'in your favorites'**
  String get reasonFavorite;

  /// No description provided for @reasonAfterThis.
  ///
  /// In en, this message translates to:
  /// **'often plays after this track'**
  String get reasonAfterThis;

  /// No description provided for @reasonTimeOfDay.
  ///
  /// In en, this message translates to:
  /// **'fits this time of day'**
  String get reasonTimeOfDay;

  /// No description provided for @reasonNew.
  ///
  /// In en, this message translates to:
  /// **'new in your library'**
  String get reasonNew;

  /// No description provided for @reasonSimilar.
  ///
  /// In en, this message translates to:
  /// **'like what you love'**
  String get reasonSimilar;

  /// No description provided for @reasonNotPlayedDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{not played for {days} day} other{not played for {days} days}}'**
  String reasonNotPlayedDays(int days);

  /// No description provided for @reasonNewFromArtist.
  ///
  /// In en, this message translates to:
  /// **'new from {artist}'**
  String reasonNewFromArtist(String artist);

  /// No description provided for @reasonTimeMix.
  ///
  /// In en, this message translates to:
  /// **'you often play it around now'**
  String get reasonTimeMix;

  /// No description provided for @smartTopMonth.
  ///
  /// In en, this message translates to:
  /// **'Most played this month'**
  String get smartTopMonth;

  /// No description provided for @smartRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get smartRecentlyAdded;

  /// No description provided for @smartNeverPlayed.
  ///
  /// In en, this message translates to:
  /// **'Never played'**
  String get smartNeverPlayed;

  /// No description provided for @smartLoved.
  ///
  /// In en, this message translates to:
  /// **'Loved the most'**
  String get smartLoved;

  /// No description provided for @smartSkipped.
  ///
  /// In en, this message translates to:
  /// **'Often skipped'**
  String get smartSkipped;

  /// No description provided for @statsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Stats will appear after your first listens'**
  String get statsEmpty;

  /// No description provided for @range7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get range7;

  /// No description provided for @range30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get range30;

  /// No description provided for @rangeAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get rangeAll;

  /// No description provided for @statListened.
  ///
  /// In en, this message translates to:
  /// **'Listened'**
  String get statListened;

  /// No description provided for @statPlays.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get statPlays;

  /// No description provided for @statStreak.
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get statStreak;

  /// No description provided for @statSkips.
  ///
  /// In en, this message translates to:
  /// **'Skips'**
  String get statSkips;

  /// No description provided for @minutesPerDay.
  ///
  /// In en, this message translates to:
  /// **'Minutes per day'**
  String get minutesPerDay;

  /// No description provided for @minutesPerDay30.
  ///
  /// In en, this message translates to:
  /// **'Minutes per day (30 days)'**
  String get minutesPerDay30;

  /// No description provided for @whenYouListen.
  ///
  /// In en, this message translates to:
  /// **'When you listen'**
  String get whenYouListen;

  /// No description provided for @topTracks.
  ///
  /// In en, this message translates to:
  /// **'Top tracks'**
  String get topTracks;

  /// No description provided for @topArtists.
  ///
  /// In en, this message translates to:
  /// **'Top artists'**
  String get topArtists;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get unitMinutes;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String durationHours(int hours);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @playsTimes.
  ///
  /// In en, this message translates to:
  /// **'{count} ×'**
  String playsTimes(int count);

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectTitle;

  /// No description provided for @setupSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Create a bot with @BotFather and copy its token.\n2. Create a channel or group and add the bot as an administrator (post, pin and delete messages).\n3. Enter the chat’s @username or its numeric id.'**
  String get setupSteps;

  /// No description provided for @botToken.
  ///
  /// In en, this message translates to:
  /// **'Bot token'**
  String get botToken;

  /// No description provided for @chatField.
  ///
  /// In en, this message translates to:
  /// **'Chat (@name or -100…)'**
  String get chatField;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @playbackSection.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playbackSection;

  /// No description provided for @autoplay.
  ///
  /// In en, this message translates to:
  /// **'Autoplay'**
  String get autoplay;

  /// No description provided for @autoplaySub.
  ///
  /// In en, this message translates to:
  /// **'When the queue ends, keep playing recommended tracks'**
  String get autoplaySub;

  /// No description provided for @prefetch.
  ///
  /// In en, this message translates to:
  /// **'Prefetch'**
  String get prefetch;

  /// No description provided for @prefetchSub.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Don’t download ahead} =1{Download 1 upcoming track ahead} other{Download {count} upcoming tracks ahead}}'**
  String prefetchSub(int count);

  /// No description provided for @cacheSection.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cacheSection;

  /// No description provided for @cacheLimit.
  ///
  /// In en, this message translates to:
  /// **'Cache limit'**
  String get cacheLimit;

  /// No description provided for @cacheUsage.
  ///
  /// In en, this message translates to:
  /// **'{limit} GB · {used} MB used'**
  String cacheUsage(String limit, int used);

  /// No description provided for @favoritesOffline.
  ///
  /// In en, this message translates to:
  /// **'Keep favorites offline'**
  String get favoritesOffline;

  /// No description provided for @favoritesOfflineSub.
  ///
  /// In en, this message translates to:
  /// **'Download them and never evict them from the cache'**
  String get favoritesOfflineSub;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearCacheSub.
  ///
  /// In en, this message translates to:
  /// **'Offline tracks and the current queue stay'**
  String get clearCacheSub;

  /// No description provided for @dataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataSection;

  /// No description provided for @resetStats.
  ///
  /// In en, this message translates to:
  /// **'Reset stats'**
  String get resetStats;

  /// No description provided for @resetStatsSub.
  ///
  /// In en, this message translates to:
  /// **'Deletes the listening history on this device'**
  String get resetStatsSub;

  /// No description provided for @resetStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset stats?'**
  String get resetStatsTitle;

  /// No description provided for @resetStatsBody.
  ///
  /// In en, this message translates to:
  /// **'Recommendations will start from scratch too.'**
  String get resetStatsBody;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect chat'**
  String get disconnect;

  /// No description provided for @disconnectSub.
  ///
  /// In en, this message translates to:
  /// **'The library stays in the chat'**
  String get disconnectSub;

  /// No description provided for @disconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect chat?'**
  String get disconnectTitle;

  /// No description provided for @disconnectBody.
  ///
  /// In en, this message translates to:
  /// **'The local list will be cleared. Everything stays in the chat.'**
  String get disconnectBody;

  /// No description provided for @tokenStoredSecurely.
  ///
  /// In en, this message translates to:
  /// **'The bot token is kept in the system keychain'**
  String get tokenStoredSecurely;

  /// No description provided for @tokenStoredPlain.
  ///
  /// In en, this message translates to:
  /// **'The bot token is kept in app settings, unencrypted (no system keychain found)'**
  String get tokenStoredPlain;

  /// No description provided for @mediaKeysOn.
  ///
  /// In en, this message translates to:
  /// **'Media keys and the system player widget are on'**
  String get mediaKeysOn;

  /// No description provided for @reloadFiles.
  ///
  /// In en, this message translates to:
  /// **'Reload files'**
  String get reloadFiles;

  /// No description provided for @moreTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTooltip;

  /// No description provided for @importFile.
  ///
  /// In en, this message translates to:
  /// **'Import from file…'**
  String get importFile;

  /// No description provided for @pasteClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteClipboard;

  /// No description provided for @copyCurrentTheme.
  ///
  /// In en, this message translates to:
  /// **'Copy current theme (JSON)'**
  String get copyCurrentTheme;

  /// No description provided for @builtInThemes.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtInThemes;

  /// No description provided for @myThemes.
  ///
  /// In en, this message translates to:
  /// **'My themes'**
  String get myThemes;

  /// No description provided for @noUserThemes.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Copy the current theme from the menu (⋮), edit the values in the file in the folder above, and the app updates by itself.'**
  String get noUserThemes;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @themeCopied.
  ///
  /// In en, this message translates to:
  /// **'Theme JSON copied'**
  String get themeCopied;

  /// No description provided for @themeRejected.
  ///
  /// In en, this message translates to:
  /// **'This theme can’t be used'**
  String get themeRejected;

  /// No description provided for @themeFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Themes folder. Drop a .json file here and it shows up in the list.'**
  String get themeFolderHint;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @deleteThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete theme?'**
  String get deleteThemeTitle;

  /// No description provided for @deleteThemeBody.
  ///
  /// In en, this message translates to:
  /// **'The file “{name}” will be deleted.'**
  String deleteThemeBody(String name);

  /// No description provided for @statusNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get statusNoConnection;

  /// No description provided for @statusUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {n}/{total}: {name}'**
  String statusUploading(int n, int total, String name);

  /// No description provided for @statusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get statusSyncing;

  /// No description provided for @errorNotAdmin.
  ///
  /// In en, this message translates to:
  /// **'The bot must be an administrator of the chat'**
  String get errorNotAdmin;

  /// No description provided for @errorFileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File unavailable'**
  String get errorFileUnavailable;

  /// No description provided for @errorFileTooBig.
  ///
  /// In en, this message translates to:
  /// **'The file is over 20 MB, the Bot API won’t serve it'**
  String get errorFileTooBig;

  /// No description provided for @errorDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed ({code})'**
  String errorDownloadFailed(int code);

  /// No description provided for @defaultPlaylistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get defaultPlaylistName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
