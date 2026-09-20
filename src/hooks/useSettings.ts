import { useCallback, useState } from "react";

/**
 * App preferences that persist per viewer in localStorage.
 *
 * In the web prototype these are honest toggles that remember their state. In
 * the packaged Tauri build they map to real behaviour (launch-at-login,
 * background running, menu-bar visibility) via the tray app; the wiring lives
 * in src-tauri and is a no-op here.
 */
export interface AppSettings {
  launchAtLogin: boolean;
  runInBackground: boolean;
  hideMenuIcons: boolean;
  darkMode: boolean;
  balanceAlerts: boolean;
  keepAwake: boolean;
}

const DEFAULTS: AppSettings = {
  launchAtLogin: false,
  runInBackground: true,
  hideMenuIcons: false,
  darkMode: true,
  balanceAlerts: true,
  keepAwake: false,
};

const KEY = "bb.settings";

function load(): AppSettings {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? { ...DEFAULTS, ...JSON.parse(raw) } : DEFAULTS;
  } catch {
    return DEFAULTS;
  }
}

export function useSettings() {
  const [settings, setSettings] = useState<AppSettings>(load);

  const toggle = useCallback((key: keyof AppSettings) => {
    setSettings((prev) => {
      const next = { ...prev, [key]: !prev[key] };
      try {
        localStorage.setItem(KEY, JSON.stringify(next));
      } catch {
        /* ignore */
      }
      return next;
    });
  }, []);

  return { settings, toggle };
}
