# Custom domain: `envs.flox.dev`

This document covers DNS setup, the rollout sequence,
and the rollback plan for moving the showcase site from
`https://flox.github.io/floxenvs/` to
`https://envs.flox.dev/`.

## DNS records

Add these to the `flox.dev` zone. Use a CNAME if the
zone supports it for subdomains (most do); fall back to
the four A records if you need an apex-style record
(not the case here, but documented for completeness).

| Type  | Host | Value             | TTL  |
| ----- | ---- | ----------------- | ---- |
| CNAME | envs | `flox.github.io.` | 3600 |

If your provider rejects CNAME on a non-apex host, use
the four GitHub Pages A records instead:

| Type | Host | Value           |
| ---- | ---- | --------------- |
| A    | envs | 185.199.108.153 |
| A    | envs | 185.199.109.153 |
| A    | envs | 185.199.110.153 |
| A    | envs | 185.199.111.153 |

## Rollout sequence

GitHub Pages provisions the TLS certificate for a custom
domain **after** seeing the `CNAME` file in the deployed
artifact, then verifying DNS. Order matters:

1. Merge the PR that adds `.website/public/CNAME`
   (Task 29) and switches `SITE_URL` (Task 30). The next
   deploy publishes `envs.flox.dev` inside `dist/`.
2. Confirm the deploy succeeds at
   `https://flox.github.io/floxenvs/` (the artifact is
   reachable at the old URL until DNS flips).
3. Add the DNS records above. Wait for propagation
   (use `dig envs.flox.dev +short` to confirm).
4. In the repo: Settings -> Pages -> Custom domain ->
   enter `envs.flox.dev` -> Save. Wait for the green
   "DNS check successful" badge.
5. Tick the "Enforce HTTPS" checkbox once the cert is
   issued (usually within 15 minutes).
6. Trigger a manual workflow run to repopulate Pagefind
   and OG assets at the new domain:

   ```bash
   gh workflow run website.yml
   ```

## Rollback plan

If anything breaks after the cutover:

1. In the repo: Settings -> Pages -> Custom domain ->
   clear the field -> Save.
2. Set repo Actions vars to restore the old URL:

   ```bash
   gh variable set SITE_URL --body 'https://flox.github.io'
   gh variable set BASE_PATH --body '/floxenvs'
   ```

3. Re-run the workflow:

   ```bash
   gh workflow run website.yml
   ```

4. (Optional) Revert the commits that added
   `.website/public/CNAME` if the rollback is permanent.

The rollback fully restores the Plan A URL within one
workflow run because the only differences are
environment variables and a single file in
`.website/public/`.

## Verification checklist

After rollout, run:

```bash
curl -sI https://envs.flox.dev/ | head -5
curl -sI https://envs.flox.dev/envs/claude/ | head -5
curl -sI https://envs.flox.dev/sitemap-index.xml | head -5
```

Expected: `200 OK` on each, with HTTPS enforced
(no redirect from `http://`).
