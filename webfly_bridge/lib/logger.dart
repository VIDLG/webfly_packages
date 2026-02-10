// Logger for webfly_theme, webfly_permission, webfly_ble, etc.
// Usage: import 'package:webfly_bridge/webfly_bridge.dart'; final _log = webflyLogger('name');
// Or: import 'package:webfly_bridge/logger.dart';
//
// Log level: [setWebflyLogLevel] in code, or compile-time --dart-define=WEBFLY_BRIDGE_LOG_LEVEL=info (default: debug).

import 'package:logger/logger.dart';

export 'package:logger/logger.dart' show Level, Logger;

Level _levelFromString(String value) {
  switch (value.toLowerCase()) {
    case 'all':
    case 'trace':
      return Level.trace;
    case 'debug':
      return Level.debug;
    case 'info':
      return Level.info;
    case 'warning':
    case 'warn':
      return Level.warning;
    case 'error':
      return Level.error;
    case 'fatal':
      return Level.fatal;
    case 'off':
      return Level.off;
    default:
      return Level.debug;
  }
}

Level _webflyLogLevel = _levelFromString(
  const String.fromEnvironment('WEBFLY_BRIDGE_LOG_LEVEL', defaultValue: 'debug'),
);

/// Sets the default log level for [webflyLogger].
/// Call at app startup, e.g. setWebflyLogLevel(Level.info).
void setWebflyLogLevel(Level level) {
  _webflyLogLevel = level;
}

/// Current default log level used by [webflyLogger] when [level] is omitted.
Level get webflyLogLevel => _webflyLogLevel;

class _NamedLogPrinter extends LogPrinter {
  _NamedLogPrinter(this.name);
  final String name;
  final _simple = SimplePrinter(colors: true);

  @override
  List<String> log(LogEvent event) {
    final lines = _simple.log(event);
    return lines.map((line) => '[$name] $line').toList();
  }
}

/// Returns a [Logger] that prefixes all output with [name], e.g. [webfly_theme].
/// [level] overrides the default (from [setWebflyLogLevel] or --dart-define=WEBFLY_BRIDGE_LOG_LEVEL).
/// Use in packages: final _log = webflyLogger('webfly_theme'); _log.w('message');
Logger webflyLogger(String name, {Level? level}) {
  return Logger(
    printer: _NamedLogPrinter(name),
    level: level ?? _webflyLogLevel,
  );
}
