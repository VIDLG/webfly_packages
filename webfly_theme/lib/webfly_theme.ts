/**
 * Theme WebF module: get/set theme and listen to theme changes.
 * Uses webfly_bridge (createModuleInvoker, Result, WebfModuleEventBus).
 *
 * Usage:
 *   import { getTheme, setTheme, getSystemTheme, addThemeChangeListener } from '@webfly/theme';
 *   const res = await getTheme();  // Result<ThemePreference, string>
 *   await setTheme('dark');
 *   const unsub = addThemeChangeListener((theme) => console.log('theme:', theme));
 *
 * Theme changes are emitted as WebF module events ('themechange' with payload { theme }),
 * so they work consistently for both JS-initiated and native theme updates.
 */

import { createModuleInvoker, WebfModuleEventBus, type Result } from '../../webfly_bridge/lib/webfly_bridge';

const invoke = createModuleInvoker('Theme');

export type ThemePreference = 'light' | 'dark' | 'system';
export type SystemTheme = 'light' | 'dark';

/**
 * Get current theme preference.
 */
export function getTheme(): Promise<Result<ThemePreference, string>> {
  return invoke<ThemePreference>('getTheme');
}

/**
 * Set theme preference.
 *
 * Returns `Result<void, string>`; callers usually only care about success/failure,
 * so the `ok` payload is not used.
 */
export function setTheme(theme: ThemePreference): Promise<Result<void, string>> {
  return invoke<void>('setTheme', theme);
}

/**
 * Get current platform (system) theme.
 */
export function getSystemTheme(): Promise<Result<SystemTheme, string>> {
  return invoke<SystemTheme>('getSystemTheme');
}

const THEME_CHANGE_EVENT = 'themechange';

export interface ThemeChangeEventDetail {
  theme: ThemePreference;
}

type ThemeEventType = typeof THEME_CHANGE_EVENT;
interface ThemeEventPayloadMap {
  themechange: ThemeChangeEventDetail;
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
export function addThemeChangeListener(callback: (theme: ThemePreference) => void): () => void {
  return defaultThemeEventBus.addListener('themechange', (payload) => {
    const detail = payload as ThemeChangeEventDetail | undefined;
    const theme = detail?.theme;
    if (!theme) return;
    callback(theme);
  });
}
