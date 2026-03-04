import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webfly_updater/src/signature.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('webfly_updater/signature');

  const fakeSig = 'ab12cd34ef56';
  const fakeSig2 = 'ff00ee11dd22';

  setUp(() {
    // Clear any previous handler.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // ── getInstalledSignature ─────────────────────────────────────────

  group('getInstalledSignature', () {
    test('returns signature from platform', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInstalledSignature') return fakeSig;
        return null;
      });

      expect(await getInstalledSignature(), fakeSig);
    });

    test('returns null on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ERROR', message: 'fail');
      });

      expect(await getInstalledSignature(), isNull);
    });

    test('returns null when no handler (MissingPluginException)', () async {
      // No handler registered → MissingPluginException
      expect(await getInstalledSignature(), isNull);
    });
  });

  // ── getApkSignature ───────────────────────────────────────────────

  group('getApkSignature', () {
    test('passes path argument and returns signature', () async {
      String? receivedPath;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApkSignature') {
          receivedPath = call.arguments['path'] as String?;
          return fakeSig2;
        }
        return null;
      });

      final result = await getApkSignature('/tmp/app.apk');
      expect(result, fakeSig2);
      expect(receivedPath, '/tmp/app.apk');
    });

    test('returns null on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ERROR', message: 'fail');
      });

      expect(await getApkSignature('/tmp/app.apk'), isNull);
    });

    test('returns null when no handler', () async {
      expect(await getApkSignature('/tmp/app.apk'), isNull);
    });
  });

  // ── verifySignature ───────────────────────────────────────────────

  group('verifySignature', () {
    test('returns true when signatures match', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInstalledSignature') return fakeSig;
        if (call.method == 'getApkSignature') return fakeSig;
        return null;
      });

      expect(await verifySignature('/tmp/app.apk'), isTrue);
    });

    test('returns false when signatures differ', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInstalledSignature') return fakeSig;
        if (call.method == 'getApkSignature') return fakeSig2;
        return null;
      });

      expect(await verifySignature('/tmp/app.apk'), isFalse);
    });

    test('returns true when installed signature unavailable', () async {
      // No handler → getInstalledSignature returns null → skip check
      expect(await verifySignature('/tmp/app.apk'), isTrue);
    });

    test('returns true when APK signature unavailable', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInstalledSignature') return fakeSig;
        // getApkSignature → PlatformException → null
        if (call.method == 'getApkSignature') {
          throw PlatformException(code: 'ERROR', message: 'fail');
        }
        return null;
      });

      expect(await verifySignature('/tmp/app.apk'), isTrue);
    });
  });
}
