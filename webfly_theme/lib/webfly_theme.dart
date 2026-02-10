// Theme WebF module: get/set theme, persist, and stream theme changes.
// No signals_flutter: callers use useStreamSignal(themeStream, initialValue: getTheme())
// in the widgets that need theme reactivity.
//
// In app: import 'package:webfly_theme/webfly_theme.dart'
//          show ThemeWebfModule, themeStream, getTheme, getThemeState, initializeTheme, setTheme;
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

/// Resolved theme for rendering; never includes `system`.
enum ResolvedTheme { light, dark }

/// Theme state used for WebF wire format (preference + resolved).
class ThemeState {
  const ThemeState({
    required this.themePreference,
    required this.resolvedTheme,
  });

  final ThemeMode themePreference;
  final ResolvedTheme resolvedTheme;

  Map<String, String> toJson() => <String, String>{
        'themePreference': themePreference.toJson(),
        'resolvedTheme': resolvedTheme.toJson(),
      };
}

/// Resolve a [ThemeMode] (which may be `system`) into a concrete [ResolvedTheme].
ResolvedTheme _resolveTheme(ThemeMode mode) {
  if (mode == ThemeMode.system) {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark
        ? ResolvedTheme.dark
        : ResolvedTheme.light;
  }
  return mode == ThemeMode.dark ? ResolvedTheme.dark : ResolvedTheme.light;
}

class _ThemeStore with WidgetsBindingObserver {
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
  final _themeChangeController = StreamController<ThemeState>.broadcast();

  Stream<ThemeState> get themeStream => _themeChangeController.stream;

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
    WidgetsBinding.instance.addObserver(store);
  }

  ThemeMode get current => _current;

  /// Resolved theme for rendering based on the current preference.
  ResolvedTheme get resolved {
    return _resolveTheme(_current);
  }

  /// Combined theme state (preference + resolved). Convenient for emitting
  /// events or exposing a structured snapshot.
  ThemeState get state => ThemeState(
        themePreference: _current,
        resolvedTheme: resolved,
      );

  Future<void> setTheme(ThemeMode mode) async {
    if (_current == mode) return;
    _current = mode;
    // Persist selection; let errors surface to the caller.
    await _prefs.setString(_themeModeKey, mode.name);
    _themeChangeController.add(state);
  }

  @override
  void didChangePlatformBrightness() {
    // Only react when user preference is `system`.
    if (_current != ThemeMode.system) return;
    // Emit a new ThemeState snapshot so listeners (Flutter UI / WebF) can react.
    _themeChangeController.add(state);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeChangeController.close();
    _instance = null;
  }
}

/// Initialize theme store (load from disk). Call once at app startup.
Future<void> initializeTheme() async {
  await _ThemeStore.create();
}

/// Current theme state (preference + resolved). Use as initialValue for
/// useStreamSignal or after initializeTheme().
ThemeState getTheme() => _ThemeStore.instance.state;

/// Resolved theme for rendering (light/dark only).
ResolvedTheme getResolvedTheme() {
  return _ThemeStore.instance.resolved;
}

/// Stream of theme changes (ThemeState). Emits when theme is set from JS or Flutter.
/// Caller: useStreamSignal(() => themeStream, initialValue: getTheme()) for a reactive signal.
Stream<ThemeState> get themeStream => _ThemeStore.instance.themeStream;

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

  StreamSubscription<ThemeState>? _themeSub;

  @override
  Future<void> initialize() async {
    // Ensure theme store is initialized so themeStream is ready.
    await initializeTheme();
    _themeSub ??= themeStream.listen(_emitThemeChanged);
  }

  @override
  String get name => 'Theme';

  @override
  Future<dynamic> invoke(String method, List<dynamic> arguments) async {
    switch (method) {
      case 'setTheme':
        return _setTheme(arguments);
      case 'getTheme':
        return webfOk(_getThemeState());
      case 'getSystemTheme':
        return webfOk(_getSystemTheme());
      default:
        _log.w('Unknown method: $method');
        return webfErr('Unknown method: $method');
    }
  }

  String _getSystemTheme() => _resolveTheme(ThemeMode.system).toJson();

  Map<String, String> _getThemeState() {
    return _ThemeStore.instance.state.toJson();
  }

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

  void _emitThemeChanged(ThemeState state) {
    try {
      _log.d(
        'ThemeWebfModule._emitThemeChanged: preference=${state.themePreference} '
        'resolved=${state.resolvedTheme}',
      );
      dispatchEvent(
        // Use CustomEvent so that payload is exposed via `event.detail`
        // following the W3C CustomEvent convention.
        event: CustomEvent('themechange', detail: state.toJson()),
      );
    } catch (e) {
      _log.w('themechange emit error: $e');
    }
  }

  @override
  void dispose() {
    _themeSub?.cancel();
    _themeSub = null;
  }
}
