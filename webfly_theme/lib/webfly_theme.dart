// Theme WebF module: get/set theme, persist, and stream theme changes.
// No signals_flutter: callers use useStreamSignal(themeStream, initialValue: getTheme())
// in the widgets that need theme reactivity.
//
// In app: import 'package:webfly_theme/webfly_theme.dart' show ThemeWebfModule, themeStream, getTheme, initializeTheme, setTheme;
//         WebF.defineModule((context) => ThemeWebfModule(context));

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webf/webf.dart';
import 'package:webfly_bridge/webfly_bridge.dart';

final _log = webflyLogger('webfly_theme');

// ---------------------------------------------------------------------------
// Theme store: current value + persistence + broadcast stream (no Signal)
// ---------------------------------------------------------------------------

const String _themeModeKey = 'webfly_theme_mode';

class _ThemeStore {
  _ThemeStore._();

  static _ThemeStore? _instance;
  static _ThemeStore get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('Theme store not initialized. Call initializeTheme() first.');
    }
    return i;
  }

  late final SharedPreferences _prefs;
  ThemeMode _current = ThemeMode.system;
  final _themeChangeController = StreamController<ThemeMode>.broadcast();

  Stream<ThemeMode> get themeStream => _themeChangeController.stream;

  static Future<void> create() async {
    if (_instance != null) return;
    final store = _ThemeStore._();
    store._prefs = await SharedPreferences.getInstance();
    final saved = store._prefs.getString(_themeModeKey);
    if (saved == null) {
      store._current = ThemeMode.system;
    } else {
      // Backwards compatible with earlier case-insensitive handling of
      // 'light' / 'dark' / 'system'.
      store._current = enumFromString<ThemeMode>(
        ThemeMode.values,
        saved,
      );
    }
    _instance = store;
  }

  ThemeMode get current => _current;

  Future<void> setTheme(ThemeMode mode) async {
    if (_current == mode) return;
    _current = mode;
    // Persist selection; let errors surface to the caller.
    await _prefs.setString(_themeModeKey, mode.name);
    _themeChangeController.add(mode);
  }

  void dispose() {
    _themeChangeController.close();
    _instance = null;
  }
}

/// Initialize theme store (load from disk). Call once at app startup.
Future<void> initializeTheme() async {
  await _ThemeStore.create();
}

/// Current theme mode (sync). Use as initialValue for useStreamSignal or after initializeTheme().
ThemeMode getTheme() => _ThemeStore.instance.current;

/// Stream of theme changes (ThemeMode). Emits when theme is set from JS or Flutter.
/// Caller: useStreamSignal(() => themeStream, initialValue: getTheme()) for a reactive signal.
Stream<ThemeMode> get themeStream => _ThemeStore.instance.themeStream;

/// Set theme from Flutter (e.g. settings dialog). Updates store and emits on [themeStream].
Future<void> setTheme(ThemeMode mode) {
  return _ThemeStore.instance.setTheme(mode);
}

// ---------------------------------------------------------------------------
// WebF native module
// ---------------------------------------------------------------------------

/// WebF Native Module for theme: getTheme, setTheme, getSystemTheme.
///
/// JS usage:
///   const theme = await webf.invokeModule('Theme', 'getTheme');
///   await webf.invokeModule('Theme', 'setTheme', ['dark']);
///   window.addEventListener('themechange', (e) => { console.log(e.detail.theme); });
class ThemeWebfModule extends WebFBaseModule {
  ThemeWebfModule(super.manager);

  @override
  String get name => 'Theme';

  @override
  Future<dynamic> invoke(String method, List<dynamic> arguments) async {
    switch (method) {
      case 'setTheme':
        return _setTheme(arguments);
      case 'getTheme':
        return webfOk(_getThemeName());
      case 'getSystemTheme':
        return webfOk(_getSystemTheme());
      default:
        _log.w('Unknown method: $method');
        return webfErr('Unknown method: $method');
    }
  }

  String _getSystemTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    // Serialize enum via shared EnumToJson extension.
    return brightness.toJson();
  }

  String _getThemeName() => _ThemeStore.instance.current.toJson();

  Future<Map<String, dynamic>> _setTheme(List<dynamic> arguments) async {
    if (arguments.isEmpty) {
      return webfErr('setTheme requires a theme argument');
    }
    final theme = arguments[0] as String?;
    if (theme == null || theme.isEmpty) {
      return webfErr('setTheme requires a theme argument');
    }
    final newMode = enumFromString<ThemeMode>(
      ThemeMode.values,
      theme,
    );
    await _ThemeStore.instance.setTheme(newMode);
    // No payload needed; JS/TS side treats this as Result<void, string>.
    return webfOk(null);
  }

  @override
  void dispose() {}
}
