import 'package:isar_community/isar.dart';

part 'anime.g.dart';

@collection
class Anime {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String animeId;

  late String title;
  String? titleHindi;
  String? coverUrl;
  String? bannerUrl;
  String? description;
  String? sourceUrl;
  String? releaseYear;
  String? status;
  String? type;
  
  List<String> genres = [];
  
  int? totalEpisodes;
  int? rating;

  @Index()
  late DateTime addedAt;
  
  DateTime? lastWatchedAt;
  
  @Index()
  bool isBookmarked = false;

  DateTime? cachedAt;
  
  int lastWatchedEpisode = 0;
  int lastWatchedPosition = 0;

  Anime();

  factory Anime.create({
    required String animeId,
    required String title,
    String? titleHindi,
    String? coverUrl,
    String? bannerUrl,
    String? description,
    String? releaseYear,
    String? status,
    String? type,
    List<String>? genres,
    int? totalEpisodes,
    int? rating,
  }) {
    return Anime()
      ..animeId = animeId
      ..title = title
      ..titleHindi = titleHindi
      ..coverUrl = coverUrl
      ..bannerUrl = bannerUrl
      ..description = description
      ..releaseYear = releaseYear
      ..status = status
      ..type = type
      ..genres = genres ?? []
      ..totalEpisodes = totalEpisodes
      ..rating = rating
      ..addedAt = DateTime.now()
      ..cachedAt = DateTime.now();
  }

  bool get isCacheExpired {
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt!).inDays > 7;
  }

  void refreshCache() {
    cachedAt = DateTime.now();
  }
}
