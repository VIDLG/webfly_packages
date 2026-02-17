import 'error.dart';

export 'release.dart';

/// Network configuration for HTTP requests.
class NetworkConfig {
  /// Connection timeout duration. Defaults to 10 seconds.
  final Duration connectTimeout;

  /// Receive timeout duration. Defaults to 10 seconds.
  final Duration receiveTimeout;

  /// Request headers to include in all requests.
  final Map<String, String> headers;

  /// Whether to follow redirects. Defaults to true.
  final bool followRedirects;

  /// Maximum number of redirects to follow. Defaults to 5.
  final int maxRedirects;

  const NetworkConfig({
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 10),
    this.headers = const {},
    this.followRedirects = true,
    this.maxRedirects = 5,
  });

  /// Create a copy of this config with some fields replaced.
  NetworkConfig copyWith({
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Map<String, String>? headers,
    bool? followRedirects,
    int? maxRedirects,
  }) {
    return NetworkConfig(
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      headers: headers ?? this.headers,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
    );
  }
}

// ---------------------------------------------------------------------------
// SHA256 Response
// ---------------------------------------------------------------------------

/// SHA256 checksum response.
class Sha256Response {
  final String hash;

  const Sha256Response({required this.hash});

  /// Parse from .sha256 file content.
  factory Sha256Response.fromContent(String content) {
    // .sha256 files typically contain "<hash>  <filename>" or just the hash.
    final hash = content.trim().split(RegExp(r'\s+')).first;
    return Sha256Response(hash: hash);
  }
}

// ---------------------------------------------------------------------------
// Release Info
// ---------------------------------------------------------------------------

/// Information about a GitHub release.
class ReleaseInfo {
  /// Tag name (e.g. 'v0.8.1').
  final String version;

  /// Direct download URL for the APK asset.
  final String downloadUrl;

  /// Optional SHA256 checksum download URL (.sha256 file).
  final String? sha256Url;

  /// Release notes (markdown body from GitHub).
  final String? releaseNotes;

  const ReleaseInfo({
    required this.version,
    required this.downloadUrl,
    this.sha256Url,
    this.releaseNotes,
  });
}

// ---------------------------------------------------------------------------
// Update State Hierarchy (Sealed)
// ---------------------------------------------------------------------------

/// Sealed state hierarchy for the update lifecycle.
sealed class UpdateState {
  const UpdateState();
}

/// No operation in progress.
class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

/// Checking GitHub for a new release.
class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

/// A newer version is available.
class UpdateAvailable extends UpdateState {
  final ReleaseInfo release;
  const UpdateAvailable(this.release);
}

/// Preparing to download (waiting for download manager).
class UpdatePreparing extends UpdateState {
  const UpdatePreparing();
}

/// APK is being downloaded.
class UpdateDownloading extends UpdateState {
  /// Progress value from 0.0 to 1.0.
  final double progress;
  const UpdateDownloading({required this.progress});
}

/// System installer has been triggered.
class UpdateInstalling extends UpdateState {
  const UpdateInstalling();
}

/// Installation was triggered successfully (user sees system UI).
class UpdateReady extends UpdateState {
  final String apkPath;
  const UpdateReady({required this.apkPath});
}

/// The app is already up to date.
class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}

/// An error occurred during the update process.
class UpdateFailed extends UpdateState {
  final UpdateError error;
  const UpdateFailed(this.error);
}

/// Download was cancelled by the user.
class UpdateCancelled extends UpdateState {
  const UpdateCancelled();
}
