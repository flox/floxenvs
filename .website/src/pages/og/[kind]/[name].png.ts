// .website/src/pages/og/[kind]/[name].png.ts
import type { APIRoute, GetStaticPaths } from "astro";
import { getCollection } from "astro:content";
import satori from "satori";
import { Resvg } from "@resvg/resvg-js";
import * as fs from "node:fs/promises";
import { buildOgSvg } from "../../../lib/ogImage";

export const getStaticPaths: GetStaticPaths = async () => {
  const envs = await getCollection("envs");
  const pkgs = await getCollection("packages");
  const out: {
    params: { kind: string; name: string };
    props: { title: string; tagline: string };
  }[] = [];
  // Generate per-item OG for every env and package. The earlier
  // gating on `featured` left most detail pages sharing the generic
  // `og/default.png`, which audits flagged as a CTR / citability loss.
  for (const e of envs) {
    out.push({
      params: { kind: "env", name: e.data.name },
      props: { title: e.data.title, tagline: e.data.tagline },
    });
  }
  for (const p of pkgs) {
    out.push({
      params: { kind: "pkg", name: p.data.name },
      props: { title: p.data.title, tagline: p.data.tagline },
    });
  }
  return out;
};

// Inter font shipped with satori examples; for now read
// it from node_modules.
async function loadFont(): Promise<ArrayBuffer> {
  // Most distros of `satori` ship without bundled fonts.
  // We rely on the system Inter; fall back to a tiny
  // Roboto bundled by `@fontsource/roboto` if needed.
  // To keep deps light, require Inter via Nix CI image.
  const candidates = [
    "/usr/share/fonts/inter/Inter-Regular.ttf",
    "/usr/share/fonts/truetype/inter/Inter-Regular.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
  ];
  for (const c of candidates) {
    try {
      const buf = await fs.readFile(c);
      return buf.buffer.slice(
        buf.byteOffset,
        buf.byteOffset + buf.byteLength,
      );
    } catch {
      // try next candidate
    }
  }
  throw new Error(
    "No usable font found for OG image rendering. " +
      "Set OG_FONT_PATH or install Inter.",
  );
}

export const GET: APIRoute = async ({ params, props }) => {
  const kind = params.kind as "env" | "pkg";
  const tree = buildOgSvg({
    kind,
    name: params.name!,
    title: (props as { title: string; tagline: string }).title,
    tagline: (props as { title: string; tagline: string }).tagline,
  });
  const fontData = process.env.OG_FONT_PATH
    ? (await fs.readFile(process.env.OG_FONT_PATH)).buffer
    : await loadFont();
  const svg = await satori(tree as Parameters<typeof satori>[0], {
    width: 1200,
    height: 630,
    fonts: [
      {
        name: "Inter",
        data: fontData,
        weight: 400,
        style: "normal",
      },
      {
        name: "Inter",
        data: fontData,
        weight: 700,
        style: "normal",
      },
    ],
  });
  const png = new Resvg(svg).render().asPng();
  return new Response(new Uint8Array(png), {
    headers: {
      "Content-Type": "image/png",
      "Cache-Control": "public, max-age=31536000, immutable",
    },
  });
};
