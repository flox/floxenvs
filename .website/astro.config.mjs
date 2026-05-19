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
  integrations: [preact(), sitemap()],
  vite: { plugins: [tailwindcss()] },
});
