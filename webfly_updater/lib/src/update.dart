import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

import 'error.dart';
import 'models.dart';
import 'signature.dart';

final _log = Logger('webfly_updater');

// ---------------------------------------------------------------------------
// Network Error Handling
// ---------------------------------------------------------------------------

/// Execute a network request and convert exceptions to [NetworkError].
Future<T> _executeRequest<T>(
  Future<Response> Function() request, {
  required T Function(dynamic) parser,
}) async {
  try {
    final response = await request();
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw NetworkError('HTTP $statusCode');
    }
    return parser(response.data);
  } on UpdateError {
    rethrow;
  } on DioException catch (e) {
    throw NetworkError('Network error: ${e.message}');
  } catch (e) {
    throw NetworkError('Unexpected error: $e');
  }
}

// ---------------------------------------------------------------------------
// GitHub Release Checking
// ---------------------------------------------------------------------------

/// Fetch the latest GitHub release and return a [ReleaseInfo] when a newer
/// version is available. Returns `null` when up to date.
///
/// [releaseUrl] is the GitHub Releases API endpoint, e.g.
/// `https://api.github.com/repos/vidlg/webfly/releases/latest`.
///
/// [currentVersion] should include the `v` prefix (e.g. `'v0.8.1'`).
/// [networkConfig] allows customizing network request parameters.
/// Throws [UpdateError] on network / parse errors.
Future<ReleaseInfo?> checkForUpdates({
  required String releaseUrl,
  required String currentVersion,
  bool testMode = false,
  NetworkConfig? networkConfig,
}) async {
  final config = networkConfig ?? const NetworkConfig();
  final dio = Dio();
  dio.options.connectTimeout = config.connectTimeout;
  dio.options.receiveTimeout = config.receiveTimeout;
  dio.options.followRedirects = config.followRedirects;
  dio.options.maxRedirects = config.maxRedirects;

  final headers = {
    'Accept': 'application/vnd.github.v3+json',
    ...config.headers,
  };

  final release = await _executeRequest<GitHubReleaseResponse>(
    () => dio.getUri(Uri.parse(releaseUrl), options: Options(headers: headers)),
    parser: (data) =>
        GitHubReleaseResponse.fromJson(data as Map<String, dynamic>),
  );

  return _releaseMetadataToReleaseInfo(release, currentVersion, testMode);
}

/// Strip the optional `v` prefix and any build metadata (`+N`) so the string
/// can be parsed by [Version.parse].
Version _parseVersion(String v) {
  var stripped = v.startsWith('v') ? v.substring(1) : v;
  stripped = stripped.split('+').first;
  return Version.parse(stripped);
}

/// Return `true` when [remote] is strictly newer than [local].
bool _isNewer(String remote, String local) =>
    _parseVersion(remote) > _parseVersion(local);

/// Convert generic [ReleaseMetadata] to [ReleaseInfo].
ReleaseInfo? _releaseMetadataToReleaseInfo(
  ReleaseMetadata release,
  String currentVersion,
  bool testMode,
) {
  final version = release.version;
  if (version.isEmpty) return null;
  if (!testMode && !_isNewer(version, currentVersion)) return null;

  // Find APK and optional .sha256 assets.
  final apkAsset = release.findAssetByExt('.apk');
  final sha256Asset = release.findAssetByExt('.sha256');

  if (apkAsset == null || apkAsset.downloadUrl.isEmpty) {
    _log.fine('Release $version has no APK asset');
    return null;
  }

  return ReleaseInfo(
    version: version,
    downloadUrl: apkAsset.downloadUrl,
    sha256Url: sha256Asset?.downloadUrl,
    releaseNotes: release.releaseNotes,
  );
}

// ---------------------------------------------------------------------------
// Download & Install
// ---------------------------------------------------------------------------

/// Download the APK from [downloadUrl] and trigger system install.
///
/// Yields [UpdateState]s: [UpdateDownloading] with progress, [UpdateInstalling]
/// when the system installer is triggered, [UpdateReady] on success, or
/// [UpdateFailed] on error.
///
/// [networkConfig] allows customizing network request parameters.
Stream<UpdateState> downloadAndInstall(
  String downloadUrl, {
  NetworkConfig? networkConfig,
}) {
  final controller = StreamController<UpdateState>();

  _downloadAndInstallInternal(
    downloadUrl,
    networkConfig: networkConfig,
    onProgress: (progress) {
      controller.add(UpdateDownloading(progress: progress));
    },
    onComplete: (apkPath) {
      controller.add(UpdateReady(apkPath: apkPath));
      controller.close();
    },
    onError: (error) {
      controller.add(UpdateFailed(error));
      controller.close();
    },
    onInstalling: () {
      controller.add(const UpdateInstalling());
    },
  );

  return controller.stream;
}

Future<void> _downloadAndInstallInternal(
  String downloadUrl, {
  NetworkConfig? networkConfig,
  required void Function(double progress) onProgress,
  required void Function(String apkPath) onComplete,
  required void Function(UpdateError error) onError,
  required void Function() onInstalling,
}) async {
  final config = networkConfig ?? const NetworkConfig();
  final dio = Dio();
  dio.options.connectTimeout = config.connectTimeout;
  dio.options.receiveTimeout = config.receiveTimeout;
  dio.options.followRedirects = config.followRedirects;
  dio.options.maxRedirects = config.maxRedirects;
  dio.options.headers.addAll(config.headers);

  onProgress(0);

  Directory? tempDir;
  String? apkPath;

  try {
    tempDir = await getTemporaryDirectory();
    final fileName = downloadUrl.split('/').last.split('?').first;
    apkPath = '${tempDir.path}/$fileName';

    _log.info('Downloading APK to: $apkPath');

    int lastLoggedPercent = 0;
    await dio.download(
      downloadUrl,
      apkPath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = received / total;
          onProgress(progress);
          final percent = (progress * 100).floor();
          if (percent >= lastLoggedPercent + 10) {
            lastLoggedPercent = (percent ~/ 10) * 10;
            _log.info('Download progress: $lastLoggedPercent%');
          }
        }
      },
    );

    _log.info('Download complete: $apkPath');

    final apkSignature = await getApkSignature(apkPath);
    _log.info('Downloaded APK signature: $apkSignature');

    final installedSignature = await getInstalledSignature();
    _log.info('Installed app signature: $installedSignature');

    if (apkSignature != null && installedSignature != null) {
      if (apkSignature != installedSignature) {
        _log.warning('SIGNATURE MISMATCH! APK may not install due to different signing key.');
      } else {
        _log.info('Signatures match - installation should succeed.');
      }
    }

    onInstalling();

    final result = await OpenFilex.open(apkPath);
    if (result.type != ResultType.done) {
      _log.severe('Failed to open APK: ${result.message}');
      onError(InstallError('Failed to open APK: ${result.message}'));
      return;
    }

    _log.info('Install dialog triggered');
    onComplete(apkPath);
  } on DioException catch (e) {
    _log.severe('Download error: ${e.message}');
    onError(DownloadError('Download failed: ${e.message}'));
  } catch (e) {
    _log.severe('Unexpected error: $e');
    onError(DownloadError('Unexpected error: $e'));
  }
}

/// Opens the APK file for installation.
Future<void> installApk(String apkPath) async {
  final result = await OpenFilex.open(apkPath);
  if (result.type != ResultType.done) {
    throw InstallError('Failed to open APK: ${result.message}');
  }
}
