import { describe, expect, it } from "vitest";
import { getUsernameStatus, normalizeUsername } from "@/lib/username-validation";

describe("normalizeUsername", () => {
  it("strips unsupported characters and lowercases the value", () => {
    expect(normalizeUsername("Noble-User_123")).toBe("nobleuser_123");
  });
});

describe("getUsernameStatus", () => {
  it("rejects usernames shorter than 3 characters", () => {
    expect(getUsernameStatus("ab")).toMatchObject({
      isValid: false,
      state: "error",
      message: expect.stringContaining("at least 3 characters"),
    });
  });

  it("accepts a valid username pattern", () => {
    expect(getUsernameStatus("noble_user_123")).toMatchObject({
      isValid: true,
      state: "success",
      message: expect.stringContaining("available"),
    });
  });

  it("rejects invalid characters", () => {
    expect(getUsernameStatus("noble user")).toMatchObject({
      isValid: false,
      state: "error",
      message: expect.stringContaining("letters, numbers, and underscores"),
    });
  });
});
