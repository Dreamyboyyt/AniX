import 'package:isar_community/isar.dart';

part 'episode.g.dart';

@collection
class Episode {
  Id id = Isar.autoIncrement;

  @Index()
  late String animeId;

  @Index(unique: true, composite: [CompositeIndex('animeId')])
  late int episodeNumber;

  late String title;
  String? thumbnail;
  String? sourceUrl;

  int? duration;

  int watchedPosition = 0;
  bool isWatched = false;
  DateTime? watchedAt;

  @enumerated
  DownloadStatus downloadStatus = DownloadStatus.none;
  
  String? downloadPath;

  Episode();

  factory Episode.create({
    required String animeId,
    required int episodeNumber,
    required String title,
    String? thumbnail,
    String? sourceUrl,
    int? duration,
  }) {
    return Episode()
      ..animeId = animeId
      ..episodeNumber = episodeNumber
      ..title = title
      ..thumbnail = thumbnail
      ..sourceUrl = sourceUrl
      ..duration = duration;
  }

  double get watchProgress {
    if (duration == null || duration == 0) return 0.0;
    return (watchedPosition / duration!).clamp(0.0, 1.0);
  }

  bool get isPartiallyWatched {
    final progress = watchProgress;
    return progress > 0.05 && progress < 0.90;
  }

  void markAsWatched() {
    isWatched = true;
    watchedAt = DateTime.now();
    if (duration != null) {
      watchedPosition = duration!;
    }
  }
}

enum DownloadStatus {
  none,
  queued,
  downloading,
  paused,
  completed,
  failed,
}
