import 'anime.dart';
import 'episode.dart';

class AnimeDetail {
  final Anime anime;
  final Map<String, List<Episode>> episodesBySeason;

  AnimeDetail({
    required this.anime,
    required this.episodesBySeason,
  });
}
