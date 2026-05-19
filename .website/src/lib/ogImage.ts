// .website/src/lib/ogImage.ts
import type { Kind } from "./kindNames";

export interface OgInput {
  kind: Kind;
  name: string;
  title: string;
  tagline: string;
}

// Returns a JSX-like element tree consumable by Satori.
// Kept JSX-free so the file is a single .ts that does
// not require JSX runtime configuration.
export function buildOgSvg(input: OgInput) {
  const tone =
    input.kind === "env" ? "#11b48a" : "#516084";
  const label = input.kind === "env" ? "ENV" : "PKG";

  return {
    type: "div",
    props: {
      style: {
        display: "flex",
        flexDirection: "column",
        width: "1200px",
        height: "630px",
        background: "#0b1220",
        color: "#e2e8f0",
        padding: "64px",
        fontFamily: "Inter, system-ui, sans-serif",
      },
      children: [
        {
          type: "div",
          props: {
            style: {
              fontSize: "28px",
              color: tone,
              marginBottom: "16px",
              letterSpacing: "0.1em",
              fontFamily: "JetBrains Mono, ui-monospace, monospace",
            },
            children: `flox/envs — ${label}`,
          },
        },
        {
          type: "div",
          props: {
            style: {
              fontSize: "84px",
              fontWeight: 700,
              lineHeight: 1.1,
              marginBottom: "32px",
            },
            children: input.title,
          },
        },
        {
          type: "div",
          props: {
            style: {
              fontSize: "32px",
              color: "#94a3b8",
              lineHeight: 1.4,
            },
            children: input.tagline,
          },
        },
        {
          type: "div",
          props: {
            style: {
              marginTop: "auto",
              fontSize: "24px",
              color: "#475569",
              fontFamily: "JetBrains Mono, ui-monospace, monospace",
            },
            children: `envs.flox.dev/${
              input.kind === "env" ? "envs" : "packages"
            }/${input.name}`,
          },
        },
      ],
    },
  };
}
