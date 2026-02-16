import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:ota_update/ota_update.dart';
import 'package:pub_semver/pub_semver.dart';

import 'error.dart';
import 'models.dart';

final _log = Logger();

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
    _log.d('Release $version has no APK asset');
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
// Download & Install via ota_update
// ---------------------------------------------------------------------------

Stream<UpdateState> downloadAndInstall(
  ReleaseInfo release, {
  NetworkConfig? networkConfig,
}) async* {
  yield const UpdateDownloading(progress: 0);

  // 1. Fetch SHA-256 checksum if available.
  String? sha256;
  if (release.sha256Url != null) {
    try {
      sha256 = await _fetchSha256(
        release.sha256Url!,
        networkConfig: networkConfig,
      );
      _log.d('SHA256 checksum: $sha256');
    } catch (e) {
      _log.d('Failed to fetch SHA256: $e');
    }
  }

  // 2. Use ota_update to download + verify + install.
  try {
    yield* _executeOta(release.downloadUrl, sha256: sha256);
  } catch (e) {
    yield UpdateFailed(DownloadError(e.toString()));
  }
}

/// Fetch the SHA-256 hash string from a `.sha256` file URL.
Future<String> _fetchSha256(String url, {NetworkConfig? networkConfig}) async {
  final config = networkConfig ?? const NetworkConfig();
  final dio = Dio();
  dio.options.connectTimeout = config.connectTimeout;
  dio.options.receiveTimeout = config.receiveTimeout;
  dio.options.followRedirects = config.followRedirects;
  dio.options.maxRedirects = config.maxRedirects;

  final sha256 = await _executeRequest<Sha256Response>(
    () => dio.getUri(Uri.parse(url), options: Options(headers: config.headers)),
    parser: (data) => Sha256Response.fromContent(data as String),
  );

  return sha256.hash;
}

/// Map `ota_update` events to [UpdateState].
Stream<UpdateState> _executeOta(String url, {String? sha256}) async* {
  try {
    await for (final event in OtaUpdate().execute(
      url,
      sha256checksum: sha256,
    )) {
      switch (event.status) {
        case OtaStatus.DOWNLOADING:
          final progress = double.tryParse(event.value ?? '0') ?? 0;
          yield UpdateDownloading(progress: progress / 100);
        case OtaStatus.INSTALLING:
          yield const UpdateInstalling();
        case OtaStatus.INSTALLATION_DONE:
          yield const UpdateReady();
        case OtaStatus.INSTALLATION_ERROR:
          yield UpdateFailed(
            InstallError(event.value ?? 'Installation failed'),
          );
        case OtaStatus.ALREADY_RUNNING_ERROR:
          yield const UpdateFailed(
            DownloadError('Another update is already in progress'),
          );
        case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          yield const UpdateFailed(
            InstallError('Install permission not granted'),
          );
        case OtaStatus.INTERNAL_ERROR:
          yield UpdateFailed(DownloadError(event.value ?? 'Internal error'));
        case OtaStatus.DOWNLOAD_ERROR:
          yield UpdateFailed(DownloadError(event.value ?? 'Download failed'));
        case OtaStatus.CHECKSUM_ERROR:
          yield UpdateFailed(
            HashVerificationError(
              expected: sha256 ?? 'unknown',
              actual: event.value ?? 'unknown',
            ),
          );
        case OtaStatus.CANCELED:
          yield const UpdateFailed(DownloadError('Download canceled'));
      }
    }

    yield const UpdateReady();
  } catch (e) {
    yield UpdateFailed(DownloadError(e.toString()));
  }
}
