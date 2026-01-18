import 'package:isar_community/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  @enumerated
  AppThemeMode themeMode = AppThemeMode.system;

  String? defaultQuality;
  String? defaultLanguage;
  bool saveQualityPreference = false;
  bool saveLanguagePreference = false;

  int parallelDownloads = 2;
  int parallelSegments = 4;
  bool downloadOnWifiOnly = false;
  bool autoResumeDownloads = true;

  String? downloadPath;

  bool notificationPermissionGranted = false;
  bool storagePermissionGranted = false;
  bool permissionsSkipped = false;

  bool isFirstLaunch = true;
  DateTime? lastOpenedAt;

  bool autoPlayNext = true;
  double playbackSpeed = 1.0;
  bool rememberPlaybackPosition = true;

  AppSettings();

  factory AppSettings.defaults() {
    return AppSettings()
      ..themeMode = AppThemeMode.system
      ..parallelDownloads = 2
      ..parallelSegments = 4
      ..downloadOnWifiOnly = false
      ..autoResumeDownloads = true
      ..isFirstLaunch = true
      ..autoPlayNext = true
      ..playbackSpeed = 1.0
      ..rememberPlaybackPosition = true;
  }

  bool get canDownload => 
      (storagePermissionGranted && downloadPath != null) || 
      !permissionsSkipped;

  bool get hasAllPermissions => 
      notificationPermissionGranted && 
      storagePermissionGranted && 
      downloadPath != null;
}

enum AppThemeMode {
  system,
  light,
  dark,
}
