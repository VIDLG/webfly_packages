import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_use/flutter_use.dart';
import 'package:webf/webf.dart';
import 'package:anyhow/anyhow.dart';
import 'package:webfly_theme/webfly_theme.dart';
import 'package:webfly_bridge/logger.dart';
import 'hybrid_config.dart';

final _log = webflyLogger('webf_view');

// ---------------------------------------------------------------------------
// Error helpers (internal to this file)
// ---------------------------------------------------------------------------

enum WebFViewErrorKind { webfController, routeResolution }

Result<T> _webfControllerError<T>({
  String? message,
  required String controllerName,
  required String url,
  Object? cause,
  StackTrace? stackTrace,
}) {
  final Object rootCause = cause ?? message ?? 'WebF controller error';
  _log.e(
    '[WebFControllerError] Failed to initialize WebF controller',
    error: rootCause,
    stackTrace: stackTrace,
  );
  return Err<T>(Error(rootCause))
      .context('Failed to initialize WebF controller')
      .context(WebFViewErrorKind.webfController)
      .context(<String, Object?>{
        'controllerName': controllerName,
        'url': url,
        ...?(message != null ? {'message': message} : null),
      });
}

Result<T> _routeResolutionError<T>({
  String? message,
  required String routePath,
  required String controllerName,
  Object? cause,
  StackTrace? stackTrace,
}) {
  final Object rootCause = cause ?? message ?? 'Route resolution error';
  _log.e(
    '[RouteResolutionError] Failed to resolve route',
    error: rootCause,
    stackTrace: stackTrace,
  );
  return Err<T>(Error(rootCause))
      .context('Failed to resolve route')
      .context(WebFViewErrorKind.routeResolution)
      .context(<String, Object?>{
        'routePath': routePath,
        'controllerName': controllerName,
        ...?(message != null ? {'message': message} : null),
      });
}

void _syncThemeToWebF(WebFController controller, ThemeMode themeMode) {
  // WebF automatically syncs with system theme when themeMode is ThemeMode.system.
  // We only need to set darkModeOverride when user explicitly chooses light or dark.
  switch (themeMode) {
    case ThemeMode.light:
      controller.darkModeOverride = false;
      break;
    case ThemeMode.dark:
      controller.darkModeOverride = true;
      break;
    case ThemeMode.system:
      // Clear override to let WebF automatically sync with system theme.
      controller.darkModeOverride = null;
      break;
  }
  // Theme change events ('themechange') are now dispatched by ThemeWebfModule
  // via WebF module events, so no JS evaluation is needed here.
}

bool _canResolveHybridRoute(
  WebFController controller, {
  required String fullPath,
  required String pathOnly,
}) {
  try {
    final dynamic dynamicController = controller;
    final dynamic view = dynamicController.view;
    final dynamic result = view.getHybridRouterView(pathOnly);
    return result != null;
  } catch (e) {
    _log.d('[WebFView] Hybrid route check failed: $e');
    return false;
  }
}

/// Injects a WebF bundle and returns a Result type.
///
/// Theme sync is not done here; the caller should set [WebFController.onLoad]
/// (and sync when [ThemeMode] changes) so theme is applied after load.
Future<Result<WebFController>> injectWebfBundleAsync({
  required String controllerName,
  required String url,
  void Function(String)? onJSRuntimeError,
  Duration? timeout,
  RouteObserver<PageRoute>? routeObserver,
  HybridHistoryDelegate? hybridHistoryDelegate,
}) async {
  try {
    WebFController? controller = await WebFControllerManager.instance
        .addWithPrerendering(
          name: controllerName,
          createController: () => WebFController(
            routeObserver: routeObserver ?? defaultWebfRouteObserver,
            onJSError: (String errorMessage) {
              _log.e(
                '❌ JavaScript Error in: $controllerName\n$errorMessage',
                error: errorMessage,
              );
              onJSRuntimeError?.call(errorMessage);
            },
          ),
          bundle: WebFBundle.fromUrl(url),
          timeout: timeout,
          setup: (controller) {
            controller.hybridHistory.delegate =
                hybridHistoryDelegate ?? defaultGoRouterDelegate;
          },
        );

    // WebFControllerManager may return null due to concurrency rules (another request won).
    // In that case, fetch the winner controller.
    controller ??= await WebFControllerManager.instance.getController(
      controllerName,
    );

    if (controller == null) {
      return _webfControllerError<WebFController>(
        message: 'Controller initialization returned null',
        controllerName: controllerName,
        url: url,
      );
    }

    return Ok(controller);
  } catch (e, stackTrace) {
    return _webfControllerError<WebFController>(
      cause: e,
      controllerName: controllerName,
      url: url,
      stackTrace: stackTrace,
    );
  }
}

/// Default loading widget for WebF view
Widget _defaultLoadingWidget() {
  return const Center(child: CircularProgressIndicator());
}

/// Default error widget for WebF view
Widget _defaultErrorWidget(Object? error) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text(error?.toString() ?? 'Unknown error', textAlign: TextAlign.center),
      ],
    ),
  );
}

class _JavaScriptRuntimeErrorView extends StatelessWidget {
  const _JavaScriptRuntimeErrorView({
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 900),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade700),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'JavaScript Runtime Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: SelectableText(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pure WebF view widget without Scaffold or AppBar.
///
/// This widget handles WebF controller lifecycle, route focus monitoring,
/// and displays loading/error states. It's designed to be composed into
/// larger page structures rather than being a complete page itself.
class WebFView extends HookWidget {
  const WebFView({
    super.key,
    required this.url,
    required this.controllerName,
    this.routePath = '/',
    this.cacheControllers = false,
    this.loadingBuilder,
    this.errorBuilder,
    this.controllerLoadingTimeout = const Duration(seconds: 15),
    this.hybridRouteResolutionTimeout = const Duration(seconds: 10),
    this.hybridRoutePollInterval = const Duration(milliseconds: 50),
    this.routeObserver,
    this.hybridHistoryDelegate,
  });

  final String url;
  final String controllerName;
  final String routePath;

  /// Whether to cache controllers across widget disposal.
  final bool cacheControllers;

  /// Optional custom loading widget builder
  final Widget Function(BuildContext)? loadingBuilder;

  /// Optional custom error widget builder
  final Widget Function(BuildContext, Object?)? errorBuilder;

  /// Timeout for controller loading.
  final Duration controllerLoadingTimeout;

  /// Timeout for hybrid route resolution.
  final Duration hybridRouteResolutionTimeout;

  /// Polling interval for checking hybrid route resolution.
  final Duration hybridRoutePollInterval;

  /// Route observer for WebF pages. Defaults to [defaultWebfRouteObserver].
  final RouteObserver<PageRoute>? routeObserver;

  /// Hybrid history delegate. Defaults to [defaultGoRouterDelegate].
  final HybridHistoryDelegate? hybridHistoryDelegate;

  @override
  Widget build(BuildContext context) {
    final jsRuntimeError = useState<String?>(null);
    final didMountRootWebF = useRef(false);
    final hybridRouteReady = useState(false);
    final hybridRouteTimeoutError = useState<Object?>(null);

    // Theme: subscribe to themeStream via useStream.
    final themeSnapshot = useStream(themeStream, initialData: getTheme());
    final themeState = themeSnapshot.data ?? getTheme();
    final themeMode = themeState.themePreference;

    final parsedPath = Uri.parse(routePath).path;
    final pathOnly = parsedPath.isEmpty ? '/' : parsedPath;
    final bool isRootPath = pathOnly == '/';

    // Build controller via useFuture so loading/error/data is centralized.
    final generation = useRef(0);
    final controllerFuture = useMemoized(() async {
      final localGen = ++generation.value;

      // Clear previous JS errors for the new load attempt.
      jsRuntimeError.value = null;

      // Reuse existing controller if already present.
      final existing = WebFControllerManager.instance.getControllerSync(
        controllerName,
      );
      if (existing != null && !existing.disposed) {
        // Keep delegate wired even across rebuilds.
        existing.hybridHistory.delegate =
            hybridHistoryDelegate ?? defaultGoRouterDelegate;
        return existing;
      }

      final timeout = controllerLoadingTimeout;

      final result = await injectWebfBundleAsync(
        controllerName: controllerName,
        url: url,
        timeout: timeout,
        routeObserver: routeObserver,
        hybridHistoryDelegate: hybridHistoryDelegate,
        onJSRuntimeError: (errorMessage) {
          if (!context.mounted) return;
          // Ignore stale callbacks from previous loads.
          if (generation.value != localGen) return;
          jsRuntimeError.value = errorMessage;
        },
      );

      return result.match(
        ok: (controller) => controller,
        err: (error) {
          // Log additional business context for debugging.
          _log.d(
            '[WebFView] Error context',
            error:
                'route=$routePath, controller=$controllerName, '
                'url=$url, timeout=${timeout.inSeconds}s, '
                'cacheControllers=$cacheControllers, '
                'waitForHybridRoute=${routePath != '/'}',
          );

          // Preserve anyhow error chain + contexts.
          throw error;
        },
      );
    }, [controllerName, url]);
    final controllerSnapshot = useFuture(controllerFuture);

    final controller = controllerSnapshot.data;
    final initError = controllerSnapshot.error;

    final hasController = controller != null;
    final shouldMountWebF =
        hasController &&
        (isRootPath || controller.state == null || didMountRootWebF.value);

    // Deep-link bootstrap: before mounting WebF with an initialRoute != '/', try to
    // wait until WebF can resolve the hybrid router view. This avoids transient
    // "Loading Error: the route path ... was not found" during router registration.
    final shouldWaitForHybridRoute =
        shouldMountWebF && !isRootPath && !didMountRootWebF.value;

    // Sync theme to WebF when themeMode or controller changes; set onLoad so
    // theme is dispatched again when the page loads (frontend can then listen).
    useEffect(() {
      if (controller != null) {
        _syncThemeToWebF(controller, themeMode);
        controller.onLoad = (ctrl) => _syncThemeToWebF(ctrl, themeMode);
      }
      return null;
    }, [themeMode, controller]);

    // Disposal policy:
    // Only an instance that actually mounted a WebF widget (via WebF.fromControllerName)
    // is considered the owner of the controller lifecycle.
    useEffect(() {
      final controllerNameForDispose = controllerName;
      final shouldCacheControllersForDispose = cacheControllers;

      return () {
        if (!shouldCacheControllersForDispose && didMountRootWebF.value) {
          unawaited(
            WebFControllerManager.instance.removeAndDisposeController(
              controllerNameForDispose,
            ),
          );
        }
      };
    }, [controllerName, cacheControllers]);

    // Reset hybrid route state when not waiting.
    useEffect(() {
      if (!shouldWaitForHybridRoute) {
        hybridRouteReady.value = hasController;
        hybridRouteTimeoutError.value = null;
      }
      return null;
    }, [shouldWaitForHybridRoute, hasController]);

    // Poll for hybrid route resolution (null delay = paused).
    useInterval(() {
      if (controller == null) return;
      final ready = _canResolveHybridRoute(
        controller,
        fullPath: routePath,
        pathOnly: pathOnly,
      );
      if (ready && !hybridRouteReady.value) {
        hybridRouteReady.value = true;
      }
    }, shouldWaitForHybridRoute ? hybridRoutePollInterval : null);

    // Timeout: give up after hybridRouteResolutionTimeout.
    useEffect(() {
      if (!shouldWaitForHybridRoute) return null;
      hybridRouteTimeoutError.value = null;

      final timeoutTimer = Timer(hybridRouteResolutionTimeout, () {
        if (!context.mounted) return;
        if (hybridRouteReady.value) return;

        final result = _routeResolutionError<void>(
          message: 'Hybrid route resolution timeout',
          routePath: routePath,
          controllerName: controllerName,
        );
        final error = result.unwrapErr();

        _log.d(
          '[WebFView] Route timeout context',
          error:
              'route=$routePath, controller=$controllerName, '
              'pollInterval=${hybridRoutePollInterval.inMilliseconds}ms, '
              'timeout=${hybridRouteResolutionTimeout.inSeconds}s',
        );

        hybridRouteTimeoutError.value = error;
      });

      return timeoutTimer.cancel;
    }, [shouldWaitForHybridRoute, controller, routePath]);

    // If we decided to mount root WebF, mark ownership without triggering rebuilds.
    // This is used for lifecycle ownership and to avoid branch-flips later.
    if (shouldMountWebF &&
        (!shouldWaitForHybridRoute || hybridRouteReady.value)) {
      didMountRootWebF.value = true;
    }

    final routeOrInitOrTimeoutError =
        initError ?? hybridRouteTimeoutError.value;
    if (routeOrInitOrTimeoutError != null) {
      return errorBuilder?.call(context, routeOrInitOrTimeoutError) ??
          _defaultErrorWidget(routeOrInitOrTimeoutError);
    }

    if (jsRuntimeError.value != null) {
      return _JavaScriptRuntimeErrorView(
        message: jsRuntimeError.value!,
        onClose: () => jsRuntimeError.value = null,
      );
    }

    if (controller == null ||
        (shouldWaitForHybridRoute && !hybridRouteReady.value)) {
      return loadingBuilder?.call(context) ?? _defaultLoadingWidget();
    }

    // Memoize WebF widget so we don't create a new instance on every build.
    // Otherwise webf package may re-run load and log "WebF: loading with controller" repeatedly.
    final webFWidget = useMemoized(
      () => WebF.fromControllerName(
        controllerName: controllerName,
        initialRoute: pathOnly,
        loadingWidget: loadingBuilder?.call(context) ?? _defaultLoadingWidget(),
        errorBuilder: (context, error) {
          final resolvedError =
              errorBuilder?.call(context, error) ?? _defaultErrorWidget(error);
          return resolvedError;
        },
      ),
      [controllerName, pathOnly],
    );

    if (shouldMountWebF) {
      return webFWidget;
    }

    return WebFRouterView(
      controller: controller,
      path: pathOnly,
      defaultViewBuilder: (context) {
        return loadingBuilder?.call(context) ?? _defaultLoadingWidget();
      },
    );
  }
}
