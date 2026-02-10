// Shared WebF bridge (Dart). Wire format for TS: { type: 'ok', value: T } | { type: 'err', message: string }.
// Usage: import 'package:webfly_bridge/webfly_bridge.dart';

import 'package:anyhow/anyhow.dart';

export 'logger.dart' show
    Level,
    Logger,
    webflyLogger,
    setWebflyLogLevel,
    webflyLogLevel;

/// Success payload for WebF TS: { type: 'ok', value: value }.
Map<String, dynamic> webfOk(dynamic value) => {'type': 'ok', 'value': value};

/// Error payload for WebF TS: { type: 'err', message: message }.
Map<String, dynamic> webfErr(String message) => {'type': 'err', 'message': message};

/// Serialize any enum to a JSON-serializable value (enum name string).
extension EnumToJson on Enum {
  String toJson() => name;
}

/// Parse an enum value from its [name] (as used by [Enum.name]).
///
/// By default this is *case-insensitive* so that inputs like 'Dark' / 'DARK'
/// still match an enum whose [Enum.name] is 'dark'. Pass [ignoreCase: false]
/// if you need strict, case-sensitive matching.
///
/// Throws [ArgumentError] if no matching value is found.
T enumFromString<T extends Enum>(
  Iterable<T> values,
  String name, {
  bool ignoreCase = true,
}) {
  return values.firstWhere(
    (e) => ignoreCase
        ? e.name.toLowerCase() == name.toLowerCase()
        : e.name == name,
    orElse: () => throw ArgumentError.value(
      name,
      'name',
      'No enum value `$name` in enum type $T',
    ),
  );
}

// For now we only expose [enumFromString]. If callers need a nullable / JSON
// variant later, we can add helpers like `enumFromStringOrNull` or `enumFromJson`.

/// Converts [Result] to WebF response map. Optional [mapper] to serialize the success value.
extension ResultToJson<S> on Result<S> {
  Map<String, dynamic> toJson([dynamic Function(S s)? mapper]) {
    return match(
      ok: (value) => webfOk(mapper != null ? mapper(value) : value),
      err: (e) => webfErr(e.toString()),
    );
  }
}
