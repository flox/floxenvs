export const KINDS = ["env", "pkg"] as const;
export type Kind = (typeof KINDS)[number];

export const SUBKINDS = ["plain", "plugin", "skill"] as const;
export type SubKind = (typeof SUBKINDS)[number];

export const AI_ROLES = [
  "agent",
  "llm-runtime",
  "rag",
  "orchestrator",
  "tooling",
  "ide",
] as const;
export type AiRole = (typeof AI_ROLES)[number];

export const CATEGORIES = [
  "ai",
  "language",
  "database",
  "service",
  "tool",
  "runtime",
] as const;
export type Category = (typeof CATEGORIES)[number];

export const KIND_LABEL: Record<Kind | SubKind, string> = {
  env: "ENV",
  pkg: "PKG",
  plain: "PKG",
  plugin: "PLUGIN",
  skill: "SKILL",
};

export const KIND_TONE: Record<Kind | SubKind, string> = {
  env: "kind-env",
  pkg: "kind-pkg",
  plain: "kind-pkg",
  plugin: "kind-plugin",
  skill: "kind-skill",
};
