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

/// Extract rate limit fields from GitHub API response headers.
({int? limit, int? remaining, DateTime? reset}) _extractRateLimit(
  Headers headers,
) {
  final limit = int.tryParse(headers.value('x-ratelimit-limit') ?? '');
  final remaining = int.tryParse(headers.value('x-ratelimit-remaining') ?? '');
  final resetEpoch = int.tryParse(headers.value('x-ratelimit-reset') ?? '');
  final reset = resetEpoch != null
      ? DateTime.fromMillisecondsSinceEpoch(resetEpoch * 1000)
      : null;
  return (limit: limit, remaining: remaining, reset: reset);
}

/// Build a [NetworkError] from an HTTP response, including rate limit info.
NetworkError _networkErrorFromResponse(Response response) {
  final statusCode = response.statusCode;
  String? detail;
  String? docUrl;
  final data = response.data;
  if (data is Map) {
    detail = data['message'] as String?;
    docUrl = data['documentation_url'] as String?;
  }
  final rl = _extractRateLimit(response.headers);
  return NetworkError(
    'HTTP ${statusCode ?? '?'}',
    detail: detail,
    documentationUrl: docUrl,
    rateLimitLimit: rl.limit,
    rateLimitRemaining: rl.remaining,
    rateLimitReset: rl.reset,
  );
}

/// Execute a network request and convert exceptions to [NetworkError].
///
/// [onResponse] is called with the raw [Response] before parsing, useful for
/// extracting headers (e.g. ETag).
Future<T> _executeRequest<T>(
  Future<Response> Function() request, {
  required T Function(dynamic) parser,
  void Function(Response)? onResponse,
}) async {
  try {
    final response = await request();
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      // Allow onResponse to handle non-error statuses like 304.
      if (onResponse != null &&
          (statusCode == 304 || statusCode == 301 || statusCode == 302)) {
        onResponse(response);
        return parser(response.data);
      }
      throw _networkErrorFromResponse(response);
    }
    onResponse?.call(response);
    return parser(response.data);
  } on UpdateError {
    rethrow;
  } on DioException catch (e) {
    throw _networkErrorFromDio(e);
  } catch (e) {
    throw NetworkError('Unexpected error: $e');
  }
}

/// Extract as much useful context as possible from a [DioException].
NetworkError _networkErrorFromDio(DioException e) {
  // If there's an HTTP response, reuse the shared response parser.
  if (e.response != null) return _networkErrorFromResponse(e.response!);

  // No response — classify by DioExceptionType.
  final msg = switch (e.type) {
    DioExceptionType.connectionTimeout => 'Connection timed out',
    DioExceptionType.sendTimeout => 'Send timed out',
    DioExceptionType.receiveTimeout => 'Receive timed out',
    DioExceptionType.connectionError => 'Connection error',
    _ => 'Network error: ${e.message}',
  };
  return NetworkError(msg);
}

// ---------------------------------------------------------------------------
// GitHub Release Checking
// ---------------------------------------------------------------------------

// Cached ETag and response for conditional requests (avoids rate-limit hits).
String? _cachedETag;
GitHubReleaseResponse? _cachedRelease;

/// Fetch the latest GitHub release and return a [ReleaseInfo] when a newer
/// version is available. Returns `null` when up to date.
///
/// [releaseUrl] is the GitHub Releases API endpoint, e.g.
/// `https://api.github.com/repos/vidlg/webfly/releases/latest`.
///
/// [currentVersion] should include the `v` prefix (e.g. `'v0.8.1'`).
/// [networkConfig] allows customizing network request parameters.
///
/// Uses HTTP conditional requests (`If-None-Match` / ETag) so that repeated
/// checks that return 304 Not Modified do NOT count against GitHub's rate
/// limit (60 req/h unauthenticated).
///
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
  // Accept 304 as a valid response (not an error).
  dio.options.validateStatus = (status) =>
      (status != null && status >= 200 && status < 300) || status == 304;

  final headers = {
    'Accept': 'application/vnd.github.v3+json',
    ...config.headers,
    'If-None-Match': ?_cachedETag,
  };

  final release = await _executeRequest<GitHubReleaseResponse?>(
    () => dio.getUri(Uri.parse(releaseUrl), options: Options(headers: headers)),
    parser: (data) {
      // 304 – no change since last check; reuse cached response.
      if (data == null || data == '') return null;
      return GitHubReleaseResponse.fromJson(data as Map<String, dynamic>);
    },
    onResponse: (response) {
      if (response.statusCode == 304) {
        _log.fine('304 Not Modified — using cached release');
        return;
      }
      // Cache ETag for next request.
      final etag = response.headers.value('etag');
      if (etag != null) _cachedETag = etag;
    },
  );

  final resolved = release ?? _cachedRelease;
  if (resolved == null) {
    // No cached data and 304 — shouldn't happen, but treat as up-to-date.
    return null;
  }
  if (release != null) _cachedRelease = release;

  return _releaseMetadataToReleaseInfo(resolved, currentVersion, testMode);
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
    final detail = e.response?.statusCode;
    final msg = detail != null
        ? 'Download failed: HTTP $detail'
        : 'Download failed: ${e.type.name}';
    _log.severe(msg);
    onError(DownloadError(msg));
  } catch (e) {
    _log.severe('Download failed: $e');
    onError(DownloadError('$e'));
  }
}

/// Opens the APK file for installation.
Future<void> installApk(String apkPath) async {
  final result = await OpenFilex.open(apkPath);
  if (result.type != ResultType.done) {
    throw InstallError('Failed to open APK: ${result.message}');
  }
}
