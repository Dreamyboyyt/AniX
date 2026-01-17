import 'package:isar_community/isar.dart';

part 'download_task.g.dart';

@collection
class DownloadTask {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String taskId;

  @Index()
  late String animeId;
  
  late String animeTitle;
  late int episodeNumber;
  late String episodeTitle;

  late String masterM3u8Url;
  String? selectedQuality;
  String? selectedLanguage;
  String? audioGroupId;

  late String downloadFolder;
  String? segmentListPath;

  int totalSegments = 0;
  int downloadedSegments = 0;
  int totalBytes = 0;
  int downloadedBytes = 0;

  @enumerated
  TaskStatus status = TaskStatus.queued;
  
  String? errorMessage;
  int retryCount = 0;

  late DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;
  DateTime? pausedAt;

  String? cookies;
  String? referer;

  DownloadTask();

  factory DownloadTask.create({
    required String taskId,
    required String animeId,
    required String animeTitle,
    required int episodeNumber,
    required String episodeTitle,
    required String masterM3u8Url,
    required String downloadFolder,
    String? selectedQuality,
    String? selectedLanguage,
    String? audioGroupId,
    String? cookies,
    String? referer,
  }) {
    return DownloadTask()
      ..taskId = taskId
      ..animeId = animeId
      ..animeTitle = animeTitle
      ..episodeNumber = episodeNumber
      ..episodeTitle = episodeTitle
      ..masterM3u8Url = masterM3u8Url
      ..downloadFolder = downloadFolder
      ..selectedQuality = selectedQuality
      ..selectedLanguage = selectedLanguage
      ..audioGroupId = audioGroupId
      ..cookies = cookies
      ..referer = referer
      ..createdAt = DateTime.now();
  }

  double get progress {
    if (totalSegments == 0) return 0.0;
    return (downloadedSegments / totalSegments).clamp(0.0, 1.0);
  }

  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  String get downloadedSizeFormatted => _formatBytes(downloadedBytes);

  String get totalSizeFormatted => _formatBytes(totalBytes);

  bool get isActive => status == TaskStatus.queued || status == TaskStatus.downloading;

  bool get canResume => status == TaskStatus.paused || status == TaskStatus.failed;

  bool get canPause => status == TaskStatus.downloading;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }
}

enum TaskStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}
