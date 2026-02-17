import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webf/webf.dart';
import 'package:logging/logging.dart';

final _log = Logger('webfly_webf_view');

/// Access GoRouter's internal [NavigatorState].
///
/// GoRouter doesn't expose `popUntil` directly, so we reach into its
/// internal navigator. Centralised here so a GoRouter API change only
/// requires one fix.
NavigatorState? _navigatorOf(BuildContext context) =>
    GoRouter.of(context).routerDelegate.navigatorKey.currentState;

/// Strategy interface describing how WebF hybrid routing should behave
/// from the delegate's point of view.
///
/// A concrete implementation is typically provided by the host app
/// (for example, via [WebfHybridConfig]).
abstract class WebfHybridStrategy {
  /// Returns whether [path] should be treated as a Flutter-managed route
  /// (and therefore not packed as a WebF inner location).
  bool isFlutterManagedRoute(String path);

  /// Returns whether [path] is a WebF entry route whose inner location
  /// should be unpacked via [resolveWebfLocation].
  bool isWebfEntryRoute(String path);

  /// Returns true if [uri] has the query params (e.g. bundle URL) needed to
  /// build a packed route via [buildWebfPackedRoute] with [fromUri].
  bool canPackFromUri(Uri uri);

  /// Resolves the effective WebF inner location from a WebF entry [entryUri].
  String resolveWebfLocation(Uri entryUri);

  /// Builds a packed Flutter route URL for WebF by rewriting the [location]
  /// into [fromUri]'s query parameters.
  ///
  /// [location] can be raw (e.g. `/led?css=0`, `about`, or empty).
  /// Implementations should normalize it internally.
  String buildWebfPackedRoute({
    required String location,
    required Uri fromUri,
  });
}

/// A [HybridHistoryDelegate] implementation that bridges WebF's hybrid
/// navigation to `go_router` in the hosting Flutter app.
///
/// Configured by [WebfHybridStrategy], so concrete route paths
/// (like `/_/app` or `/_/usecases`) live in the host app rather than
/// inside this package.
///
/// ## bundleUrl propagation
///
/// The host app initiates the first navigation with an explicit bundleUrl:
///
///     GoRouter.push('/_/app?url=<bundleUrl>&ctrl=<ctrl>&loc=/')
///
/// GoRouter stores this full packed URI in [GoRouterState]. When JS later
/// navigates (e.g. `history.pushState('/led')`), the delegate reads the
/// current [GoRouterState.uri] — which already carries bundleUrl — extracts
/// it, and packs a new URI with the updated location:
///
///     /_/app?url=<bundleUrl>&ctrl=<ctrl>&loc=/led
///
/// This way bundleUrl propagates naturally through the navigation stack
/// without explicit caching. Every route entry is self-contained.
///
/// ## Responsibilities
///
/// - Pack plain WebF locations into the hybrid entry route
/// - Expose the *inner* WebF location to JS-side routers (instead of the
///   outer packed Flutter route)
class GoRouterHybridDelegate extends HybridHistoryDelegate {
  GoRouterHybridDelegate(this._strategy);

  final WebfHybridStrategy _strategy;

  String _packIfWebfInnerRoute(BuildContext context, String location) {
    _log.fine('request location=$location');

    // GoRouterState.of throws if context is outside a GoRouter tree;
    // that's a programming error — this delegate is GoRouter-specific.
    final currentUri = GoRouterState.of(context).uri;

    // Dart's Uri.parse is lenient and won't throw, so no try-catch needed.
    final targetUri = Uri.parse(location);

    // If it's already a Flutter-managed route, pass through as-is.
    if (_strategy.isFlutterManagedRoute(targetUri.path)) {
      _log.fine('Flutter-managed route detected path=${targetUri.path}, passthrough');
      return location;
    }

    // Only pack when the current URI carries the bundle URL.
    // This should always be true when JS navigates from within a loaded WebF;
    // a false here likely indicates a context/widget-tree issue.
    if (!_strategy.canPackFromUri(currentUri)) {
      _log.warning('missing bundle url in currentUri=$currentUri, passthrough location=$location');
      return location;
    }

    // Pack the WebF inner location into the hybrid entry route.
    // buildWebfPackedRoute handles normalization (leading `/`, fallback).
    final packed = _strategy.buildWebfPackedRoute(
      location: location,
      fromUri: currentUri,
    );
    _log.fine('packed location=$location currentUri=$currentUri -> $packed');
    return packed;
  }

  @override
  void pop(BuildContext context) {
    if (GoRouter.of(context).canPop()) {
      GoRouter.of(context).pop();
      return;
    }
    Navigator.pop(context);
  }

  @override
  String path(BuildContext? context, String? initialRoute) {
    if (context == null) {
      return initialRoute!;
    }

    final Uri uri;
    try {
      uri = GoRouterState.of(context).uri;
    } on GoError {
      // Context is no longer under a GoRouter route tree (e.g. during
      // pop/unmount). JS-side routers may still query the path during
      // teardown — return a safe fallback instead of crashing.
      _log.fine('path() context detached from GoRouter, fallback');
      return initialRoute ?? '/';
    }

    _log.fine('path() current uri=$uri');

    // Hybrid routing packs the real web route into a query parameter.
    // For WebF/JS routers we should expose the inner route (e.g. `/led`)
    // rather than the outer Flutter route (e.g. `/_/app?url=...&loc=%2Fled`).
    if (_strategy.isWebfEntryRoute(uri.path)) {
      final inner = _strategy.resolveWebfLocation(uri);
      _log.fine('path() wrapper route=${uri.path} inner=$inner');
      return inner;
    }

    return uri.toString();
  }

  @override
  void pushNamed(BuildContext context, String routeName, {Object? arguments}) {
    final route = _packIfWebfInnerRoute(context, routeName);
    GoRouter.of(context).push(route, extra: arguments);
  }

  @override
  void replaceState(BuildContext context, Object? state, String name) {
    final route = _packIfWebfInnerRoute(context, name);
    GoRouter.of(context).pushReplacement(route, extra: state);
  }

  @override
  dynamic state(BuildContext? context, Map<String, dynamic>? initialState) {
    if (context == null) {
      return jsonEncode(initialState ?? {});
    }
    try {
      return jsonEncode(GoRouterState.of(context).extra ?? {});
    } on GoError {
      _log.fine('state() context detached from GoRouter, fallback');
      return jsonEncode(initialState ?? {});
    }
  }

  @override
  String restorablePopAndPushNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    // go_router doesn't support restorable navigation APIs; fall back to a non-restorable equivalent.
    // Pack before pop: read currentUri while the navigation stack is intact.
    final route = _packIfWebfInnerRoute(context, routeName);
    if (GoRouter.of(context).canPop()) {
      GoRouter.of(context).pop();
    }
    GoRouter.of(context).push(route, extra: arguments);
    return route;
  }

  @override
  void popUntil(BuildContext context, RoutePredicate predicate) {
    _navigatorOf(context)?.popUntil(predicate);
  }

  @override
  bool canPop(BuildContext context) {
    return GoRouter.of(context).canPop();
  }

  @override
  Future<bool> maybePop<T extends Object?>(BuildContext context, [T? result]) async {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop(result);
      return true;
    }
    return false;
  }

  @override
  void popAndPushNamed(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    final router = GoRouter.of(context);
    // Pack before pop: read currentUri while the navigation stack is intact.
    final route = _packIfWebfInnerRoute(context, routeName);
    if (router.canPop()) {
      router.pop();
    }
    router.push(route, extra: arguments);
  }

  @override
  void pushNamedAndRemoveUntil(
    BuildContext context,
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    final router = GoRouter.of(context);
    final route = _packIfWebfInnerRoute(context, newRouteName);
    _navigatorOf(context)?.popUntil(predicate);
    router.push(route, extra: arguments);
  }
}
