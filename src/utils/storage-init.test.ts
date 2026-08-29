import { describe, expect, it } from "vitest";
import { shouldWarnForBucketError } from "./storage-init";

describe("shouldWarnForBucketError", () => {
  it("suppresses noisy permission-related storage warnings", () => {
    expect(
      shouldWarnForBucketError({ message: "JWT expired", status: 401 }, "avatars", false),
    ).toBe(false);
  });

  it("warns only for actual missing bucket issues", () => {
    expect(
      shouldWarnForBucketError({ message: "Bucket not found", status: 404 }, "rewards", false),
    ).toBe(true);
  });
});
