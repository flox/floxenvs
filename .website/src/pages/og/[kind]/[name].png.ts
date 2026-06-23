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
  // Inter ships from the `.website` flox env (the `inter` package).
  // Prefer it via $FLOX_ENV so local builds inside the env Just Work;
  // CI sets OG_FONT_PATH explicitly (handled by the caller below).
  const floxEnv = process.env.FLOX_ENV;
  const candidates = [
    floxEnv && `${floxEnv}/share/fonts/truetype/InterVariable.ttf`,
    "/System/Library/Fonts/Supplemental/Arial.ttf",
  ].filter((c): c is string => Boolean(c));
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
  const { title, tagline } = props as { title: string; tagline: string };

  let png: Uint8Array;
  try {
    const tree = buildOgSvg({ kind, name: params.name!, title, tagline });
    const fontData = process.env.OG_FONT_PATH
      ? (await fs.readFile(process.env.OG_FONT_PATH)).buffer
      : await loadFont();
    const svg = await satori(tree as Parameters<typeof satori>[0], {
      width: 1200,
      height: 630,
      fonts: [
        { name: "Inter", data: fontData, weight: 400, style: "normal" },
        { name: "Inter", data: fontData, weight: 700, style: "normal" },
      ],
    });
    png = new Uint8Array(new Resvg(svg).render().asPng());
  } catch (err) {
    // Best-effort: satori needs a static font, but the .website env ships
    // only a variable Inter its parser rejects. Until the website redesign
    // sorts out fonts, emit a text-free branded placeholder (Resvg needs no
    // font for it) so a font issue can never fail the build.
    console.warn(`OG render fallback for ${kind}/${params.name}: ${err}`);
    const tone = kind === "env" ? "#11b48a" : "#516084";
    const fallback =
      `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630">` +
      `<rect width="1200" height="630" fill="#0b1220"/>` +
      `<rect width="1200" height="14" fill="${tone}"/></svg>`;
    png = new Uint8Array(new Resvg(fallback).render().asPng());
  }

  return new Response(png, {
    headers: {
      "Content-Type": "image/png",
      "Cache-Control": "public, max-age=31536000, immutable",
    },
  });
};
