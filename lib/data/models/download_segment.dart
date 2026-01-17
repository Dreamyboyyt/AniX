import 'package:isar_community/isar.dart';

part 'download_segment.g.dart';

@collection
class DownloadSegment {
  Id id = Isar.autoIncrement;

  @Index()
  late String taskId;

  @Index(composite: [CompositeIndex('taskId')])
  late int segmentIndex;

  late String segmentUrl;
  late String localPath;

  double? duration;
  int? fileSize;
  int downloadedBytes = 0;

  @enumerated
  SegmentStatus status = SegmentStatus.pending;

  String? errorMessage;
  int retryCount = 0;

  DownloadSegment();

  factory DownloadSegment.create({
    required String taskId,
    required int segmentIndex,
    required String segmentUrl,
    required String localPath,
    double? duration,
  }) {
    return DownloadSegment()
      ..taskId = taskId
      ..segmentIndex = segmentIndex
      ..segmentUrl = segmentUrl
      ..localPath = localPath
      ..duration = duration;
  }

  bool get isComplete => status == SegmentStatus.completed;

  bool get canRetry => status == SegmentStatus.failed && retryCount < 3;
}

enum SegmentStatus {
  pending,
  downloading,
  completed,
  failed,
}
