import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/anime.dart';

class AnimeDetailsScreen extends StatelessWidget {
  final Anime anime;

  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(anime.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: anime.coverUrl != null
                  ? Image.network(anime.coverUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.draculaCurrentLine,
                      child: const Icon(Icons.movie_outlined, size: 64, color: AppColors.draculaComment),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(anime.title, style: Theme.of(context).textTheme.headlineSmall),
          if (anime.description != null) ...[
            const SizedBox(height: 12),
            Text(anime.description!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Open series: ${anime.sourceUrl ?? anime.animeId}')),
              );
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open Series'),
          ),
        ],
      ),
    );
  }
}
