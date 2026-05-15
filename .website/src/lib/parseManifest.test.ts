import { describe, expect, it } from "vitest";
import { parseInstalledPackages } from "./parseManifest";

const SAMPLE = `
schema-version = "1.10.0"

[install]
claude-code.pkg-path = "flox/claude-code"
claude-code.pkg-group = "claude-code"
claude-managed.pkg-path = "flox/claude-managed"
claude-managed.pkg-group = "claude-managed"
claude-managed.version = "^0.4.1"
`;

describe("parseInstalledPackages", () => {
  it("extracts pkg-path names from [install] block", () => {
    const pkgs = parseInstalledPackages(SAMPLE);
    expect(pkgs).toEqual([
      { name: "claude-code", path: "flox/claude-code" },
      { name: "claude-managed", path: "flox/claude-managed" },
    ]);
  });

  it("returns empty list when [install] is missing", () => {
    expect(parseInstalledPackages('schema-version = "1.10.0"')).toEqual([]);
  });

  it("ignores non-pkg-path keys like pkg-group and version", () => {
    const pkgs = parseInstalledPackages(SAMPLE);
    expect(pkgs.every(p => "name" in p && "path" in p)).toBe(true);
  });
});
