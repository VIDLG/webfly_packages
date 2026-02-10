/**
 * Theme WebF module: get/set theme and listen to theme changes.
 * Uses webfly_bridge (createModuleInvoker, Result).
 *
 * Usage:
 *   import { getTheme, setTheme, getSystemTheme, addThemeChangeListener } from '@webfly/theme';
 *   const res = await getTheme();  // Result<ThemePreference, string>
 *   await setTheme('dark');
 *   const unsub = addThemeChangeListener((theme) => console.log('theme:', theme));
 *
 * Theme changes are emitted via window 'themechange' (detail: { theme: string }).
 * Flutter also dispatches 'colorschemchange' for compatibility.
 */

import { createModuleInvoker, type Result } from '../../webfly_bridge/lib/webfly_bridge';

const invoke = createModuleInvoker('Theme');

export type ThemePreference = 'light' | 'dark' | 'system';

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
export function getSystemTheme(): Promise<Result<'light' | 'dark', string>> {
  return invoke<'light' | 'dark'>('getSystemTheme');
}

const THEME_CHANGE_EVENT = 'themechange';

export interface ThemeChangeEventDetail {
  theme: ThemePreference;
}

/**
 * Listen to theme changes. Flutter dispatches 'themechange' when theme is set (from JS or native).
 * Returns an unsubscribe function.
 */
export function addThemeChangeListener(callback: (theme: ThemePreference) => void): () => void {
  const handler = (e: Event) => {
    const detail = (e as CustomEvent<ThemeChangeEventDetail>).detail;
    if (detail?.theme) callback(detail.theme);
  };
  window.addEventListener(THEME_CHANGE_EVENT, handler);
  return () => window.removeEventListener(THEME_CHANGE_EVENT, handler);
}
