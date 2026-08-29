import { useEffect, useState } from "react";

type Theme = "dark" | "light" | "system";

interface ThemeProviderProps {
  children: React.ReactNode;
  defaultTheme?: Theme;
  storageKey?: string;
}

interface ThemeProviderState {
  theme: Theme;
  setTheme: (theme: Theme) => void;
}

import { createContext, useContext } from "react";

const ThemeProviderContext = createContext<ThemeProviderState | undefined>(undefined);

export function resolveThemePreference(
  storageKey: string,
  defaultTheme: Theme,
  storage?: Pick<Storage, "getItem" | "setItem" | "removeItem">,
): Theme {
  const browserStorage = storage ?? (typeof window !== "undefined" ? window.localStorage : undefined);

  if (!browserStorage) {
    return defaultTheme;
  }

  const legacyKey = "earn-pal-theme";
  const legacyValue = browserStorage.getItem(legacyKey) as Theme | null;
  const currentValue = browserStorage.getItem(storageKey) as Theme | null;

  if (legacyValue && !currentValue) {
    browserStorage.setItem(storageKey, legacyValue);
    browserStorage.removeItem(legacyKey);
    return legacyValue;
  }

  return (currentValue as Theme | null) || defaultTheme;
}

export function ThemeProvider({
  children,
  defaultTheme = "system",
  storageKey = "noble-gain-theme",
  ...props
}: ThemeProviderProps) {
  const [theme, setTheme] = useState<Theme>(() => {
    if (typeof window !== "undefined") {
      return resolveThemePreference(storageKey, defaultTheme, window.localStorage);
    }
    return defaultTheme;
  });

  useEffect(() => {
    const root = window.document.documentElement;

    root.classList.remove("light", "dark");

    if (theme === "system") {
      const systemTheme = window.matchMedia("(prefers-color-scheme: dark)").matches
        ? "dark"
        : "light";

      root.classList.add(systemTheme);
      return;
    }

    root.classList.add(theme);
  }, [theme]);

  const value = {
    theme,
    setTheme: (theme: Theme) => {
      if (typeof window !== "undefined") {
        localStorage.setItem(storageKey, theme);
      }
      setTheme(theme);
    },
  };

  return (
    <ThemeProviderContext.Provider {...props} value={value}>
      {children}
    </ThemeProviderContext.Provider>
  );
}

export const useTheme = () => {
  const context = useContext(ThemeProviderContext);

  if (context === undefined) throw new Error("useTheme must be used within a ThemeProvider");

  return context;
};
