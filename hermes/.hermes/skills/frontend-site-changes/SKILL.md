---
name: frontend-site-changes
description: "Edit the user's Vite/React sites. Build, verify, ship."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [frontend, react, vite, tailwind, vercel, deploy-verification]
    related_skills: [humanizer, github-auth]
---

# Front-end site changes: edit → build → local verify → push → live verify

Changes to the site repos listed in `references/sites.md` (portfolio, jayn-landing). The loop: edit source, build, verify behavior locally, push only what you touched, then verify the deployment is actually serving the change. Other Vite apps, including `~/src/crm`, are out of scope — use the `crm` skill. This deploy loop does not apply to them.

## When to Use

- The user asks to change anything in one of their site repos listed in `references/sites.md` — copy, layout, new sections, assets, media.
- The user reports a visual/behavior bug on one of their sites ("weird on refresh", broken link, misaligned section) — reproduce it before touching code, verify the fix locally, then confirm live.
- The user asks to update their GitHub profile README to match site changes — the inventory file notes where it lives.
- Do not use this skill for `~/src/crm` or any repo absent from `references/sites.md`. A Vite + React stack is not enough; the push-and-grep-live-bundle steps target these sites' hosts only.

## Procedure

1. **Read the target files before editing.** Map with `find <repo> -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*'`, then read the page/data files and the repo's CLAUDE.md if present.
2. **Clone the codebase's own idioms, don't invent.** The hover-underline link is one long copy-pasted Tailwind className literal reused at every link — paste it verbatim; icons load from root-absolute `/icons/<file>` paths; a new list/section entry copies the surrounding item structure.
3. **Site copy keeps the human tone.** lowercase-casual, first person, no AI-isms — check new prose against the humanizer skill's patterns (`skill_view humanizer`) before committing. The surrounding lines are the style guide.
4. **Build + lint before verifying anything.** `npm run build && npm run lint`. The build also proves new assets resolve: `ls dist/icons`, `ls dist/photos/projects`, or grep the emitted `dist/assets/*.js` for the asset name.
5. **Behavior checks run against a local `dist/` server, started in the background.** Foreground server commands are refused as long-lived processes. `terminal(background=true)` with `cd dist && python3 -m http.server <port>`, curl `http://localhost:<port>/` for a 200, then open it in the preview pane.
6. **Verify behavior in the preview pane** (desktop_preview `open` → drive_preview `scroll`/`click`/`reload` → `elements` / desktop_preview `read`). For any "weird on refresh" report: scroll down a few hundred px, `reload`, compare the `elements` inventory — top-of-page content (intro, first Recently items) visible = fix works; only mid/late entries visible = scroll was restored, see pitfall 1.
7. **Commit only what you touched.** These repos carry unrelated dirty edits (in-progress thoughts/drafts) — stage by explicit path, never `git add -A`/`-a`, and tell the user what was left uncommitted.
8. **Push, then verify the deployment for real.** Vercel auto-deploys from `main` in ~60–90 s. Never report success from the push alone: sleep ~80 s, curl the live index, extract the current hashed bundle filename (the `index-*.js` entry under `dist/assets/` naming) from it, download that bundle, and grep for a unique marker string from your change — new string present (count ≥1) AND removed old string absent (count 0). A changed asset hash only proves a rebuild, not that your change shipped. For asset URLs use `curl -sIL` and judge the FINAL status — the apex host 307s to www, so a bare status check reads the redirect, not the file.
9. **Re-run the behavioral check against the live URL** once the bundle marker is confirmed, same as step 6.

## Pitfalls

1. **SPA refresh landing mid-page** is the browser's history scroll restoration racing the app's route-change `scrollTo(0, 0)`: restoration applies asynchronously AFTER React mount effects, so it wins on reload. Set `history.scrollRestoration = 'manual'` in an inline `<head>` script in index.html (runs before the bundle — strongest placement) and repeat the guard in the JS entry file. Keep the route-change scrollTo: it is correct for navigation.
2. **Multi-MB demo GIFs → looping MP4.** Screen-capture GIFs pulled from project repos are huge; convert for `video` fields: `ffmpeg -i in.gif -movflags faststart -pix_fmt yuv420p -vf "scale=960:-2" -c:v libx264 -crf 28 -an out.mp4` (≈10× smaller at equal quality for screen captures). Keep `object-contain` (not `object-cover`) on the dark card background for terminal captures — cover crops them.
3. **Never judge an SVG from a rasterized thumbnail.** Vision on a `qlmanage -t` rasterization reports "pixelated at small sizes" even for a clean 24×24 viewBox vector — the thumbnail is low-res, not the icon. Inspect the SVG source (viewBox, shape count, single fill) or render at the exact target size.
4. **Don't hand-parse binary headers for media dimensions** — a struct read of a GIF descriptor produced dimensions orders of magnitude off. Use `ffprobe -show_entries stream=width,height`.
5. **read_file dedup:** re-reading an already-read file returns "unchanged since last read" with no content — re-read with explicit `offset`/`limit` parameters to force the real content.
6. **Push over SSH can fail with "Permission denied (publickey)"** while `gh` is authenticated — follow the github-auth HTTPS fallback (`gh auth setup-git`, then push or switch the remote URL to HTTPS). Empty `git config credential.helper` does not mean no helper: gh writes a URL-scoped `[credential "https://github.com"]` entry the unscoped lookup never shows.
