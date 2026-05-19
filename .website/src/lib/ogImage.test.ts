import { describe, expect, it } from "vitest";
import { buildOgSvg } from "./ogImage";

describe("buildOgSvg", () => {
  it("returns a JSX-like element tree shape Satori can render", () => {
    const tree = buildOgSvg({
      kind: "env",
      name: "claude",
      title: "Claude Code",
      tagline: "Claude Code CLI with managed config",
    });
    // The tree is { type, props }; check the title appears
    // somewhere in the serialized form.
    const serialized = JSON.stringify(tree);
    expect(serialized).toContain("Claude Code");
    expect(serialized).toContain("ENV");
  });

  it("uses PKG label for pkg kind", () => {
    const tree = buildOgSvg({
      kind: "pkg",
      name: "ollama",
      title: "Ollama",
      tagline: "Local LLM runtime",
    });
    expect(JSON.stringify(tree)).toContain("PKG");
  });
});
