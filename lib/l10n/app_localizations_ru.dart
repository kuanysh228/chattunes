// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'ChatTunes';

  @override
  String get cancel => 'Отмена';

  @override
  String get done => 'Готово';

  @override
  String get ok => 'Ок';

  @override
  String get delete => 'Удалить';

  @override
  String get open => 'Открыть';

  @override
  String get play => 'Играть';

  @override
  String get pause => 'Пауза';

  @override
  String get shuffle => 'Перемешать';

  @override
  String get rename => 'Переименовать';

  @override
  String get name => 'Название';

  @override
  String get refresh => 'Обновить';

  @override
  String get tabLibrary => 'Библиотека';

  @override
  String get tabForYou => 'Для вас';

  @override
  String get tabPlaylists => 'Плейлисты';

  @override
  String get tabStats => 'Статистика';

  @override
  String get syncTooltip => 'Синхронизировать';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get previous => 'Предыдущий';

  @override
  String get next => 'Следующий';

  @override
  String get repeat => 'Повтор';

  @override
  String get addToFavorites => 'В избранное';

  @override
  String get removeFromFavorites => 'Убрать из избранного';

  @override
  String get queueTitle => 'Очередь';

  @override
  String get nothingPlaying => 'Ничего не играет';

  @override
  String get nowPlayingTitle => 'Сейчас играет';

  @override
  String get addToPlaylistTooltip => 'В плейлист';

  @override
  String get trackActions => 'Действия';

  @override
  String get playNext => 'Играть далее';

  @override
  String get addToQueue => 'В очередь';

  @override
  String get addToPlaylistMenu => 'В плейлист…';

  @override
  String get removeFromLibrary => 'Удалить из библиотеки';

  @override
  String get deleteTrackTitle => 'Удалить трек?';

  @override
  String deleteTrackBody(String title) {
    return '«$title» исчезнет из библиотеки на всех устройствах и из канала.';
  }

  @override
  String get searchHint => 'Поиск по названию и исполнителю';

  @override
  String get favoritesFilter => 'Избранное';

  @override
  String get sortTooltip => 'Сортировка';

  @override
  String get sortNewest => 'Сначала новые';

  @override
  String get sortTitle => 'По названию';

  @override
  String get sortArtist => 'По исполнителю';

  @override
  String get sortMostPlayed => 'Чаще слушаемые';

  @override
  String get libraryEmpty =>
      'Пока пусто. Добавь треки кнопкой + или кинь их в канал.';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get addTracksTooltip => 'Добавить треки';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count трека',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
      zero: 'Нет треков',
    );
    return '$_temp0';
  }

  @override
  String get favorites => 'Избранное';

  @override
  String get newPlaylist => 'Новый плейлист';

  @override
  String get playlistName => 'Название плейлиста';

  @override
  String get playlistsEmpty =>
      'Плейлистов пока нет. Создай первый кнопкой + или добавь трек через меню «В плейлист…».';

  @override
  String get playlistDeleted => 'Плейлист удалён';

  @override
  String get deletePlaylistAction => 'Удалить плейлист';

  @override
  String get deletePlaylistTitle => 'Удалить плейлист?';

  @override
  String get deletePlaylistBody => 'Треки останутся в библиотеке.';

  @override
  String get offline => 'Офлайн';

  @override
  String get removeFromPlaylist => 'Убрать из плейлиста';

  @override
  String get nothingHereYet => 'Здесь пока пусто';

  @override
  String get smartPlaylists => 'Умные плейлисты';

  @override
  String get forYouEmpty => 'Добавь музыку, и здесь появятся рекомендации';

  @override
  String get forYouColdStart =>
      'Пока мало данных. Послушай несколько треков до конца, и рекомендации подстроятся под тебя.';

  @override
  String get mixOfTheDay => 'Микс дня';

  @override
  String get forgottenTitle => 'Давно не слушали';

  @override
  String get newFromArtistsTitle => 'Новое у любимых исполнителей';

  @override
  String get timeMixMorning => 'Ваше утро';

  @override
  String get timeMixDay => 'Ваш день';

  @override
  String get timeMixEvening => 'Ваш вечер';

  @override
  String get timeMixNight => 'Ваша ночь';

  @override
  String get reasonFavoriteArtist => 'любимый исполнитель';

  @override
  String get reasonOftenPlayed => 'часто слушаете';

  @override
  String get reasonFavorite => 'в избранном';

  @override
  String get reasonAfterThis => 'часто играет после этого трека';

  @override
  String get reasonTimeOfDay => 'под это время суток';

  @override
  String get reasonNew => 'новое в вашей библиотеке';

  @override
  String get reasonSimilar => 'похоже на то, что вы любите';

  @override
  String reasonNotPlayedDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'не слушали $days дня',
      many: 'не слушали $days дней',
      few: 'не слушали $days дня',
      one: 'не слушали $days день',
    );
    return '$_temp0';
  }

  @override
  String reasonNewFromArtist(String artist) {
    return 'новое у «$artist»';
  }

  @override
  String get reasonTimeMix => 'часто играете в это время';

  @override
  String get smartTopMonth => 'Чаще всего за месяц';

  @override
  String get smartRecentlyAdded => 'Недавно добавленные';

  @override
  String get smartNeverPlayed => 'Ни разу не слушали';

  @override
  String get smartLoved => 'Самое любимое';

  @override
  String get smartSkipped => 'Часто пропускаете';

  @override
  String get statsEmpty => 'Статистика появится после первых прослушиваний';

  @override
  String get range7 => '7 дней';

  @override
  String get range30 => '30 дней';

  @override
  String get rangeAll => 'Всё время';

  @override
  String get statListened => 'Слушали';

  @override
  String get statPlays => 'Прослушиваний';

  @override
  String get statStreak => 'Серия дней';

  @override
  String get statSkips => 'Пропусков';

  @override
  String get minutesPerDay => 'Минуты по дням';

  @override
  String get minutesPerDay30 => 'Минуты по дням (30 дней)';

  @override
  String get whenYouListen => 'Когда вы слушаете';

  @override
  String get topTracks => 'Топ треков';

  @override
  String get topArtists => 'Топ исполнителей';

  @override
  String get unitMinutes => 'мин';

  @override
  String durationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String durationHours(int hours) {
    return '$hours ч';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String playsTimes(int count) {
    return '$count ×';
  }

  @override
  String get connectTitle => 'Подключение';

  @override
  String get setupSteps =>
      '1. Создай бота у @BotFather и скопируй токен.\n2. Создай канал или группу и добавь бота админом (публикация, закрепление и удаление сообщений).\n3. Укажи @username чата или его числовой id.';

  @override
  String get botToken => 'Токен бота';

  @override
  String get chatField => 'Чат (@name или -100…)';

  @override
  String get connect => 'Подключить';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get themeTitle => 'Тема';

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get playbackSection => 'Воспроизведение';

  @override
  String get autoplay => 'Автопродолжение';

  @override
  String get autoplaySub =>
      'Когда очередь кончается, добавлять рекомендованные треки';

  @override
  String get prefetch => 'Предзагрузка';

  @override
  String prefetchSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Заранее качать $count следующих трека',
      many: 'Заранее качать $count следующих треков',
      few: 'Заранее качать $count следующих трека',
      one: 'Заранее качать $count следующий трек',
      zero: 'Не качать заранее',
    );
    return '$_temp0';
  }

  @override
  String get cacheSection => 'Кэш';

  @override
  String get cacheLimit => 'Лимит кэша';

  @override
  String cacheUsage(String limit, int used) {
    return '$limit ГБ · занято $used МБ';
  }

  @override
  String get favoritesOffline => 'Избранное всегда офлайн';

  @override
  String get favoritesOfflineSub =>
      'Скачивать и не удалять избранные треки из кэша';

  @override
  String get clearCache => 'Очистить кэш';

  @override
  String get clearCacheSub => 'Офлайн-треки и текущая очередь останутся';

  @override
  String get dataSection => 'Данные';

  @override
  String get resetStats => 'Сбросить статистику';

  @override
  String get resetStatsSub => 'Удалит историю прослушиваний на этом устройстве';

  @override
  String get resetStatsTitle => 'Сбросить статистику?';

  @override
  String get resetStatsBody => 'Рекомендации тоже начнутся с нуля.';

  @override
  String get reset => 'Сбросить';

  @override
  String get disconnect => 'Отключить канал';

  @override
  String get disconnectSub => 'Библиотека в канале останется';

  @override
  String get disconnectTitle => 'Отключить канал?';

  @override
  String get disconnectBody =>
      'Локальный список будет очищен. В канале всё останется.';

  @override
  String get tokenStoredSecurely =>
      'Токен бота хранится в системной связке ключей';

  @override
  String get tokenStoredPlain =>
      'Токен бота хранится в настройках приложения без шифрования (системная связка ключей не найдена)';

  @override
  String get mediaKeysOn => 'Медиаклавиши и системный виджет плеера включены';

  @override
  String get reloadFiles => 'Перечитать файлы';

  @override
  String get moreTooltip => 'Ещё';

  @override
  String get importFile => 'Импорт из файла…';

  @override
  String get pasteClipboard => 'Вставить из буфера обмена';

  @override
  String get copyCurrentTheme => 'Скопировать текущую (JSON)';

  @override
  String get builtInThemes => 'Встроенные';

  @override
  String get myThemes => 'Мои темы';

  @override
  String get noUserThemes =>
      'Пока пусто. Скопируй текущую тему в меню (⋮), поправь значения в файле в папке выше, и приложение обновится само.';

  @override
  String get clipboardEmpty => 'В буфере обмена пусто';

  @override
  String get themeCopied => 'JSON темы скопирован';

  @override
  String get themeRejected => 'Тема не подходит';

  @override
  String get themeFolderHint =>
      'Папка тем. Положи сюда .json и тема появится в списке.';

  @override
  String get copyPath => 'Скопировать путь';

  @override
  String get deleteThemeTitle => 'Удалить тему?';

  @override
  String deleteThemeBody(String name) {
    return 'Файл «$name» будет удалён.';
  }

  @override
  String get statusNoConnection => 'Нет соединения';

  @override
  String statusUploading(int n, int total, String name) {
    return 'Загрузка $n/$total: $name';
  }

  @override
  String get statusSyncing => 'Синхронизация…';

  @override
  String get errorNotAdmin => 'Бот должен быть администратором канала';

  @override
  String get errorFileUnavailable => 'Файл недоступен';

  @override
  String get errorFileTooBig => 'Файл больше 20 МБ, Bot API не отдаст его';

  @override
  String errorDownloadFailed(int code) {
    return 'Скачивание не удалось ($code)';
  }

  @override
  String get defaultPlaylistName => 'Плейлист';
}
