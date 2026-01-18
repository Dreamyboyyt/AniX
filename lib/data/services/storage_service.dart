import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/extensions.dart';
import '../database/repositories/settings_repository.dart';

/// Service for managing storage and file operations
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  /// Default download path in external storage
  static const String defaultExternalPath = '/storage/emulated/0/AniX';

  String? _downloadBasePath;

  /// Initialize storage service
  Future<void> initialize() async {
    final settings = await SettingsRepository.instance.getSettings();

    // Check if we have storage permission
    final hasPermission = await hasStoragePermission();

    if (hasPermission) {
      // Use custom path if set, otherwise use default
      _downloadBasePath = settings.downloadPath ?? defaultExternalPath;
      
      // Ensure the directory exists
      await _ensureDirectoryExists(_downloadBasePath!);
      
      // Update settings
      settings.downloadPath = _downloadBasePath;
      settings.storagePermissionGranted = true;
      await SettingsRepository.instance.saveSettings(settings);
      
      AppLogger.i('Storage initialized at: $_downloadBasePath');
    } else if (settings.downloadPath != null) {
      _downloadBasePath = settings.downloadPath;
    }
  }

  /// Request storage permission
  Future<bool> requestStoragePermission() async {
    try {
      PermissionStatus status;

      // For Android 11+ (API 30+), we need MANAGE_EXTERNAL_STORAGE
      // For Android 10 and below, we use READ/WRITE_EXTERNAL_STORAGE
      if (await _isAndroid11OrHigher()) {
        status = await Permission.manageExternalStorage.request();
      } else {
        // Request both read and write for older Android versions
        final writeStatus = await Permission.storage.request();
        status = writeStatus;
      }

      if (status.isGranted) {
        _downloadBasePath = defaultExternalPath;
        await _ensureDirectoryExists(_downloadBasePath!);

        await SettingsRepository.instance.setDownloadPath(_downloadBasePath!);

        AppLogger.i('Storage permission granted: $_downloadBasePath');
        return true;
      }

      if (status.isPermanentlyDenied) {
        AppLogger.w('Storage permission permanently denied - opening settings');
        await openAppSettings();
        return false;
      }

      AppLogger.w('Storage permission denied');
      return false;
    } catch (e, stack) {
      AppLogger.e('Failed to request storage permission', e, stack);
      return false;
    }
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    try {
      if (await _isAndroid11OrHigher()) {
        return await Permission.manageExternalStorage.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    } catch (e) {
      AppLogger.e('Failed to check storage permission', e);
      return false;
    }
  }

  /// Check if running on Android 11 or higher
  Future<bool> _isAndroid11OrHigher() async {
    if (!Platform.isAndroid) return false;
    // Android 11 is API level 30
    // We can check this by attempting to use manageExternalStorage
    // which is only available on Android 11+
    try {
      final status = await Permission.manageExternalStorage.status;
      return status != PermissionStatus.restricted;
    } catch (e) {
      return false;
    }
  }

  /// Set custom download path
  Future<bool> setCustomDownloadPath(String path) async {
    try {
      final hasPermission = await hasStoragePermission();
      if (!hasPermission) {
        AppLogger.w('Cannot set custom path - no storage permission');
        return false;
      }

      await _ensureDirectoryExists(path);
      _downloadBasePath = path;
      await SettingsRepository.instance.setDownloadPath(path);
      
      AppLogger.i('Custom download path set: $path');
      return true;
    } catch (e, stack) {
      AppLogger.e('Failed to set custom download path', e, stack);
      return false;
    }
  }

  /// Reset to default download path
  Future<void> resetToDefaultPath() async {
    _downloadBasePath = defaultExternalPath;
    await _ensureDirectoryExists(_downloadBasePath!);
    await SettingsRepository.instance.setDownloadPath(_downloadBasePath!);
    AppLogger.i('Reset to default download path: $_downloadBasePath');
  }

  /// Get download base path
  String? get downloadBasePath => _downloadBasePath;

  /// Get or create anime download folder
  Future<String> getAnimeFolder(String animeTitle) async {
    final sanitizedTitle = animeTitle.sanitizeFileName;
    
    if (_downloadBasePath != null) {
      // Using SAF
      final animePath = p.join(_downloadBasePath!, sanitizedTitle);
      await _ensureDirectoryExists(animePath);
      return animePath;
    }
    
    // Fallback to app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final animePath = p.join(appDir.path, AppConstants.downloadFolderName, sanitizedTitle);
    await _ensureDirectoryExists(animePath);
    return animePath;
  }

  /// Get or create episode download folder
  Future<String> getEpisodeFolder(String animeTitle, int episodeNumber) async {
    final animeFolder = await getAnimeFolder(animeTitle);
    final episodeFolder = p.join(animeFolder, 'Episode_$episodeNumber');
    await _ensureDirectoryExists(episodeFolder);
    return episodeFolder;
  }

  /// Get segments folder for an episode
  Future<String> getSegmentsFolder(String animeTitle, int episodeNumber) async {
    final episodeFolder = await getEpisodeFolder(animeTitle, episodeNumber);
    final segmentsFolder = p.join(episodeFolder, 'segments');
    await _ensureDirectoryExists(segmentsFolder);
    return segmentsFolder;
  }

  /// Get local master.m3u8 path for an episode
  String getLocalMasterPath(String episodeFolder) {
    return p.join(episodeFolder, 'master.m3u8');
  }

  /// Create local master.m3u8 for offline playback
  Future<String> createLocalMaster(String episodeFolder, List<String> segmentFiles) async {
    final masterPath = getLocalMasterPath(episodeFolder);
    
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:3');
    buffer.writeln('#EXT-X-TARGETDURATION:10');
    buffer.writeln('#EXT-X-MEDIA-SEQUENCE:0');

    for (final segmentFile in segmentFiles) {
      buffer.writeln('#EXTINF:10.0,');
      buffer.writeln(segmentFile);
    }

    buffer.writeln('#EXT-X-ENDLIST');

    final file = File(masterPath);
    await file.writeAsString(buffer.toString());
    
    AppLogger.i('Created local master.m3u8 at: $masterPath');
    return masterPath;
  }

  /// Get segment file path
  String getSegmentPath(String segmentsFolder, int index) {
    return p.join(segmentsFolder, 'segment_$index.ts');
  }

  /// Check if episode is fully downloaded
  Future<bool> isEpisodeDownloaded(String episodeFolder) async {
    final masterPath = getLocalMasterPath(episodeFolder);
    return File(masterPath).exists();
  }

  /// Get downloaded episode size
  Future<int> getEpisodeSize(String episodeFolder) async {
    final dir = Directory(episodeFolder);
    if (!await dir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Delete episode download
  Future<void> deleteEpisodeDownload(String episodeFolder) async {
    final dir = Directory(episodeFolder);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      AppLogger.i('Deleted episode folder: $episodeFolder');
    }
  }

  /// Delete anime download folder
  Future<void> deleteAnimeDownloads(String animeTitle) async {
    final sanitizedTitle = animeTitle.sanitizeFileName;
    
    String animePath;
    if (_downloadBasePath != null) {
      animePath = p.join(_downloadBasePath!, sanitizedTitle);
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      animePath = p.join(appDir.path, AppConstants.downloadFolderName, sanitizedTitle);
    }

    final dir = Directory(animePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      AppLogger.i('Deleted anime folder: $animePath');
    }
  }

  /// Get total downloaded size
  Future<int> getTotalDownloadedSize() async {
    String basePath;
    if (_downloadBasePath != null) {
      basePath = _downloadBasePath!;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      basePath = p.join(appDir.path, AppConstants.downloadFolderName);
    }

    final dir = Directory(basePath);
    if (!await dir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Get app cache directory
  Future<String> getCacheDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final anixCacheDir = p.join(cacheDir.path, 'anix_cache');
    await _ensureDirectoryExists(anixCacheDir);
    return anixCacheDir;
  }

  /// Clear app cache
  Future<void> clearCache() async {
    final cacheDir = await getCacheDirectory();
    final dir = Directory(cacheDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      AppLogger.i('Cache cleared');
    }
  }

  /// Ensure directory exists
  Future<void> _ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}
