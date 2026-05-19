# flox / envs — website

The Astro 5 + Tailwind v4 + Preact + Pagefind site that
showcases every Flox environment and package in this repo.
Served at <https://flox.github.io/floxenvs/>.

## Layout

```text
.website/
├── astro.config.mjs           # Astro + Tailwind + sitemap integrations
├── package.json
├── tsconfig.json
├── vitest.config.ts
├── public/                    # static assets copied verbatim to dist/
│   ├── favicon.svg
│   └── robots.txt
└── src/
    ├── content.config.ts      # Astro content collections; reads
    │                          # meta.yaml + README.md from the repo
    │                          # root and audit/<kind>/<name>/metrics.json
    ├── components/            # Astro and Preact components
    ├── layouts/Layout.astro   # base layout, theme toggle, OG meta
    ├── lib/                   # TypeScript helpers (TDD'd with vitest)
    ├── pages/                 # static-site pages
    │   ├── index.astro        # AI-first landing
    │   ├── envs/[name].astro
    │   ├── packages/[name].astro
    │   ├── og/[kind]/[name].png.ts  # OG image endpoint
    │   └── ...
    └── styles/global.css      # Tailwind v4 + design tokens
```

## Local development

All commands run inside the root flox env (`flox activate`).
The `Justfile` recipes save typing:

| Recipe              | What it runs                              |
| ------------------- | ----------------------------------------- |
| `just website-dev`  | `cd .website && npm run dev`              |
| `just website-build`| `cd .website && npm run build`            |
| `just website-test` | `cd .website && npm run test` (vitest)    |
| `just website-check`| `cd .website && npm run check` (astro)    |
| `just website-push` | Build + push `dist/` to `gh-pages`        |

Pagefind runs after `astro build`. The build emits 200+
pages, the Pagefind index at `dist/pagefind/`, OG images
for featured items at `dist/og/<kind>/<name>.png`, and
`dist/sitemap-*.xml`.

## Deploy

`gh-pages` branch is the deploy target. Two paths:

- `just website-push` — local build, local push.
- CI: push to `main` → `ci.yml` summary green → calls
  `.github/workflows/website.yml` → push to `gh-pages`.

GitHub Pages is configured to "Deploy from a branch ·
`gh-pages` · `/ (root)`".

## Theme

`Layout.astro` includes a header toggle that flips between
light and dark. An inline script in `<head>` applies the
class before paint to avoid flash:

1. If the user has toggled before, the stored choice in
   `localStorage["theme"]` wins.
2. Otherwise the script falls back to
   `prefers-color-scheme: dark`.

Tailwind v4 dark variants resolve via the `.dark` class on
`<html>` (`@custom-variant dark (&:where(.dark, .dark *))`
in `global.css`).

## Custom domain (`envs.flox.dev`) — activation

The site currently lives at
`https://flox.github.io/floxenvs/`. To move it to
`envs.flox.dev`:

### 1. Add DNS records

Add a CNAME in the `flox.dev` zone:

| Type  | Host  | Value                | TTL  |
| ----- | ----- | -------------------- | ---- |
| CNAME | envs  | `flox.github.io.`    | 3600 |

If your provider rejects CNAME on a non-apex host, use the
four GitHub Pages A records instead (see
`docs/dns-setup.md` for the full list).

Confirm propagation:

```bash
dig envs.flox.dev +short
```

### 2. Add the `CNAME` file to the site

GitHub Pages reads `CNAME` from the deployed `dist/` and
flips the custom domain. The file lives in
`.website/public/CNAME` so Astro copies it verbatim to
`dist/CNAME`:

```bash
echo "envs.flox.dev" > .website/public/CNAME
git add .website/public/CNAME
git commit -m "chore: enable envs.flox.dev CNAME"
```

### 3. Flip the workflow URL defaults

The workflow reads two GitHub Actions vars with fallbacks
to `envs.flox.dev` and `/`. Right now those vars are pinned
to the github.io URL — clear them or set them to the
custom domain so the next build uses the right absolute
URLs:

```bash
# Either delete the vars (the workflow falls back to the
# custom-domain defaults baked into website.yml):
gh variable delete SITE_URL
gh variable delete BASE_PATH

# Or set them explicitly:
gh variable set SITE_URL  --body 'https://envs.flox.dev'
gh variable set BASE_PATH --body '/'
```

### 4. Redeploy

```bash
just website-push
# or, after merging the PR with the CNAME file:
gh workflow run website.yml
```

### 5. Confirm in GitHub repo settings

**Settings → Pages → Custom domain**: enter
`envs.flox.dev` → Save. Wait for the green "DNS check
successful" badge. Enable "Enforce HTTPS" once the
certificate has been issued (usually within 15 minutes).

### 6. Verify

```bash
curl -sfSL -o /dev/null -w "HTTP %{http_code}  %{url_effective}\n" \
  https://envs.flox.dev/
```

Should print `HTTP 200  https://envs.flox.dev/`.

### Rollback

If anything breaks:

```bash
# Restore the github.io URL via Actions vars:
gh variable set SITE_URL  --body 'https://flox.github.io'
gh variable set BASE_PATH --body '/floxenvs'

# Remove the CNAME file:
git rm .website/public/CNAME
git commit -m "chore: drop CNAME, return to flox.github.io/floxenvs"

# Redeploy:
just website-push
```

In repo settings, clear the custom-domain field. Within
one workflow run the site is back at
`https://flox.github.io/floxenvs/`.

`docs/dns-setup.md` covers the full DNS/cutover procedure
with more context.

## Adding a new env or package to the site

The site auto-discovers items from the repo root:

- Envs: any top-level dir with a `meta.yaml` of `kind: env`.
- Packages: any `.flox/pkgs/<name>/meta.yaml` of `kind: pkg`.

Author the `meta.yaml` following the existing examples
(`claude/meta.yaml`, `.flox/pkgs/ollama/meta.yaml`) and the
schema in `.website/src/content.config.ts`. The next build
picks it up — no further wiring needed.

If the item has a `<name>-demo/` sibling directory, its
`README.md` and `manifest.toml` are rendered as the
"recipe" section on the env's page.

## Score panel

Each env or package page shows a tessl-style score panel
with Quality, Reliability, Security, and Impact sections.
The data comes from `audit/<kind>/<name>/metrics.json`,
which is produced by `scripts/run-audit.sh <kind> <name>`
in CI. When `metrics.json` is missing, the panel renders
with the default "no data" state.

To audit an item locally:

```bash
just audit-item env claude
# or
just audit-item pkg ollama
```

Then rebuild the site to see the panel populate.

## See also

- `../AGENTS.md` — repo conventions
- `../docs/dns-setup.md` — DNS records and cutover plan
- `../.plans/2026-05-15-flox-envs-site-design.md` — full design spec
