---
name: dotfiles

description: Use when touching ~/dotfiles; repo rules and workflow.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [dotfiles, hammerspoon, stow, git, macos]
    related_skills: [github-auth]
---

## When to Use

- Editing anything under `~/dotfiles` (hammerspoon, zsh, ssh, claude, tmux, micro, karabiner packages)
- Adding or changing a global app-launch hotkey (⌃⌘+key)
- Committing/pushing the user's dotfiles, or reviewing what's pending there
- Fixing "Permission denied (publickey)" pushing this user's GitHub repos

# dotfiles — hugopuybareau's stow-managed macOS config

Repo: `~/dotfiles`, packages symlinked into `$HOME` by GNU stow (`make stow` in the repo runs `stow --restow` over the package list). Before assuming a file is repo-managed, check `ls -la ~/` for the symlink — `~/.ssh/config` is a plain local file (holds private VPS details; keep it out of the repo), while `ssh/.ssh/agent.sh` IS stowed.

Remotes: `origin` = `git@github.com:hugopuybareau/dotfiles.git` (SSH), `upstream` = `maxmaxou2/dotfiles`. **origin is PUBLIC** — every pushed diff is world-visible.

## Always-on rules

- Stage only the files belonging to the current change. The user routinely keeps unrelated uncommitted edits (claude config, zsh) pending; never sweep them into a task's commit.
- When asked to push "everything": review ALL pending changes with the user first — tracked diffs AND untracked files — then commit in logical groups; gitignore runtime junk instead of committing it.
- Public-repo gate: scan every diff for secrets, tokens, and private infra details (VPS IPs, hostnames) before pushing; say plainly when personal config is about to land in a public repo.
- Commit messages: conventional commits matching history — `feat(scope):`, `fix(scope):`, `chore(scope):`, lowercase imperative.
- Runtime-junk policy under `claude/.claude/` (already gitignored): plugin caches (`plugin-directory-cache*.json`, `plugins/store/`, `plugins/synced/`), `state/`, `skills/.trash/`, `skills/synced/`, `settings.json.*` backups. Hand-written config (settings.json, themes/, CLAUDE.md) is tracked and belongs in commits.
- SSH push failures (`Permission denied (publickey)`) on this machine: apply the macOS Keychain agent fix from the github-auth skill, then push over SSH as normal.
- When reporting git state, explain concepts plainly (commit = local save, push = upload to the GitHub remote, remote = hosted copy) — the user is still building git vocabulary.

## Hammerspoon app-shortcut workflow (⌃⌘+key)

Single-app launcher shortcuts live in `hammerspoon/.hammerspoon/Spoons/AppKeybindings.spoon/init.lua`.

1. Resolve the bundle ID: `osascript -e 'id of app "Name"'` (Hermes = `com.nousresearch.hermes`).
2. Add a `*_BUNDLE` constant next to the others at the top of the file.
3. Check the `singleHotkeys` table for a free key (avoid collisions), then add `["x"] = { bundleID = THE_BUNDLE }`. Current map: t=cmux, v=VSCode, m=Mail, c=Chrome, p=Finder, o=Obsidian, w=Whatsapp, s=Spotify, d=Discord, r=Strawberry, à=CapCut, h=Hermes.
4. Syntax-check: `luajit -b <file> /dev/null`.
5. Restart Hammerspoon to reload config: `killall Hammerspoon && sleep 1 && open -a Hammerspoon`.
6. Verify end-to-end with a synthetic keypress — see references/macos-hotkey-verification.md.
