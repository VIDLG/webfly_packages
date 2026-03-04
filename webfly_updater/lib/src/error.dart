// ---------------------------------------------------------------------------
// Error Hierarchy (Sealed)
// ---------------------------------------------------------------------------

/// Sealed error hierarchy for update failures.
sealed class UpdateError {
  const UpdateError();
}

/// Network-level failure (DNS, timeout, HTTP error, etc.).
class NetworkError extends UpdateError {
  final String message;

  /// Optional human-readable detail from the server response (e.g. GitHub API
  /// error body `{"message": "API rate limit exceeded"}`).
  final String? detail;

  /// Optional URL to documentation for this error (e.g. GitHub's
  /// `documentation_url` field).
  final String? documentationUrl;

  /// Rate limit ceiling for the resource (from `X-RateLimit-Limit` header).
  final int? rateLimitLimit;

  /// Remaining requests in the current window (from `X-RateLimit-Remaining`).
  final int? rateLimitRemaining;

  /// When the current rate limit window resets (from `X-RateLimit-Reset`).
  final DateTime? rateLimitReset;

  const NetworkError(
    this.message, {
    this.detail,
    this.documentationUrl,
    this.rateLimitLimit,
    this.rateLimitRemaining,
    this.rateLimitReset,
  });

  @override
  String toString() => 'NetworkError: $message'
      '${detail != null ? ' ($detail)' : ''}';
}

/// SHA256 hash of the downloaded APK does not match the expected value.
class HashVerificationError extends UpdateError {
  final String expected;
  final String actual;
  const HashVerificationError({required this.expected, required this.actual});

  @override
  String toString() =>
      'HashVerificationError: expected=$expected, actual=$actual';
}

/// The downloaded APK is signed with a different certificate than the
/// currently installed app.
class SignatureMismatchError extends UpdateError {
  final String installedSignature;
  final String downloadSignature;
  const SignatureMismatchError({
    required this.installedSignature,
    required this.downloadSignature,
  });

  @override
  String toString() =>
      'SignatureMismatchError: installed=$installedSignature, '
      'download=$downloadSignature';
}

/// Download failed (ota_update reported an error).
class DownloadError extends UpdateError {
  final String message;
  const DownloadError(this.message);

  @override
  String toString() => 'DownloadError: $message';
}

/// Installation failed.
class InstallError extends UpdateError {
  final String message;
  const InstallError(this.message);

  @override
  String toString() => 'InstallError: $message';
}
