import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../library_store.dart';
import '../recommender.dart';
import '../smart_playlists.dart';
import '../telegram_api.dart';

export '../l10n/app_localizations.dart';

/// Each language's own name, shown in the language picker. Add a line here when
/// you add a translation (see docs/LOCALIZATION.md). A language missing from
/// the list is shown by its code.
const languageNames = {
  'en': 'English',
  'ru': 'Русский',
};

/// `context.l10n.someText`: the translated strings of the current language.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// "3 h 20 min" / "45 min" for listening totals.
String fmtSpent(AppLocalizations l, int ms) {
  final minutes = ms ~/ 60000;
  if (minutes < 60) return l.durationMinutes(minutes);
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? l.durationHours(h) : l.durationHoursMinutes(h, m);
}

String reasonText(AppLocalizations l, RecReason r) => switch (r.kind) {
      RecReasonKind.favoriteArtist => l.reasonFavoriteArtist,
      RecReasonKind.oftenPlayed => l.reasonOftenPlayed,
      RecReasonKind.favorite => l.reasonFavorite,
      RecReasonKind.afterThis => l.reasonAfterThis,
      RecReasonKind.timeOfDay => l.reasonTimeOfDay,
      RecReasonKind.newInLibrary => l.reasonNew,
      RecReasonKind.similar => l.reasonSimilar,
      RecReasonKind.notPlayedDays => l.reasonNotPlayedDays(r.days ?? 0),
      RecReasonKind.newFromArtist => l.reasonNewFromArtist(r.artist ?? ''),
      RecReasonKind.timeMix => l.reasonTimeMix,
    };

/// Turns any error we store into text in the user's language. Errors from
/// Telegram itself keep Telegram's own English description.
String errorText(AppLocalizations l, Object error) {
  if (error is TelegramException) {
    return switch (error.kind) {
      TelegramErrorKind.notAdmin => l.errorNotAdmin,
      TelegramErrorKind.fileUnavailable => l.errorFileUnavailable,
      TelegramErrorKind.fileTooBig => l.errorFileTooBig,
      TelegramErrorKind.downloadFailed => l.errorDownloadFailed(error.code ?? 0),
      TelegramErrorKind.api => error.message,
    };
  }
  return '$error';
}

String statusText(AppLocalizations l, LibraryStatus s) => switch (s.kind) {
      StatusKind.noConnection => l.statusNoConnection,
      StatusKind.uploading => l.statusUploading(s.current ?? 0, s.total ?? 0, s.name ?? ''),
      StatusKind.error => errorText(l, s.error ?? ''),
    };

String dayPartTitle(AppLocalizations l, DayPart p) => switch (p) {
      DayPart.morning => l.timeMixMorning,
      DayPart.day => l.timeMixDay,
      DayPart.evening => l.timeMixEvening,
      DayPart.night => l.timeMixNight,
    };

String smartPlaylistTitle(AppLocalizations l, SmartPlaylist s) => switch (s) {
      SmartPlaylist.topMonth => l.smartTopMonth,
      SmartPlaylist.recentlyAdded => l.smartRecentlyAdded,
      SmartPlaylist.neverPlayed => l.smartNeverPlayed,
      SmartPlaylist.loved => l.smartLoved,
      SmartPlaylist.skipped => l.smartSkipped,
    };
