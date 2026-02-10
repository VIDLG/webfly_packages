/**
 * Theme WebF module: get/set theme and listen to theme changes.
 * Uses webfly_bridge (createModuleInvoker, Result, WebfModuleEventBus).
 *
 * Usage:
 *   import { getTheme, setTheme, getSystemTheme, addThemeChangeListener } from '@webfly/theme';
 *   const res = await getTheme();  // Result<ThemeState, string>
 *   await setTheme('dark');
 *   const unsub = addThemeChangeListener((theme) => console.log('theme:', theme));
 *
 * Theme changes are emitted as WebF module events ('themechange' with payload { theme }),
 * so they work consistently for both JS-initiated and native theme updates.
 */

import { createModuleInvoker, WebfModuleEventBus, type Result } from '../../webfly_bridge/lib/webfly_bridge';

const invoke = createModuleInvoker('Theme');

// Mirror Dart naming: ThemeMode (may be 'system') and ResolvedTheme (light/dark only).
export type ThemeMode = 'light' | 'dark' | 'system';
export type ResolvedTheme = 'light' | 'dark';

export interface ThemeState {
  /** User preference: 'light' | 'dark' | 'system'. */
  themePreference: ThemeMode;
  /** Resolved theme for rendering: 'light' | 'dark'. */
  resolvedTheme: ResolvedTheme;
}

/**
 * Get current theme state: user preference + resolved theme.
 */
export function getTheme(): Promise<Result<ThemeState, string>> {
  return invoke<ThemeState>('getTheme');
}

/**
 * Set theme preference.
 *
 * Returns `Result<void, string>`; callers usually only care about success/failure,
 * so the `ok` payload is not used.
 */
export function setTheme(theme: ThemeMode): Promise<Result<void, string>> {
  return invoke<void>('setTheme', theme);
}

/**
 * Get current platform (system) theme.
 */
export function getSystemTheme(): Promise<Result<ResolvedTheme, string>> {
  return invoke<ResolvedTheme>('getSystemTheme');
}

const THEME_CHANGE_EVENT = 'themechange';

type ThemeEventType = typeof THEME_CHANGE_EVENT;
interface ThemeEventPayloadMap {
  themechange: ThemeState;
}

class ThemeEventBus extends WebfModuleEventBus<ThemeEventType, ThemeEventPayloadMap> {
  protected override get moduleName(): string {
    return 'Theme';
  }
}

const defaultThemeEventBus = new ThemeEventBus();

/**
 * Listen to theme changes from the Theme WebF module.
 * Returns an unsubscribe function.
 */
export function addThemeChangeListener(callback: (state: ThemeState) => void): () => void {
  return defaultThemeEventBus.addListener('themechange', (payload) => {
    const detail = payload as ThemeState | undefined;
    if (!detail) {
      throw new Error('[ThemeEventBus] themechange payload is undefined');
    }
    callback(detail);
  });
}
