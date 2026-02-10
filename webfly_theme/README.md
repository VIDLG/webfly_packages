# webfly_theme

WebF native module for theme: get/set theme preference, persist, and stream theme changes.

- **Uses `webfly_bridge`** for Dart response helpers (`webfOk`/`webfErr`) and TS `createModuleInvoker` + `Result`.
- **No `signals_flutter` dependency.** Events are expressed as a `Stream<ThemeMode>`. Callers that need reactivity can use `useStreamSignal(() => themeStream, initialValue: getTheme())` directly in their widgets.

## Dart (Flutter)

- **Register module:** `WebF.defineModule((context) => ThemeWebfModule(context));`
- **Initialize (once at startup):** `await initializeTheme();`
- **Current theme (sync):** `getTheme()` → `ThemeMode`
- **Listen to changes:** `themeStream` (broadcast `Stream<ThemeMode>`; use with `useStreamSignal` or `.listen()`)
- **Set from Flutter:** `setTheme(ThemeMode)` (e.g. settings dialog)
- **Reactive usage (in app):** in a `HookWidget`, use `useStreamSignal(() => themeStream, initialValue: getTheme())` to read the current `ThemeMode` and rebuild on changes.

## JavaScript / TypeScript

- **Get theme:** `getTheme()` → `Promise<WebfResponse<'light' | 'dark' | 'system'>>`
- **Set theme:** `setTheme('light' | 'dark' | 'system')`
- **System theme:** `getSystemTheme()` → `Promise<WebfResponse<'light' | 'dark'>>`
- **Listen to changes:** `addThemeChangeListener((theme) => { ... })` (returns unsubscribe), or `window.addEventListener('themechange', (e) => { e.detail.theme })`

Flutter dispatches `themechange` (with `detail.theme`) and `colorschemchange` when theme changes so the frontend can stay in sync.
