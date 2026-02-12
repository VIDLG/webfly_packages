/// Generic WebF + GoRouter hybrid routing configuration and URL helpers.
///
/// This file intentionally avoids hard-coding any concrete route paths from a
/// specific app (like `/_/app`, `/_/scanner`, etc). Instead, those live in the
/// host app and are passed in via [WebfHybridConfig].
library;

import 'package:flutter/material.dart';

import 'go_router_delegate.dart';

/// Immutable configuration describing how a host app wires WebF hybrid routing.
class WebfHybridConfig implements WebfHybridStrategy {
  const WebfHybridConfig({
    this.flutterPrefix = defaultFlutterPrefix,
    this.entrySubRoute = defaultEntrySubRoute,
    this.fallbackLocation = defaultFallbackLocation,
    this.bundleUrlParam = defaultBundleUrlParam,
    this.controllerParam = defaultControllerParam,
    this.locationParam = defaultLocationParam,
  });

  /// Default instance with all default values.
  static const defaults = WebfHybridConfig();

  static const defaultFlutterPrefix = '/_';
  static const defaultEntrySubRoute = 'app';
  static const defaultFallbackLocation = '/';
  static const defaultBundleUrlParam = 'url';
  static const defaultControllerParam = 'ctrl';
  static const defaultLocationParam = 'loc';

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Prefix reserved for Flutter-managed screens (so we don't accidentally
  /// treat them as WebF inner routes when wrapping).
  final String flutterPrefix;

  /// Relative sub-route under [flutterPrefix] that serves as the WebF entry
  /// (e.g. `'app'` when the full route is `/_/app`).
  ///
  /// WebF hybrid data (url, ctrl, loc) is packed into the entry URI under
  /// this sub-route.
  final String entrySubRoute;

  /// Default WebF inner location used inside the Web app (e.g. `/`).
  ///
  /// Used as the fallback WebF inner location when [locationParam] is
  /// missing in the hybrid URL.
  final String fallbackLocation;

  /// Query parameter keys for WebF hybrid bundle.
  ///
  /// - [bundleUrlParam]: key for the Web bundle/base URL (e.g. `url`);
  /// - [controllerParam]: key for controller name (e.g. `ctrl`);
  /// - [locationParam]: key for WebF inner location (path + query +
  ///   fragment) (e.g. `loc`).
  final String bundleUrlParam;
  final String controllerParam;
  final String locationParam;

  // ---------------------------------------------------------------------------
  // Derived getters
  // ---------------------------------------------------------------------------

  /// Full Flutter route for the WebF entry, derived from
  /// [flutterPrefix] + [entrySubRoute].
  String get entryRoute => flutterPrefix.endsWith('/')
      ? '$flutterPrefix$entrySubRoute'
      : '$flutterPrefix/$entrySubRoute';

  // ---------------------------------------------------------------------------
  // Strategy interface (@override)
  // ---------------------------------------------------------------------------

  @override
  bool isFlutterManagedRoute(String path) {
    if (path.isEmpty) return false;
    return path.startsWith(flutterPrefix);
  }

  @override
  bool isWebfEntryRoute(String path) => path == entryRoute;

  /// Resolves the effective WebF inner location from a WebF entry [entryUri],
  /// falling back to [fallbackLocation] when the packed location is missing.
  @override
  String resolveWebfLocation(Uri entryUri) {
    return normalizeWebfInnerPath(
      entryUri.queryParameters[locationParam],
      fallbackLocation,
    );
  }

  /// Returns true if [uri] has the query params (e.g. [bundleUrlParam])
  /// needed to build a packed route via [buildWebfPackedRoute] with [fromUri].
  @override
  bool canPackFromUri(Uri uri) {
    final url = uri.queryParameters[bundleUrlParam];
    return url != null && url.isNotEmpty;
  }

  /// Rewrites [location] into [fromUri]'s existing query parameters.
  ///
  /// Used by the delegate when JS navigates: bundleUrl / ctrl are carried
  /// over from the current route, only the inner location changes.
  @override
  String buildWebfPackedRoute({
    required String location,
    required Uri fromUri,
  }) {
    final bundleUrl = fromUri.queryParameters[bundleUrlParam];
    assert(
      bundleUrl != null && bundleUrl.isNotEmpty,
      'url parameter missing in URI',
    );
    final resolvedLocation = normalizeWebfInnerPath(location, fallbackLocation);
    final encodedUrl = Uri.encodeComponent(bundleUrl!);
    final encodedCtrl = Uri.encodeComponent(
      fromUri.queryParameters[controllerParam] ?? 'webf-${bundleUrl.hashCode}',
    );
    final encodedLocation = Uri.encodeComponent(resolvedLocation);
    return '$entryRoute?$bundleUrlParam=$encodedUrl'
        '&$controllerParam=$encodedCtrl'
        '&$locationParam=$encodedLocation';
  }
}

/// Default [GoRouterHybridDelegate] using [WebfHybridConfig.defaults].
final defaultGoRouterDelegate = GoRouterHybridDelegate(
  WebfHybridConfig.defaults,
);

/// Default [RouteObserver] for WebF pages.
final defaultWebfRouteObserver = RouteObserver<PageRoute>();

/// Normalizes a WebF *inner route* string and returns a canonical location.
///
/// - Input can be `led`, `/led`, `/led?css=0#top`, etc.
/// - Output guarantees:
///   - Always starts with `/` (empty path is normalized to `/`);
///   - Preserves query / fragment if present;
///   - Returns [fallback] for `null` or whitespace-only input.
///
/// The result is intended to be used directly as the WebF initialRoute / JS
/// router location.
String normalizeWebfInnerPath(String? rawPath, [String fallback = '/']) {
  if (rawPath == null) return fallback;
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) return fallback;
  var uri = Uri.parse(trimmed.startsWith('/') ? trimmed : '/$trimmed');
  if (uri.path.isEmpty) {
    uri = uri.replace(path: '/');
  }
  return uri.toString();
}
