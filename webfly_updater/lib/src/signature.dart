import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _log = Logger('webfly_updater');

// ---------------------------------------------------------------------------
// APK Signature Verification
// ---------------------------------------------------------------------------

const _signatureChannel = MethodChannel('org.vidlg.webfly/signature');

/// Returns the SHA-256 fingerprint of the signing certificate for the
/// currently installed app, or `null` if unavailable.
Future<String?> getInstalledSignature() async {
  try {
    return await _signatureChannel.invokeMethod<String>(
      'getInstalledSignature',
    );
  } on PlatformException catch (e) {
    _log.fine('Failed to get installed signature: $e');
    return null;
  } on MissingPluginException {
    _log.fine('Signature channel not available (non-Android platform?)');
    return null;
  }
}

/// Returns the SHA-256 fingerprint of the signing certificate embedded in
/// the APK at [apkPath], or `null` if unavailable.
Future<String?> getApkSignature(String apkPath) async {
  try {
    return await _signatureChannel.invokeMethod<String>('getApkSignature', {
      'path': apkPath,
    });
  } on PlatformException catch (e) {
    _log.fine('Failed to get APK signature: $e');
    return null;
  } on MissingPluginException {
    _log.fine('Signature channel not available');
    return null;
  }
}

/// Compare the installed app signature with the given APK.
///
/// Returns `true` when signatures match or when verification is unavailable.
/// Returns `false` only on a confirmed mismatch.
Future<bool> verifySignature(String apkPath) async {
  final installed = await getInstalledSignature();
  if (installed == null) return true;

  final downloaded = await getApkSignature(apkPath);
  if (downloaded == null) return true;

  return installed == downloaded;
}
