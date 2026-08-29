import { describe, expect, it } from "vitest";
import { resolveThemePreference } from "./use-theme";

describe("resolveThemePreference", () => {
  it("migrates legacy Earn Pal storage values to the Noble Gain key", () => {
    const storage = {
      getItem: (key: string) => {
        if (key === "earn-pal-theme") return "dark";
        if (key === "noble-gain-theme") return null;
        return null;
      },
      setItem: () => undefined,
      removeItem: () => undefined,
    } as unknown as Storage;

    expect(resolveThemePreference("noble-gain-theme", "system", storage)).toBe("dark");
  });
});
