import { defineConfig } from "astro/config";
import preact from "@astrojs/preact";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";

const SITE = process.env.SITE_URL ?? "https://flox.github.io";
const BASE = process.env.BASE_PATH ?? "/floxenvs";

export default defineConfig({
  site: SITE,
  base: BASE,
  output: "static",
  trailingSlash: "always",
  integrations: [
    preact(),
    sitemap({
      // Mark each URL with the build timestamp. The build is
      // deterministic per push, so this is effectively the
      // "last touched on main" date for the whole catalog.
      // Per-page git-commit times would be sharper but require
      // a build-time git lookup; deferring that.
      serialize(item) {
        return { ...item, lastmod: new Date().toISOString() };
      },
    }),
  ],
  vite: { plugins: [tailwindcss()] },
});
