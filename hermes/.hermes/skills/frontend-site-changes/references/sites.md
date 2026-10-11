# Site inventory

Quick cache of the user's front-end properties — re-verify paths per session, they drift. Update this file when a site's layout or deploy changes.

| repo | stack | deploy | live | facts worth knowing |
|---|---|---|---|---|
| `~/src/portfolio` | Vite + React 18 + TS + Tailwind + Framer Motion; dev server port 4173 | Vercel, auto from `main` (~60–90 s; no vercel CLI installed — verify deploys by grepping the live bundle) | https://hugopuybareau.com → 307 → https://www.hugopuybareau.com | icons `public/icons/*` (root-absolute imports), project media `public/photos/projects/*`; the GitHub profile README lives in the `hugopuybareau/hugopuybareau` repo — update via the contents API, passing the current file `sha` |
| `~/src/jayn-landing` | pnpm + Vite multi-page React; Tailwind v4; Caddy + Docker | Hetzner; `.github/workflows/deploy-hetzner.yml` is **workflow_dispatch**, not auto-deploy on push (deployment not exercised here) | https://jayn.app | `public/favicon.svg` is the golden pixel-sun jayn mark; entries: `/`, `/jaynshare`, `/audits`, `/caveman`, `/share`, `/share-app`; hosted product: https://share.jayn.app |

## Jayn typography and design constraints

- Preserve Jaynshare's approved layout, spacing, font sizes, tracking, content, and interactions in typography-only requests. Change font families only; natural text reflow from different glyph metrics is expected. Obtain a baseline of computed non-font styles and visible text before edits, then compare desktop/mobile and light/dark renders afterwards.
- Keep the larger landing redesign separate from the typography pass. The user's reference is https://nousresearch.com/ for density, constrained composition, and multiple contrasting type roles—not its branding or proprietary font binaries.
- The local type system is defined in `src/typography.css` and Tailwind tokens in `src/index.css`: Barlow Condensed (display), Instrument Sans (copy/UI), IBM Plex Mono (technical/navigation), Fraunces (editorial/reading). Font provenance and role mapping live in `public/fonts/README.md`.
- Self-host font binaries and include their OFL notices. `/fonts/*` has immutable caching, so use content-hashed filenames when replacing a font, and update every affected HTML preload. Do not overwrite a font binary in place or add runtime Google Fonts requests.
- Include generated SVG labels when auditing typography: `src/charts/*.svg` are inlined into the Caveman article and can hard-code retired faces despite correct page CSS. Update `tools/charts.py` to measure using the selected self-hosted WOFF2 (pin variable weights with fontTools before converting to TTF), emit `font-family:var(--font-sans)`, and regenerate rather than merely swapping names against old metrics. Preserve numeric labels and accessible descriptions; check label bounding boxes against each SVG viewport. The hand-written `exchange.svg` is not generated and needs a separate font-family attribute edit. Cache conversion artifacts under TMPDIR, not in the repo.
- Use `pnpm build` (includes typecheck/server build) and targeted `pnpm exec prettier --check <changed files>`; this repo has no `lint` script. Do not run whole-repo format writes or assume a push deploys production.

Related org repos: `~/src/jaynshare` (jaynshare source), public at `https://github.com/jaynlabs/jaynshare` — marketing/doc assets live under its `docs/assets/` (demo GIF, light/dark SVG logos, overview diagrams).
