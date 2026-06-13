import { describe, expect, it } from "vitest";
import { deriveBundling } from "./derive";

const envs = [
  {
    name: "claude",
    bundles_pkgs: [],
    manifest_install: [
      { name: "claude-code", path: "flox/claude-code" },
      { name: "flox-ai", path: "flox/flox-ai" },
    ],
  },
  {
    name: "langchain",
    bundles_pkgs: ["ollama"],
    manifest_install: [],
  },
];

const pkgs = [
  { name: "claude-code" },
  { name: "flox-ai" },
  { name: "ollama" },
];

describe("deriveBundling", () => {
  it("populates bundles_pkgs from manifest.toml [install]", () => {
    const r = deriveBundling(envs, pkgs);
    const claude = r.envs.find(e => e.name === "claude")!;
    expect(claude.bundles_pkgs).toEqual(["claude-code", "flox-ai"]);
  });

  it("preserves explicit bundles_pkgs in meta.yaml", () => {
    const r = deriveBundling(envs, pkgs);
    const lc = r.envs.find(e => e.name === "langchain")!;
    expect(lc.bundles_pkgs).toEqual(["ollama"]);
  });

  it("populates bundled_by on packages via reverse lookup", () => {
    const r = deriveBundling(envs, pkgs);
    const ollama = r.pkgs.find(p => p.name === "ollama")!;
    expect(ollama.bundled_by).toEqual(["langchain"]);
    const cc = r.pkgs.find(p => p.name === "claude-code")!;
    expect(cc.bundled_by).toEqual(["claude"]);
  });

  it("ignores manifest paths that do not match a known pkg", () => {
    const r = deriveBundling(
      [{ name: "x", bundles_pkgs: [], manifest_install: [
        { name: "nodejs_22", path: "nodejs_22" },
      ]}],
      pkgs,
    );
    expect(r.envs[0].bundles_pkgs).toEqual([]);
  });
});
