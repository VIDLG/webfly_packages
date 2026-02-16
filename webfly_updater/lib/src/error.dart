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
  const NetworkError(this.message);

  @override
  String toString() => 'NetworkError: $message';
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
