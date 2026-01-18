import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../data/models/anime.dart';
import '../../data/models/anime_detail.dart';
import '../../data/models/episode.dart';
import '../../providers/app_providers.dart';

class AnimeDetailsScreen extends ConsumerStatefulWidget {
  final Anime anime;

  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  ConsumerState<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends ConsumerState<AnimeDetailsScreen> {
  bool _isDescriptionExpanded = false;
  String? _selectedSeason;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(animeDetailProvider(widget.anime));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.anime.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: detail.when(
        data: (animeDetail) => _buildContent(context, animeDetail),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnimeDetail detail) {
    final anime = detail.anime;
    final seasons = detail.episodesBySeason;
    final seasonKeys = seasons.keys.toList();
    final hasSeasons = seasonKeys.isNotEmpty;
    final selectedSeason = hasSeasons
        ? seasonKeys.firstWhere(
            (season) => season == _selectedSeason,
            orElse: () => seasonKeys.first,
          )
        : null;
    final episodes = hasSeasons ? seasons[selectedSeason]! : const <Episode>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(anime),
        const SizedBox(height: 16),
        Text('Anime Name', style: Theme.of(context).textTheme.labelLarge),
        Text(anime.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _buildDescription(context, anime.description),
        const SizedBox(height: 16),
        if (hasSeasons) ...[
          Text('Season', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _SeasonToggle(
            seasons: seasonKeys,
            selected: selectedSeason!,
            onSelected: (season) {
              setState(() {
                _selectedSeason = season;
              });
            },
          ),
          const SizedBox(height: 16),
        ],
        Text('Episodes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (episodes.isEmpty)
          Text('No episodes found', style: Theme.of(context).textTheme.bodyMedium)
        else
          ...episodes.map((episode) => _EpisodeTile(episode: episode)),
      ],
    );
  }

  Widget _buildHeader(Anime anime) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 120,
            height: 180,
            child: anime.coverUrl != null
                ? Image.network(anime.coverUrl!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.draculaCurrentLine,
                    child: const Icon(Icons.movie_outlined, size: 48, color: AppColors.draculaComment),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(anime.title, style: Theme.of(context).textTheme.titleLarge),
              if (anime.releaseYear != null) ...[
                const SizedBox(height: 8),
                Text('Year: ${anime.releaseYear}', style: Theme.of(context).textTheme.bodySmall),
              ],
              if (anime.status != null) ...[
                const SizedBox(height: 4),
                Text('Status: ${anime.status}', style: Theme.of(context).textTheme.bodySmall),
              ],
              if (anime.type != null) ...[
                const SizedBox(height: 4),
                Text('Type: ${anime.type}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context, String? description) {
    if (description == null || description.trim().isEmpty) {
      return Text('Description', style: Theme.of(context).textTheme.labelLarge);
    }

    final textTheme = Theme.of(context).textTheme;
    final maxLines = _isDescriptionExpanded ? null : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(description, style: textTheme.bodyMedium, maxLines: maxLines, overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            setState(() {
              _isDescriptionExpanded = !_isDescriptionExpanded;
            });
          },
          child: Text(_isDescriptionExpanded ? 'View Less' : 'View More'),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.draculaOrange),
            const SizedBox(height: 12),
            Text('Failed to load anime details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(animeDetailProvider(widget.anime)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonToggle extends StatelessWidget {
  final List<String> seasons;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SeasonToggle({
    required this.seasons,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: seasons.map((season) {
        final isSelected = season == selected;
        return ChoiceChip(
          label: Text(season),
          selected: isSelected,
          onSelected: (_) => onSelected(season),
        );
      }).toList(),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Episode episode;

  const _EpisodeTile({required this.episode});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('Episode ${episode.episodeNumber}: ${episode.title}'),
      subtitle: episode.duration != null
          ? Text('Duration: ${episode.duration!.formatDuration}')
          : null,
      trailing: const Icon(Icons.play_circle_outline),
      onTap: () {
        context.showSnackBar('Play ${episode.title}');
      },
    );
  }
}
